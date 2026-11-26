import 'dart:convert';
import 'package:http/http.dart' as http;
import '../network/api_constants.dart';

class AppUpdateInfo {
  final String minimumVersion;
  final String latestVersion;
  final String downloadUrl;
  final bool forceUpdate;
  final String releaseNotes;
  final bool isUpdateRequired;

  const AppUpdateInfo({
    required this.minimumVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.isUpdateRequired,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json, String currentVersion, String appType) {
    Map<String, dynamic> data = json;
    if (json[appType] is Map<String, dynamic>) {
      data = json[appType];
    } else if (json['data'] is Map<String, dynamic>) {
      if (json['data'][appType] is Map<String, dynamic>) {
        data = json['data'][appType];
      } else {
        data = json['data'];
      }
    }

    final minVer = (data['minimum_version'] ?? data['min_version'] ?? '1.0.0').toString();
    final latestVer = (data['latest_version'] ?? data['current_version'] ?? minVer).toString();
    
    // Dedicated 1-click APK direct download endpoint from backend
    final defaultUrl = appType == 'driver'
        ? 'https://api.bemsfarms.com/api/app-releases/download/driver'
        : 'https://api.bemsfarms.com/api/app-releases/download/customer';

    String url = (data['download_url'] ?? data['url'] ?? defaultUrl).toString();
    // If backend returns a generic website URL without .apk or release endpoint, use the direct 1-click download link
    if (url.trim().isEmpty || url == 'https://bemsfarms.com/download' || url == 'https://bemsfarms.com') {
      url = defaultUrl;
    }

    final force = data['force_update'] == true || data['is_mandatory'] == true;
    final notes = (data['release_notes'] ?? data['message'] ?? 'A new version with important updates is available.').toString();

    final isOlder = AppUpdateService.isVersionOlder(currentVersion, minVer);
    final required = force || isOlder;

    return AppUpdateInfo(
      minimumVersion: minVer,
      latestVersion: latestVer,
      downloadUrl: url,
      forceUpdate: force,
      releaseNotes: notes,
      isUpdateRequired: required && isOlder,
    );
  }
}

class AppUpdateService {
  static const String currentAppVersion = '1.0.1';

  /// Compare two semantic version strings (e.g., "1.0.0" vs "1.0.1")
  /// Returns true if [installed] is strictly older than [minimumRequired].
  static bool isVersionOlder(String installed, String minimumRequired) {
    try {
      List<int> parse(String v) => v
          .split('.')
          .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();

      final curr = parse(installed);
      final min = parse(minimumRequired);

      final maxLength = curr.length > min.length ? curr.length : min.length;
      for (int i = 0; i < maxLength; i++) {
        final c = i < curr.length ? curr[i] : 0;
        final m = i < min.length ? min[i] : 0;
        if (c < m) return true;
        if (c > m) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Checks remote API or website JSON for minimum required version with real-time cache busting
  static Future<AppUpdateInfo?> checkUpdate({String appType = 'customer'}) async {
    final client = http.Client();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final endpoints = [
      '${ApiConstants.baseUrl}/app-version?_t=$timestamp',
      '${ApiConstants.baseUrl}/version?_t=$timestamp',
      'https://bemsfarms.com/app-version.json?_t=$timestamp',
      'https://bemsfarms.com/version.json?_t=$timestamp',
    ];

    final headers = {
      ...ApiConstants.defaultHeaders(),
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
    };

    for (final url in endpoints) {
      try {
        final res = await client
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200 && res.body.trim().startsWith('{')) {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            return AppUpdateInfo.fromJson(decoded, currentAppVersion, appType);
          }
        }
      } catch (_) {
        // Fallback to next endpoint
      }
    }

    client.close();
    return null;
  }
}
