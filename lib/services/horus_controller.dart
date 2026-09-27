import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/horus_persona.dart';
import 'audio_input.dart';
import 'audio_output.dart';
import 'settings_store.dart';

enum HorusState {
  /// Welcome screen, no conversation running.
  idle,
  connecting,

  /// Waiting for / hearing the visitor.
  listening,

  /// Visitor finished talking, waiting for Horus's answer.
  thinking,
  speaking,
  error,
}

/// Runs a voice conversation between a visitor and Horus over the Gemini
/// Live API: mic audio goes up, Horus's spoken answer streams back and plays.
class HorusController extends ChangeNotifier {
  HorusController({required this.settingsStore});

  final SettingsStore settingsStore;
  final AudioInput _input = AudioInput();
  final AudioOutput _output = AudioOutput();

  HorusSettings settings = const HorusSettings();
  HorusState state = HorusState.idle;

  /// What the visitor said/typed in the current exchange.
  String userText = '';

  /// What Horus is saying in the current exchange.
  String horusText = '';

  String? errorMessage;

  /// Technical error text shown in small print, to help diagnose problems.
  String? errorDetail;

  /// Mic loudness 0..1, for the listening animation.
  final ValueNotifier<double> micLevel = ValueNotifier(0);

  LiveSession? _session;
  String? _resumptionHandle;
  Timer? _ticker;
  DateTime _lastActivity = DateTime.now();
  bool _turnComplete = true;
  bool _dropAudioUntilNextTurn = false;
  // Set when a turn ends; the next transcript chunk then replaces the old
  // text instead of appending to it.
  bool _clearUserText = true;
  bool _clearHorusText = true;
  DateTime? _thinkingSince;
  bool _disposed = false;
  int _sessionGeneration = 0;
  DateTime _connectedAt = DateTime.now();
  bool _receivedContent = false;
  int _quickCloses = 0;

  bool get isActive => state != HorusState.idle && state != HorusState.error;

  Future<void> init() async {
    settings = await settingsStore.load();
    try {
      await _output.init();
    } catch (e) {
      developer.log('Audio output init failed', error: e);
    }
    notifyListeners();
  }

  Future<void> updateSettings(HorusSettings newSettings) async {
    settings = newSettings;
    await settingsStore.save(newSettings);
    // Voice and mic behaviour apply from the next conversation.
    if (isActive) await stop();
    notifyListeners();
  }

  LiveGenerativeModel _buildModel() {
    return FirebaseAI.googleAI().liveGenerativeModel(
      model: AppConfig.geminiLiveModel,
      systemInstruction: Content.system(HorusPersona.systemInstruction),
      liveGenerationConfig: LiveGenerationConfig(
        responseModalities: [ResponseModalities.audio],
        speechConfig: SpeechConfig(voiceName: settings.voiceName),
        inputAudioTranscription: AudioTranscriptionConfig(),
        outputAudioTranscription: AudioTranscriptionConfig(),
      ),
      tools: [Tool.googleSearch()],
    );
  }

  /// Starts a conversation (the big mic button).
  Future<void> start() async {
    if (isActive) return;
    errorMessage = null;
    errorDetail = null;
    _quickCloses = 0;
    userText = '';
    horusText = '';
    _setState(HorusState.connecting);

    if (!await _input.hasPermission()) {
      _fail('محتاج إذن الميكروفون علشان أقدر أسمعك.');
      return;
    }

    try {
      await _connect();
    } catch (e) {
      developer.log('Failed to connect', error: e);
      await _teardown();
      _fail(_describeConnectionError(e), detail: e);
      return;
    }

    try {
      await _input.start(
        onData: _onMicData,
        onLevel: (level) => micLevel.value = level,
      );
    } catch (e) {
      developer.log('Failed to start microphone', error: e);
      await _teardown();
      _fail('مش قادر أشغّل الميكروفون.', detail: e);
      return;
    }

    _markActivity();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());

    if (settings.greetOnStart) {
      _turnComplete = false;
      _setState(HorusState.thinking);
      try {
        await _session?.sendTextRealtime(HorusPersona.greetingPrompt);
      } catch (e) {
        developer.log('Failed to send greeting', error: e);
      }
    } else {
      _setState(HorusState.listening);
    }
  }

  Future<void> _connect() async {
    final generation = ++_sessionGeneration;
    final model = _buildModel();
    LiveSession session;
    try {
      session = await model.connect(
        sessionResumption: _resumptionHandle != null
            ? SessionResumptionConfig.resume(_resumptionHandle!)
            : SessionResumptionConfig(),
      );
    } catch (e) {
      if (_resumptionHandle == null) rethrow;
      _resumptionHandle = null;
      session = await model.connect(
        sessionResumption: SessionResumptionConfig(),
      );
    }
    _session = session;
    _connectedAt = DateTime.now();
    _receivedContent = false;
    unawaited(_receiveLoop(session, generation));
  }

  /// Ends the conversation and goes back to the welcome screen.
  Future<void> stop() async {
    await _teardown();
    _resumptionHandle = null;
    micLevel.value = 0;
    _setState(HorusState.idle);
  }

  Future<void> _teardown() async {
    _sessionGeneration++;
    _ticker?.cancel();
    _ticker = null;
    await _input.stop();
    await _output.stop();
    final session = _session;
    _session = null;
    await session?.close();
  }

  /// Sends a typed question. Starts a conversation first if needed.
  Future<void> sendText(String text) async {
    text = text.trim();
    if (text.isEmpty) return;
    if (!isActive) {
      final greet = settings.greetOnStart;
      settings = settings.copyWith(greetOnStart: false);
      await start();
      settings = settings.copyWith(greetOnStart: greet);
      if (!isActive) return;
    }
    await _output.stop();
    _dropAudioUntilNextTurn = false;
    userText = text;
    horusText = '';
    _clearUserText = false;
    _clearHorusText = false;
    _turnComplete = false;
    _markActivity();
    _setState(HorusState.thinking);
    await _session?.sendTextRealtime(text);
  }

  /// Tapping Horus while he talks makes him stop.
  Future<void> interrupt() async {
    if (state != HorusState.speaking && state != HorusState.thinking) return;
    _dropAudioUntilNextTurn = true;
    await _output.stop();
    _clearUserText = _clearHorusText = true;
    _markActivity();
    _setState(HorusState.listening);
  }

  void _onMicData(Uint8List data) {
    final session = _session;
    if (session == null) return;
    final horusTalking = state == HorusState.speaking || _output.isPlaying;
    if (horusTalking && !settings.allowInterruptions) {
      // Keep the mic muted so Horus doesn't answer his own echo.
      return;
    }
    session
        .sendAudioRealtime(InlineDataPart(AudioInput.mimeType, data))
        .catchError((Object e) => developer.log('Send audio failed', error: e));
  }

  Future<void> _receiveLoop(LiveSession session, int generation) async {
    try {
      await for (final response in session.receive()) {
        if (generation != _sessionGeneration) return;
        await _handle(response.message);
      }
    } catch (e) {
      developer.log('Live session error', error: e);
    }
    if (generation != _sessionGeneration || !isActive) return;

    // The socket closed on its own. Find out why: receive() throws with the
    // server's close code and reason once the socket is closed.
    Object? reason;
    try {
      await session.receive().drain<void>();
    } catch (e) {
      reason = e;
    }
    developer.log('Live session closed: $reason');

    // A session the server closes right away (bad App Check token, unknown
    // model, quota...) would fail again; stop instead of looping forever.
    final quick =
        !_receivedContent &&
        DateTime.now().difference(_connectedAt) < const Duration(seconds: 10);
    _quickCloses = quick ? _quickCloses + 1 : 0;
    if (_quickCloses >= 2) {
      await _teardown();
      _fail(_describeConnectionError(reason), detail: reason);
      return;
    }
    await _reconnect();
  }

  Future<void> _reconnect() async {
    // Invalidate the old receive loop first so closing it can't trigger a
    // second reconnect.
    _sessionGeneration++;
    try {
      final old = _session;
      _session = null;
      await old?.close();
      await _connect();
      if (state == HorusState.connecting) _setState(HorusState.listening);
    } catch (e) {
      developer.log('Reconnect failed', error: e);
      await _teardown();
      _fail('الاتصال بالإنترنت اتقطع. اضغط على الميكروفون وجرب تاني.');
    }
  }

  Future<void> _handle(LiveServerMessage message) async {
    switch (message) {
      case LiveServerContent():
        _handleContent(message);
      case GoingAwayNotice():
        // Server is about to close this socket; move to a fresh one.
        unawaited(_reconnect());
      case SessionResumptionUpdate(:final resumable, :final newHandle):
        if (resumable ?? false) _resumptionHandle = newHandle;
      case LiveServerToolCall(:final functionCalls):
        developer.log('Unexpected tool call: $functionCalls');
      default:
        break;
    }
  }

  void _handleContent(LiveServerContent content) {
    _receivedContent = true;
    _quickCloses = 0;
    final heard = content.inputTranscription?.text;
    if (heard != null && heard.trim().isNotEmpty) {
      if (_clearUserText) {
        userText = '';
        _clearUserText = false;
        // Hide the previous answer, unless the transcript arrived late and
        // Horus is already saying the new one.
        if (state != HorusState.speaking) {
          horusText = '';
          _clearHorusText = false;
        }
      }
      userText += heard;
      _turnComplete = false;
      _markActivity();
      if (state == HorusState.listening) _setState(HorusState.thinking);
      notifyListeners();
    }

    if (content.interrupted ?? false) {
      // Visitor talked over Horus: stop the audio he was still playing.
      unawaited(_output.stop());
      _dropAudioUntilNextTurn = false;
      _clearUserText = _clearHorusText = true;
      _setState(HorusState.listening);
    }

    final parts = content.modelTurn?.parts ?? const <Part>[];
    for (final part in parts) {
      if (part is InlineDataPart &&
          part.mimeType.startsWith('audio') &&
          !_dropAudioUntilNextTurn) {
        _output.add(part.bytes);
        _markActivity();
        if (state != HorusState.speaking) _setState(HorusState.speaking);
      }
    }

    final said = content.outputTranscription?.text;
    if (said != null && !_dropAudioUntilNextTurn) {
      if (_clearHorusText) {
        horusText = '';
        _clearHorusText = false;
      }
      horusText += said;
      notifyListeners();
    }

    if (content.turnComplete ?? false) {
      // Turn ended without any audio (nothing to say): go back to listening.
      if (state == HorusState.thinking) _setState(HorusState.listening);
      _turnComplete = true;
      _clearUserText = _clearHorusText = true;
      _dropAudioUntilNextTurn = false;
    }
  }

  void _tick() {
    if (!isActive) return;
    if (state == HorusState.speaking && _turnComplete && !_output.isPlaying) {
      _markActivity();
      _setState(HorusState.listening);
    }
    if (state == HorusState.speaking || _output.isPlaying) {
      _markActivity();
    }
    // Don't stay stuck on "thinking" if no answer ever arrives.
    final thinkingSince = _thinkingSince;
    if (state == HorusState.thinking &&
        thinkingSince != null &&
        DateTime.now().difference(thinkingSince).inSeconds >= 20) {
      _clearUserText = _clearHorusText = true;
      _markActivity();
      _setState(HorusState.listening);
    }
    final idle = DateTime.now().difference(_lastActivity);
    if (state == HorusState.listening &&
        idle.inSeconds >= settings.idleTimeoutSeconds) {
      unawaited(stop());
    }
  }

  void _markActivity() => _lastActivity = DateTime.now();

  String _describeConnectionError(Object? error) {
    final text = '$error';
    if (text.contains('App Check') || text.contains('app-check')) {
      return 'فيه مشكلة في App Check. اتأكد إن الـ debug token متسجل في Firebase.';
    }
    if (text.contains('quota')) {
      return 'خلصت الحصة المجانية بتاعة Gemini. جرب تاني بعد شوية.';
    }
    if (text.contains('not found') || text.contains('not supported')) {
      return 'موديل Gemini ده مش متاح. غيّر GEMINI_LIVE_MODEL.';
    }
    if (error is SocketException ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'مفيش إنترنت. اتأكد إن الجهاز متوصل بالإنترنت وجرب تاني.';
    }
    return 'مش قادر أتصل بـ Gemini دلوقتي. جرب تاني.';
  }

  void _fail(String message, {Object? detail}) {
    errorMessage = message;
    errorDetail = detail == null ? null : '$detail';
    micLevel.value = 0;
    _setState(HorusState.error);
  }

  void _setState(HorusState newState) {
    if (newState == HorusState.thinking && state != HorusState.thinking) {
      _thinkingSince = DateTime.now();
    }
    state = newState;
    if (newState != HorusState.listening) micLevel.value = 0;
    if (!_disposed) notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_teardown());
    micLevel.dispose();
    super.dispose();
  }
}
