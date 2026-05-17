class RideStateGuard {
  /// Backend RideStatus enum values: REQUESTED, ACCEPTED, ARRIVED, STARTED, COMPLETED, CANCELED
  static const Map<String, List<String>> allowedTransitions = {
    'REQUESTED': ['ACCEPTED', 'CANCELED'],
    'ACCEPTED': ['ARRIVED', 'CANCELED'],
    'ARRIVED': ['STARTED', 'CANCELED'],
    'STARTED': ['COMPLETED', 'CANCELED'],
    'COMPLETED': [],
    'CANCELED': [],
  };

  static bool canTransition(String from, String to) {
    final allowed = allowedTransitions[from.toUpperCase()] ?? const [];
    return allowed.contains(to.toUpperCase());
  }

  static void assertCanTransition(String from, String to) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid ride status transition: $from -> $to');
    }
  }
}
