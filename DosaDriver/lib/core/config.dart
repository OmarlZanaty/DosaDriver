class AppConfig {
  AppConfig._();

  /// Google Maps API key, set via --dart-define=MAPS_API_KEY=...
  /// At minimum, replace the default below with your own key.
  /// Must be set via --dart-define=MAPS_API_KEY=... during build.
  /// No default is provided — builds will fail without it.
  static const String mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
  );
}
