import 'dart:convert';

import 'package:http/http.dart' as http;

/// A newer release than the currently-installed version, if one exists.
class UpdateInfo {
  final String latestVersion;
  final String releaseUrl;
  const UpdateInfo({required this.latestVersion, required this.releaseUrl});
}

/// Checks GitHub Releases for a version newer than the one currently
/// running — detection only, no auto-download/auto-install. The user
/// decides whether and when to grab the update themselves (see README for
/// the manual install steps). Fails silently (returns null) on any
/// network/parse error, since this is a non-critical, best-effort check.
class UpdateCheckService {
  static const _apiUrl =
      'https://api.github.com/repos/Dokya0513/Huetan/releases/latest';

  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'];
      final htmlUrl = data['html_url'];
      if (tagName is! String || htmlUrl is! String) return null;

      final latestVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;
      if (!_isNewer(latestVersion, currentVersion)) return null;

      return UpdateInfo(latestVersion: latestVersion, releaseUrl: htmlUrl);
    } catch (_) {
      return null;
    }
  }

  /// Simple dotted-numeric version comparison ("1.10.0" > "1.9.0"). Treats
  /// any unparseable segment as 0, and a shorter version's missing trailing
  /// segments as 0 too, so "1.5" vs "1.5.0" compares equal.
  bool _isNewer(String a, String b) {
    final partsA = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final length = partsA.length > partsB.length
        ? partsA.length
        : partsB.length;
    for (var i = 0; i < length; i++) {
      final segA = i < partsA.length ? partsA[i] : 0;
      final segB = i < partsB.length ? partsB[i] : 0;
      if (segA != segB) return segA > segB;
    }
    return false;
  }
}
