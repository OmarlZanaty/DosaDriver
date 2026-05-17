import 'package:google_maps_flutter/google_maps_flutter.dart';

class Ride {
  final String id;
  final LatLng pickup;
  final LatLng destination;
  final String status;

  Ride({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.status,
  });
}
