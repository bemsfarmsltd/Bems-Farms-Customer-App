class ApiConstants {
  static const String baseUrl = 'https://api.bemsfarms.com/api';
  static const String appVersion = '1.0.1';

  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36 BemsFarmsMobile/$appVersion';

  static Map<String, String> defaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': userAgent,
      'Origin': 'https://bemsfarms.com',
      'Referer': 'https://bemsfarms.com/',
      'X-App-Version': appVersion,
      'X-App-Platform': 'android',
    };
  }

  static Map<String, String> authHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/plain, */*',
      'Authorization': 'Bearer $token',
      'User-Agent': userAgent,
      'Origin': 'https://bemsfarms.com',
      'Referer': 'https://bemsfarms.com/',
      'X-App-Version': appVersion,
      'X-App-Platform': 'android',
    };
  }
}
