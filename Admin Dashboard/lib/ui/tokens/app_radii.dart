/// Corner radii used throughout the application. Define a handful
/// of radii sizes so that you can quickly pick an appropriate
/// curvature without hard‑coding values.
class AppRadii {
  AppRadii._();

  /// Small radius, used for chips and small buttons (8px).
  static const double sm = 8.0;

  /// Medium radius, used for inputs and medium sized cards (12px).
  static const double md = 12.0;

  /// Large radius, used for primary cards and dialogs (16px).
  static const double lg = 16.0;

  /// Extra large radius used on very rounded components like avatars.
  static const double xl = 22.0;

  /// Fully rounded radius for pill shapes.
  static const double full = 999.0;
}