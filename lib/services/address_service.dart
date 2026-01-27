import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import '../config/app_config.dart';

/// Model for address suggestion
class AddressSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  LatLng? latLng;

  AddressSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.latLng,
  });

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'] ?? '',
      secondaryText: json['structured_formatting']?['secondary_text'] ?? '',
    );
  }
}

/// Service for address search and geocoding
class AddressService {
  // TODO: Replace with your actual Google API key from Google Cloud Console
  // Get key from: https://console.cloud.google.com/
  static const String _googleApiKey = AppConfig.googleApiKey;
  static const String _googleMapsApiKey = AppConfig.googleMapsApiKey;


  // Google Places Autocomplete endpoint
  static const String _placesAutocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  // Google Places Details endpoint
  static const String _placesDetailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  // Google Directions endpoint
  static const String _directionsUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Search for address suggestions based on input
  Future<List<AddressSuggestion>> searchAddress(
      String input, {
        LatLng? bias,
      }) async {
    if (input.isEmpty) return [];

    try {
      final String url = '$_placesAutocompleteUrl'
          '?input=$input'
          '&key=$_googleApiKey'
          '&components=country:eg'
          '${bias != null ? '&location=${bias.latitude},${bias.longitude}&radius=50000' : ''}';

      print('🔍 Searching: $input');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ Search timeout');
          return http.Response('timeout', 408);
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('✅ Found ${json['predictions']?.length ?? 0} results');

        if (json['predictions'] != null) {
          final predictions = (json['predictions'] as List).cast<Map<String, dynamic>>();
          return predictions.map((p) => AddressSuggestion.fromJson(p)).toList();
        }
      } else {
        print('❌ Search error: ${response.statusCode} - ${response.body}');
      }
      return [];
    } catch (e) {
      print('❌ Error searching address: $e');
      return [];
    }
  }

  /// Get place details including coordinates
  Future<AddressSuggestion?> getPlaceDetails(String placeId) async {
    try {
      final String url = '$_placesDetailsUrl'
          '?place_id=$placeId'
          '&key=$_googleApiKey'
          '&fields=geometry,formatted_address,name';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result'];

        if (result != null) {
          final geometry = result['geometry'];
          final location = geometry['location'];

          return AddressSuggestion(
            placeId: placeId,
            description: result['formatted_address'] ?? '',
            mainText: result['name'] ?? '',
            secondaryText: result['formatted_address'] ?? '',
            latLng: LatLng(
              location['lat'].toDouble(),
              location['lng'].toDouble(),
            ),
          );
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting place details: $e');
      return null;
    }
  }

  /// Geocode address to LatLng
  Future<LatLng?> geocodeAddress(String address) async {
    try {
      final locations = await geo.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return LatLng(location.latitude, location.longitude);
      }
      return null;
    } catch (e) {
      print('❌ Error geocoding address: $e');
      return null;
    }
  }

  /// Reverse geocode LatLng to address
  Future<String?> reverseGeocode(LatLng latLng) async {
    try {
      print('🔄 Reverse geocoding: ${latLng.latitude}, ${latLng.longitude}');
      final placemarks = await geo.placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address =
        '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}'
            .replaceAll(RegExp(r',\s*,'), ',')
            .replaceAll(RegExp(r',\s*$'), '')
            .trim();
        print('✅ Address: $address');
        return address;
      }
      return null;
    } catch (e) {
      print('❌ Error reverse geocoding: $e');
      return null;
    }
  }

  /// Calculate distance between two points (in km)
  double calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(to.latitude - from.latitude);
    final double dLng = _degreesToRadians(to.longitude - from.longitude);

    final double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_degreesToRadians(from.latitude)) *
            math.cos(_degreesToRadians(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2));

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Get ETA between two points
  Future<int?> getETA(LatLng from, LatLng to) async {
    try {
      final String url = '$_directionsUrl'
          '?origin=${from.latitude},${from.longitude}'
          '&destination=${to.latitude},${to.longitude}'
          '&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final routes = (json['routes'] as List).cast<Map<String, dynamic>>();

        if (routes.isNotEmpty) {
          final legs = routes[0]['legs'] as List;
          if (legs.isNotEmpty) {
            final duration = legs[0]['duration']['value'] as int;
            return (duration / 60).ceil(); // Convert to minutes
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting ETA: $e');
      return null;
    }
  }

  /// Get distance between two points using Directions API
  Future<double?> getDistance(LatLng from, LatLng to) async {
    try {
      final String url = '$_directionsUrl'
          '?origin=${from.latitude},${from.longitude}'
          '&destination=${to.latitude},${to.longitude}'
          '&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final routes = (json['routes'] as List).cast<Map<String, dynamic>>();

        if (routes.isNotEmpty) {
          final legs = routes[0]['legs'] as List;
          if (legs.isNotEmpty) {
            final distance = legs[0]['distance']['value'] as int;
            return distance / 1000; // Convert to km
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting distance: $e');
      return null;
    }
  }

  /// Calculate fare based on distance
  double calculateFare(double distanceKm, {String rideType = 'economy'}) {
    double baseFare = 5.0;
    double perKmRate = 2.0;

    // Adjust rates based on ride type
    switch (rideType.toLowerCase()) {
      case 'comfort':
        baseFare = 7.0;
        perKmRate = 2.5;
        break;
      case 'premium':
        baseFare = 10.0;
        perKmRate = 3.0;
        break;
      default:
        baseFare = 5.0;
        perKmRate = 2.0;
    }

    return baseFare + (distanceKm * perKmRate);
  }
}
