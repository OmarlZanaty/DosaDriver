enum RideStatus {
  requested,
  accepted,
  arrived,
  started,
  completed,
  canceled,
  unknown,
}

RideStatus rideStatusFromAny(String? raw) {
  if (raw == null) return RideStatus.unknown;
  final v = raw.trim().toUpperCase();

  switch (v) {
    case 'REQUESTED':
      return RideStatus.requested;
    case 'ACCEPTED':
      return RideStatus.accepted;
    case 'ARRIVED':
      return RideStatus.arrived;
    case 'STARTED':
      return RideStatus.started;
    case 'COMPLETED':
      return RideStatus.completed;

  // backend canonical
    case 'CANCELED':
    // old typo
    case 'CANCELLED':
      return RideStatus.canceled;

  // legacy mapping (if you still have it somewhere)
    case 'ON_THE_WAY':
      return RideStatus.started;

    default:
      return RideStatus.unknown;
  }
}

String rideStatusToApi(RideStatus s) {
  switch (s) {
    case RideStatus.requested:
      return 'REQUESTED';
    case RideStatus.accepted:
      return 'ACCEPTED';
    case RideStatus.arrived:
      return 'ARRIVED';
    case RideStatus.started:
      return 'STARTED';
    case RideStatus.completed:
      return 'COMPLETED';
    case RideStatus.canceled:
      return 'CANCELED';
    case RideStatus.unknown:
      return 'UNKNOWN';
  }
}
