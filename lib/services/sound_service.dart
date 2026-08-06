import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Plays a short, in-code-synthesized success chime on correct answers.
/// No bundled audio asset is needed — the PCM waveform is generated at
/// runtime and wrapped in a minimal WAV header.
class SoundService {
  final AudioPlayer _player = AudioPlayer();
  late final Uint8List _successChime = _generateChime([
    523.25, // C5
    659.25, // E5
    783.99, // G5
  ]);

  Future<void> playCorrect({double volume = 1.0}) async {
    await _player.play(BytesSource(_successChime), volume: volume);
  }

  void dispose() => _player.dispose();

  static Uint8List _generateChime(
    List<double> frequencies, {
    int sampleRate = 44100,
    double noteDuration = 0.11,
  }) {
    final samplesPerNote = (sampleRate * noteDuration).round();
    final samples = Int16List(samplesPerNote * frequencies.length);

    var index = 0;
    for (final frequency in frequencies) {
      for (var i = 0; i < samplesPerNote; i++) {
        final t = i / sampleRate;
        // Half-sine envelope avoids clicks at the start/end of each note.
        final envelope = sin(pi * i / samplesPerNote);
        final value = sin(2 * pi * frequency * t) * envelope * 0.3;
        samples[index++] = (value * 32767).round().clamp(-32768, 32767);
      }
    }
    return _wrapAsWav(samples, sampleRate);
  }

  static Uint8List _wrapAsWav(Int16List samples, int sampleRate) {
    const bitsPerSample = 16;
    const channels = 1;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = samples.length * 2;

    final buffer = BytesBuilder();
    void writeString(String s) => buffer.add(s.codeUnits);
    void writeUint32(int v) => buffer.add([
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);
    void writeUint16(int v) => buffer.add([v & 0xFF, (v >> 8) & 0xFF]);

    writeString('RIFF');
    writeUint32(36 + dataLength);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    writeString('data');
    writeUint32(dataLength);
    for (final sample in samples) {
      writeUint16(sample & 0xFFFF);
    }
    return buffer.toBytes();
  }
}
