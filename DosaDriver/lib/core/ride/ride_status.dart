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
    case 'REQUESTED': return RideStatus.requested;
    case 'ACCEPTED':  return RideStatus.accepted;
    case 'ARRIVED':   return RideStatus.arrived;
    case 'STARTED':   return RideStatus.started;
    case 'COMPLETED': return RideStatus.completed;
    case 'CANCELED':
    case 'CANCELLED': return RideStatus.canceled;
    default:          return RideStatus.unknown;
  }
}
