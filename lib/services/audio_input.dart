import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Streams raw 16 kHz mono PCM16 from the microphone, which is what the
/// Gemini Live API expects as input.
class AudioInput {
  static const sampleRate = 16000;
  static const mimeType = 'audio/pcm;rate=$sampleRate';

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _dataSub;
  StreamSubscription<Amplitude>? _ampSub;

  Future<bool> hasPermission() =>
      (_recorder ??= AudioRecorder()).hasPermission();

  /// Starts recording. [onLevel] receives a 0..1 loudness value.
  Future<void> start({
    required void Function(Uint8List data) onData,
    void Function(double level)? onLevel,
  }) async {
    await stop();
    // A fresh recorder per session avoids "stream already listened to" errors.
    final recorder = _recorder = AudioRecorder();
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        androidConfig: AndroidRecordConfig(
          // Enables the platform echo canceller so Horus hears the visitor,
          // not his own voice.
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
      ),
    );
    _dataSub = stream.listen((data) {
      if (data.isNotEmpty) onData(data);
    });
    if (onLevel != null) {
      _ampSub = recorder
          .onAmplitudeChanged(const Duration(milliseconds: 80))
          .listen((amp) {
            // Map roughly -50..0 dBFS to 0..1.
            onLevel(((amp.current + 50) / 50).clamp(0.0, 1.0));
          });
    }
  }

  Future<void> stop() async {
    await _dataSub?.cancel();
    await _ampSub?.cancel();
    _dataSub = null;
    _ampSub = null;
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (_) {}
      await recorder.dispose();
    }
  }
}
