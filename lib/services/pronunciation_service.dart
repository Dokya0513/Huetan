import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Plays a word's pronunciation. Prefers the dictionary-provided audio clip
/// when available, and falls back to on-device text-to-speech otherwise
/// (e.g. for custom/quick-added words with no dictionary audio).
class PronunciationService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsConfigured = false;

  Future<void> _ensureTtsConfigured() async {
    if (_ttsConfigured) return;
    await _tts.setLanguage('en-US');

    // setLanguage alone isn't always enough on Windows/SAPI: if no voice is
    // installed for that language, the engine silently keeps using the
    // system default voice (e.g. Japanese on a ja-JP machine). Explicitly
    // pick an installed English voice when one exists.
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final englishVoice = voices.cast<Object?>().firstWhere(
          (voice) {
            if (voice is! Map) return false;
            final locale = voice['locale']?.toString().toLowerCase() ?? '';
            return locale.startsWith('en');
          },
          orElse: () => null,
        );
        if (englishVoice is Map) {
          await _tts.setVoice({
            'name': englishVoice['name'].toString(),
            'locale': englishVoice['locale'].toString(),
          });
        }
      }
    } catch (_) {
      // Voice enumeration isn't supported on every platform; ignore.
    }

    _ttsConfigured = true;
  }

  Future<void> speak(
    String english, {
    String? audioUrl,
    double volume = 1.0,
  }) async {
    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.play(UrlSource(audioUrl), volume: volume);
        return;
      } catch (_) {
        // Fall through to TTS below.
      }
    }
    await _ensureTtsConfigured();
    await _tts.setVolume(volume);
    await _tts.speak(english);
  }

  void dispose() {
    _audioPlayer.dispose();
    _tts.stop();
  }
}
