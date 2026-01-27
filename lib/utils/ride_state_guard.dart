enum RideStatus {
  requested,
  accepted,
  onTheWay,
  arrived,
  started,
  completed,
  cancelled,
}

class RideStateGuard {
  static const Map<String, List<String>> allowedTransitions = {
    'requested': ['accepted', 'cancelled'],
    'accepted': ['on_the_way', 'cancelled'],
    'on_the_way': ['arrived', 'cancelled'],
    'arrived': ['started', 'cancelled'],
    'started': ['completed', 'cancelled'],
    'completed': [],
    'cancelled': [],
  };

  static bool canTransition(String from, String to) {
    final allowed = allowedTransitions[from] ?? const [];
    return allowed.contains(to);
  }

  static void assertCanTransition(String from, String to) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid ride status transition: $from -> $to');
    }
  }
}
