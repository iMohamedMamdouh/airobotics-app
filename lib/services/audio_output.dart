import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Plays the 24 kHz mono PCM16 audio chunks streamed back by Gemini.
class AudioOutput {
  static const sampleRate = 24000;
  static const _bytesPerSecond = sampleRate * 2;

  AudioSource? _stream;
  SoundHandle? _handle;
  DateTime _playingUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// True while queued audio is still expected to be coming out of the speaker.
  bool get isPlaying => DateTime.now().isBefore(_playingUntil);

  Future<void> init() async {
    if (SoLoud.instance.isInitialized) return;
    await SoLoud.instance.init(sampleRate: sampleRate, channels: Channels.mono);
  }

  void _ensureStream() {
    if (_stream != null) return;
    final stream = _stream = SoLoud.instance.setBufferStream(
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.1,
      sampleRate: sampleRate,
      channels: Channels.mono,
      format: BufferType.s16le,
    );
    _handle = SoLoud.instance.play(stream);
  }

  void add(Uint8List pcm) {
    if (!SoLoud.instance.isInitialized || pcm.isEmpty) return;
    _ensureStream();
    SoLoud.instance.addAudioDataStream(_stream!, pcm);

    final chunk = Duration(
      microseconds: pcm.length * 1000000 ~/ _bytesPerSecond,
    );
    final now = DateTime.now();
    final start = _playingUntil.isAfter(now) ? _playingUntil : now;
    _playingUntil = start.add(chunk);
  }

  /// Immediately silences Horus (used when he is interrupted).
  Future<void> stop() async {
    _playingUntil = DateTime.fromMillisecondsSinceEpoch(0);
    final stream = _stream;
    final handle = _handle;
    _stream = null;
    _handle = null;
    if (!SoLoud.instance.isInitialized) return;
    if (handle != null && SoLoud.instance.getIsValidVoiceHandle(handle)) {
      await SoLoud.instance.stop(handle);
    }
    if (stream != null) await SoLoud.instance.disposeSource(stream);
  }
}
