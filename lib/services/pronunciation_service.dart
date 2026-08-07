import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Plays a word's pronunciation. Prefers the dictionary-provided audio clip
/// when available (downloaded once and cached locally, so repeat plays are
/// instant instead of re-fetching over the network every time), and falls
/// back to on-device text-to-speech otherwise (e.g. for custom/quick-added
/// words with no dictionary audio, or if the fetch fails/times out — the
/// dictionaryapi.dev audio CDN has turned out to be unreliable in practice,
/// often returning 502s, so failures need to degrade fast rather than make
/// every tap wait out a long timeout).
class PronunciationService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsConfigured = false;
  Directory? _cacheDir;

  // Tracked locally instead of querying the player/TTS engine every call —
  // stop() on either has real latency on Windows even when nothing is
  // playing, so calling it unconditionally on every tap made playback feel
  // laggy. Only stop() when something is actually in flight.
  bool _isPlaying = false;

  // URLs that failed this session — skipped on later taps so a
  // consistently-broken clip (e.g. a 502 from the CDN) doesn't cost a
  // fresh timeout every single time; falls straight to TTS instead.
  final Set<String> _knownBadUrls = {};

  PronunciationService() {
    _audioPlayer.onPlayerComplete.listen((_) => _isPlaying = false);
    _tts.setCompletionHandler(() => _isPlaying = false);
    _tts.setCancelHandler(() => _isPlaying = false);
    _tts.setErrorHandler((_) => _isPlaying = false);
  }

  Future<Directory> _ensureCacheDir() async {
    final cached = _cacheDir;
    if (cached != null) return cached;
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docsDir.path, 'audio_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Returns the locally-cached file for [audioUrl], downloading it first
  /// if this is the first time it's been played. Returns null (so the
  /// caller can fall back to TTS) if the download fails, times out, or is
  /// already known to be broken this session.
  Future<File?> _cachedAudioFile(String audioUrl) async {
    if (_knownBadUrls.contains(audioUrl)) return null;

    final dir = await _ensureCacheDir();
    final uri = Uri.parse(audioUrl);
    final filename = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : audioUrl.hashCode.toString();
    final file = File(p.join(dir.path, filename));
    if (await file.exists()) return file;

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        _knownBadUrls.add(audioUrl);
        return null;
      }
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (_) {
      _knownBadUrls.add(audioUrl);
      return null;
    }
  }

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
    // Cut off whatever's still playing first — the Windows TTS engine only
    // has one voice channel, so a rapid second tap gets silently dropped
    // unless the in-flight utterance/clip is stopped before starting a new
    // one. Only bother stopping if something is actually in flight — stop()
    // has real latency on Windows even as a no-op, and most taps land after
    // the previous playback already finished.
    if (_isPlaying) {
      await _audioPlayer.stop();
      await _tts.stop();
    }
    _isPlaying = true;

    if (audioUrl != null && audioUrl.isNotEmpty) {
      final cachedFile = await _cachedAudioFile(audioUrl);
      if (cachedFile != null) {
        try {
          await _audioPlayer.play(
            DeviceFileSource(cachedFile.path),
            volume: volume,
          );
          return;
        } catch (_) {
          // Fall through to TTS below.
        }
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
