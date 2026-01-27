class AppConfig {
  /// Cloud Run base URL (no trailing slash)
  static const String baseUrl =
      'https://dosadriver-api-1056710019958.me-central1.run.app';

  // ✅ Put the real key as a normal string
  static const String googleApiKey = 'AIzaSyBT339kszEpKM4eXGoCi9eRhPnUjIBLWRs';
  static const String googleMapsApiKey = 'AIzaSyBT339kszEpKM4eXGoCi9eRhPnUjIBLWRs';

  /// API version prefix used by backend
  static const String apiPrefix = '/v1';
}
