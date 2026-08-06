import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists when each badge was first unlocked, since badge "unlocked"
/// state itself is recomputed live from stats and has no memory of when
/// that happened.
class BadgeUnlockService {
  static const _key = 'badge_unlock_timestamps';

  Future<Map<String, DateTime>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, DateTime.parse(v as String)));
  }

  Future<void> save(Map<String, DateTime> data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      data.map((k, v) => MapEntry(k, v.toIso8601String())),
    );
    await prefs.setString(_key, encoded);
  }
}
