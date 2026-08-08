import 'package:shared_preferences/shared_preferences.dart';

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
}
