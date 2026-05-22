class AppConfig {
  AppConfig._();

  /// Google Maps / Directions API key.
  /// Override at build time via --dart-define=MAPS_API_KEY=<key>.
  /// Falls back to the shared project key when no define is supplied
  /// (e.g. during local development / hot-reload).
  static const String mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyBT339kszEpKM4eXGoCi9eRhPnUjIBLWRs',
  );
}
