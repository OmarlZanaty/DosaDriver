class ApiConfig {
  // ✅ Always NO trailing slash here
  static const String baseUrl = 'https://dosadriver-api-1056710019958.me-central1.run.app';

  // ✅ Always starts with /
  static const String apiPrefix = '/v1';

  /// ✅ Safe join: never produces ".appadmin"
  static String url(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$p';
  }

  /// ✅ Safe API join: /v1 + /admin/me
  static String api(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$apiPrefix$p';
  }
}