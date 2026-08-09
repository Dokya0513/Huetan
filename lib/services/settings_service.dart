import 'package:shared_preferences/shared_preferences.dart';

import '../models/learning_direction.dart';

const double defaultVolume = 1.0;

enum VolumeChannel {
  soundEffect('se_volume'),
  voice('voice_volume');

  final String prefsKey;
  const VolumeChannel(this.prefsKey);
}

/// Persists user-adjustable app settings. Sound-effect volume (correct
/// answer chime) and voice volume (pronunciation / TTS) are stored
/// separately so the user can balance them independently.
class SettingsService {
  static const _darkModeKey = 'dark_mode';
  static const _onboardingSeenKey = 'onboarding_seen';
  static const _learningModeKey = 'learning_mode';
  static const _lastCloudSyncAtKey = 'last_cloud_sync_at';

  Future<double> loadVolume(VolumeChannel channel) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(channel.prefsKey) ?? defaultVolume;
  }

  Future<void> saveVolume(VolumeChannel channel, double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(channel.prefsKey, volume);
  }

  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }

  Future<bool> loadOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> saveOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  Future<LearningDirection> loadLearningMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_learningModeKey);
    return raw == null
        ? LearningDirection.enTarget
        : LearningDirection.fromDbValue(raw);
  }

  Future<void> saveLearningMode(LearningDirection mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_learningModeKey, mode.dbValue);
  }

  /// The cloud backup timestamp this device has already "dealt with" —
  /// either by uploading (making the cloud match this exact moment) or by
  /// downloading/dismissing a newer one. Used to decide whether to prompt
  /// "there's newer data in the cloud" on launch, without re-prompting for
  /// the same cloud version every time.
  Future<DateTime?> loadLastCloudSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastCloudSyncAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveLastCloudSyncAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCloudSyncAtKey, time.toIso8601String());
  }
}
