class ApiConfig {
  // ✅ New backend server IP — HTTP (bare IPs don't support HTTPS)
  static const String baseUrl = 'http://35.222.75.137:8080';

  static const String apiPrefix = '/v1';

  static String url(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$p';
  }

  static String api(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$apiPrefix$p';
  }
}