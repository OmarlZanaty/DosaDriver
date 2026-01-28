import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../core/localization/localization_helper.dart';
import '../services/api_client.dart';
import '../services/ride_api.dart';
import '../services/session_store.dart';

import '../services/pricing_service.dart';
import '../services/fare_calculator.dart';
import '../models/pricing_model.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/firestore_legacy_do_not_use.dart';
import '../services/address_service.dart';
import 'client_ride_request_screen.dart';
import 'client_tracking_screen_new.dart';

enum RideType {
  
dosaFairValue,
dosaPremium,
dosaEconomy,
dosaScooter,
}



class ClientRideSelectionScreen extends StatefulWidget {
  final LatLng pickupPosition;
  final String pickupAddress; // ✅ ADD THIS


  final LatLng? destinationPosition;
  final String? destinationAddress;
  final Function(String)? onRideRequested;

  const ClientRideSelectionScreen({
    super.key,
    required this.pickupPosition,
    required this.pickupAddress,
    this.destinationPosition,
    this.destinationAddress,
    this.onRideRequested,
  });


  @override
  State<ClientRideSelectionScreen> createState() =>
      _ClientRideSelectionScreenState();
}

class _ClientRideSelectionScreenState extends State<ClientRideSelectionScreen> {

  final RideApi _rideApi = RideApi(ApiClient());
  final SessionStore _session = SessionStore();

  final AddressService _addressService = AddressService();

  final PricingService _pricingService = PricingService();

  Pricing? _pricing;
  double _surgeMultiplier = 1.0;

  GoogleMapController? _mapController;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final Map<RideType, Pricing> _pricingMap = {};

  late LatLng _pickupLocation;
  late LatLng _destinationLocation;

  bool _isRequesting = false;
  double _distance = 0.0;
  int _eta = 0;
  double _price = 0.0;
  bool _isCalculating = false;

  double _pendingPenalty = 0.0;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};


  // Premium ride only with EGP pricing
  RideType _selectedRideType = RideType.dosaPremium;

  String _rideTypeKey(RideType type) {
    switch (type) {
         case RideType.dosaFairValue:
      return 'fair_value';
    case RideType.dosaPremium:
        case RideType.dosaPremium:
      return 'premium';
    case RideType.dosaEconomy:
      return 'economic';
    case RideType.dosaScooter:
      return 'scooter';;
  }

  Future<void> _fetchAllPricing() async {
    for (final type in RideType.values) {
      final key = _rideTypeKey(type);
      _pricingMap[type] = await _pricingService.getPricing(key);
    }
    _surgeMultiplier = await _pricingService.getSurgeMultiplier();

    // ✅ SET INITIAL PRICING
    _pricing = _pricingMap[_selectedRideType];
  }

  Future<void> _fetchPendingPenalty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()?['pendingPenalty'] != null) {
      _pendingPenalty = (doc.data()!['pendingPenalty'] as num).toDouble();
    } else {
      _pendingPenalty = 0.0;
    }
  }


  @override
  void initState() {
    super.initState();
    _pickupLocation = widget.pickupPosition;

    // Use destination from parameter if provided, otherwise use default
    if (widget.destinationPosition != null) {
      _destinationLocation = widget.destinationPosition!;
      _destinationController.text =
          widget.destinationAddress ?? context.tr('destination');
    } else {
      _destinationLocation = LatLng(
        widget.pickupPosition.latitude + 0.02,
        widget.pickupPosition.longitude + 0.015,
      );
      _destinationController.text = context.tr('select_destination');
    }

    _pickupController.text = widget.pickupAddress;
    _fetchAllPricing()
        .then((_) => _fetchPendingPenalty())
        .then((_) => _calculateRoute());
  }

  Future<void> _calculateRoute() async {
    setState(() => _isCalculating = true);

    try {
      // Calculate distance
      _distance = _addressService.calculateDistance(
        _pickupLocation,
        _destinationLocation,
      );

      // Get ETA
      final eta = await _addressService.getETA(
        _pickupLocation,
        _destinationLocation,
      );

      _eta = eta ?? 0;

      if (_pricing != null) {
        final basePrice = FareCalculator.calculate(
          pricing: _pricing!,
          distanceKm: _distance,
          multiplier: _surgeMultiplier,
        );

        _price = basePrice + _pendingPenalty;

      }



      _updateMarkers();
      // Draw polyline
      _drawPolyline();

      // Fit camera to show both markers
      await Future.delayed(const Duration(milliseconds: 300));
      _fitCameraToShowBothMarkers();

      setState(() => _isCalculating = false);
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isCalculating = false);
    }
  }

  void _updateMarkers() {
    Set<Marker> newMarkers = {};

    newMarkers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: context.tr('pickup')),
      ),
    );

    newMarkers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: context.tr('destination')),
      ),
    );

    if (mounted) {
      setState(() => _markers = newMarkers);
    }
  }

  void _drawPolyline() {
    // Get actual route from Google Directions API
    _getActualRoute();
  }

  Future<void> _getActualRoute() async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${_pickupLocation.latitude},${_pickupLocation.longitude}'
          '&destination=${_destinationLocation.latitude},${_destinationLocation.longitude}'
          '&mode=driving'
          '&key=AIzaSyBT339kszEpKM4eXGoCi9eRhPnUjIBLWRs';

      debugPrint('Getting route...');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        debugPrint('Route status: ${json['status']}');

        if (json['status'] == 'OK') {
          final routes = (json['routes'] as List).cast<Map<String, dynamic>>();
          if (routes.isNotEmpty) {
            final route = routes[0];
            final overviewPolyline = route['overview_polyline'];

            if (overviewPolyline != null && overviewPolyline['points'] != null) {
              final points = _decodePolyline(overviewPolyline['points']);
              debugPrint('Decoded ${points.length} points from route');

              Set<Polyline> newPolylines = {};
              if (points.isNotEmpty) {
                newPolylines.add(
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: points,
                    color: Colors.blue,
                    width: 5,
                    geodesic: true,
                  ),
                );
              }

              if (mounted) {
                setState(() => _polylines = newPolylines);
                debugPrint('Blue polyline drawn through streets');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting route: $e');
      // Fallback to straight line if API fails
      _drawStraightLine();
    }
  }

  void _drawStraightLine() {
    Set<Polyline> newPolylines = {};
    newPolylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          _pickupLocation,
          _destinationLocation,
        ],
        color: Colors.blue,
        width: 5,
        geodesic: true,
      ),
    );

    if (mounted) {
      setState(() => _polylines = newPolylines);
      debugPrint('Fallback: straight blue line drawn');
    }
  }

  List<LatLng> _generateIntermediatePoints(LatLng start, LatLng end) {
    List<LatLng> points = [start];

    // Add 10 intermediate points for smoother curve
    for (int i = 1; i < 10; i++) {
      double lat = start.latitude + (end.latitude - start.latitude) * (i / 10);
      double lng = start.longitude + (end.longitude - start.longitude) * (i / 10);
      points.add(LatLng(lat, lng));
    }

    points.add(end);
    return points;
  }

  Future<void> _updatePolyline() async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${_pickupLocation.latitude},${_pickupLocation.longitude}'
          '&destination=${_destinationLocation.latitude},${_destinationLocation.longitude}'
          '&mode=driving'
          '&key=AIzaSyBT339kszEpKM4eXGoCi9eRhPnUjIBLWRs';

      debugPrint('🗺️ Getting route from: ${_pickupLocation.latitude},${_pickupLocation.longitude} to ${_destinationLocation.latitude},${_destinationLocation.longitude}');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        debugPrint('📍 Route status: ${json['status']}');

        if (json['status'] == 'OK') {
          final routes = (json['routes'] as List).cast<Map<String, dynamic>>();
          if (routes.isNotEmpty) {
            final route = routes[0];
            final overviewPolyline = route['overview_polyline'];

            if (overviewPolyline != null && overviewPolyline['points'] != null) {
              final encodedPoints = overviewPolyline['points'];
              debugPrint('📝 Encoded polyline length: ${encodedPoints.length}');

              final points = _decodePolyline(encodedPoints);
              debugPrint('✅ Decoded ${points.length} points');

              Set<Polyline> newPolylines = {};
              if (points.isNotEmpty) {
                final polyline = Polyline(
                  polylineId: const PolylineId('route'),
                  points: points,
                  color: AppColors.primary,
                  width: 6,
                  geodesic: true,
                );
                newPolylines.add(polyline);
                debugPrint('✏️ Polyline created with ${points.length} points');
              }

              if (mounted) {
                setState(() {
                  _polylines = newPolylines;
                  debugPrint('🎨 Polylines set: ${_polylines.length}');
                });
              }
            } else {
              debugPrint('❌ No polyline data in response');
            }
          } else {
            debugPrint('❌ No routes in response');
          }
        } else {
          debugPrint('❌ Route error: ${json['status']}');
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error getting route: $e');
    }
  }

  void _fitCameraToShowBothMarkers() {
    if (_mapController == null) {
      debugPrint('Map controller not ready, retrying...');
      Future.delayed(const Duration(milliseconds: 500), _fitCameraToShowBothMarkers);
      return;
    }

    try {
      // Create bounds that include both pickup and destination
      double minLat = math.min(_pickupLocation.latitude, _destinationLocation.latitude);
      double maxLat = math.max(_pickupLocation.latitude, _destinationLocation.latitude);
      double minLng = math.min(_pickupLocation.longitude, _destinationLocation.longitude);
      double maxLng = math.max(_pickupLocation.longitude, _destinationLocation.longitude);

      // Add padding to the bounds (40%)
      double latPadding = (maxLat - minLat) * 0.4;
      double lngPadding = (maxLng - minLng) * 0.4;

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latPadding, minLng - lngPadding),
        northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
      );

      debugPrint('Fitting camera to bounds');

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 300),
      );

      debugPrint('Camera animation triggered');
    } catch (e) {
      debugPrint('Error fitting camera: $e');
    }
  }

  void _fitCameraToRoute(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  Future<void> _requestRide() async {
    if (_isRequesting) return;

    setState(() => _isRequesting = true);

    if (_price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price calculation failed')),
      );
      setState(() => _isRequesting = false);
      return;
    }


    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('user_not_logged_in'))),
        );
        return;
      }

      final String rideTypeString = _rideTypeKey(_selectedRideType);

      // Example: "Dosa Premium", "Dosa Economy", "Dosa Scooter"

      // ================= LOG =================
      debugPrint('\n========== RIDE REQUEST DATA ==========');
      debugPrint('Client UID: ${user.uid}');
      debugPrint('Pickup Location: ${_pickupLocation.latitude}, ${_pickupLocation.longitude}');
      debugPrint('Destination Location: ${_destinationLocation.latitude}, ${_destinationLocation.longitude}');
      debugPrint('Pickup Address: ${_pickupController.text}');
      debugPrint('Destination Address: ${_destinationController.text}');
      debugPrint('Distance: ${_distance.toStringAsFixed(2)} km');
      debugPrint('ETA: $_eta minutes');
      debugPrint('Price: ${_price.toStringAsFixed(2)} EGP');
      debugPrint('Ride Type: $rideTypeString');
      debugPrint('Phone Number: ${user.phoneNumber}');
      debugPrint('========================================\n');

      // ================= CREATE RIDE =================
      // phone is required (unique). Firebase email accounts don't have phoneNumber.
      // 1) prefer dbUser.phone from backend
      // 2) fallback to locally saved phone (CompletePhoneScreen)
      final dbUser = await _session.readDbUser();
      final fallbackPhone = await _session.readFallbackPhone();
      final riderPhone = (dbUser?.phone ?? fallbackPhone ?? '').trim();

      if (riderPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('phone_required'))),
        );
        return;
      }

      final created = await _rideApi.createRide(
        pickupAddress: _pickupController.text,
        destinationAddress: _destinationController.text,
        pickupLat: _pickupLocation.latitude,
        pickupLng: _pickupLocation.longitude,
        destinationLat: _destinationLocation.latitude,
        destinationLng: _destinationLocation.longitude,
        rideType: rideTypeString,
        distanceKm: _distance,
        durationMin: _eta,
        price: _price,
        riderPhone: riderPhone,
      );

      final rideId = created.id;



      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClientRideRequestScreen(rideId: rideId),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error requesting ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isRequesting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickupLocation,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Back button
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back, color: AppColors.darkGray),
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    Widget rideTile(RideType type) {
      final pricing = _pricingMap[type];

      final price = pricing == null
          ? 0.0
          : FareCalculator.calculate(
        pricing: pricing,
        distanceKm: _distance,
        multiplier: _surgeMultiplier,
      ) +
          (_pendingPenalty > 0 ? _pendingPenalty : 0);

      final selected = _selectedRideType == type;

      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedRideType = type;
            _pricing = _pricingMap[type]; // ✅ THIS LINE

          });

          _calculateRoute(); // ✅ recalc price

        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? AppColors.primary.withOpacity(0.05)
                : AppColors.white,
          ),
          child: Row(
            children: [
              Icon(
                type == RideType.dosaPremium
                    ? Icons.directions_car
                    : type == RideType.dosaEconomy
                    ? Icons.directions_car_filled
                    : Icons.two_wheeler,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rideTypeKey(type).toUpperCase(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      type == RideType.dosaPremium
                          ? context.tr('premium_service')

                          : type == RideType.dosaEconomy
                          ? context.tr('affordable_ride')

                          : context.tr('fast_and_cheap'),

                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${price.toStringAsFixed(2)} ج.م',
                    style: AppTextStyles.headline3.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 18),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(context.tr('choose_ride'), style: AppTextStyles.headline2),
              const SizedBox(height: 16),

              // Distance & ETA
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('${_distance.toStringAsFixed(1)} km',
                            style: AppTextStyles.headline3),
                        Text(context.tr('distance'), style: AppTextStyles.bodySmall),
                      ],
                    ),
                    Column(
                      children: [
                        Text('$_eta min', style: AppTextStyles.headline3),
                        Text(context.tr('eta'), style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 🚗 Ride options
              rideTile(RideType.dosaPremium),
              rideTile(RideType.dosaEconomy),
              rideTile(RideType.dosaScooter),

              // ⚠️ Penalty (ONLY if exists)
              if (_pendingPenalty > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('includes_penalty')
                              .replaceAll('{amount}', _pendingPenalty.toStringAsFixed(2)),

                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Payment info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments,
                        color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('pay_cash_to_driver'),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Request button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _requestRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRequesting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    context.tr('request_ride')
                        .replaceAll('{type}', _rideTypeKey(_selectedRideType).toUpperCase()),

                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }




  @override
  void dispose() {
    _mapController?.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}
