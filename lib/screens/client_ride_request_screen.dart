import 'package:DosaDriver/core/localization/localization_helper.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/cancellation_service.dart';
import 'client_tracking_screen_new.dart';
import 'client_home_new.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_client.dart';
import '../services/ride_api.dart';
import '../services/session_store.dart';
import '../core/ride/ride_status.dart';



class ClientRideRequestScreen extends StatefulWidget {
  final String rideId;

  const ClientRideRequestScreen({super.key, required this.rideId});

  @override
  State<ClientRideRequestScreen> createState() =>
      _ClientRideRequestScreenState();
}

class _ClientRideRequestScreenState extends State<ClientRideRequestScreen> with WidgetsBindingObserver {

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rideSub;
  String _activeRideId = '';

  final RideApi _rideApi = RideApi(ApiClient());
  final SessionStore _session = SessionStore();


  String _rideStatus = 'requested';
  String _pickupAddress = '';
  String _destinationAddress = '';
  double _estimatedFare = 0.0;
  String _rideType = '';
  bool _navigating = false;

  String get _effectiveRideId {
    final a = _activeRideId.trim();
    if (a.isNotEmpty) return a;
    return widget.rideId.trim();
  }
  Future<void> _initAndSubscribe() async {
    try {
      final active = await _rideApi.getActiveRide();
      if (!mounted) return;

      // no active ride => go home
      if (active == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientHomeNew()),
        );
        return;
      }

      _activeRideId = active.id.trim();
      if (_activeRideId.isEmpty) return;

      final rideId = _effectiveRideId; // now will be active id
      _subscribeToRideMirror(rideId);

    } catch (_) {
      // fallback to widget id if backend fails
      final rideId = _effectiveRideId;
      if (rideId.isNotEmpty) _subscribeToRideMirror(rideId);
    }
  }

  void _subscribeToRideMirror(String rideId) {
    _rideSub?.cancel();

    _rideSub = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;

      final statusRaw = (data['status'] ?? 'REQUESTED').toString();

      final pickupAddr =
      (data['pickup'] is Map ? (data['pickup']['addr'] ?? '') : '').toString();
      final dropAddr =
      (data['drop'] is Map ? (data['drop']['addr'] ?? '') : '').toString();

      // optional fields if backend sends them later
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
      final rideType = (data['rideType'] ?? '').toString();

      if (!mounted) return;
      setState(() {
        _rideStatus = statusRaw;
        _pickupAddress = pickupAddr;
        _destinationAddress = dropAddr;
        _estimatedFare = price;
        _rideType = rideType;
      });

      await _routeByStatus(statusRaw);
    });
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAndSubscribe();
  }



  Future<void> _routeByStatus(String status) async {
    if (_navigating) return;

    final st = rideStatusFromAny(status);
    final rideId = _effectiveRideId;

// If no ride id, do nothing
    if (rideId.isEmpty) return;

    if (st == RideStatus.accepted || st == RideStatus.arrived || st == RideStatus.started) {
      _navigating = true;
      _rideSub?.cancel();
      _rideSub = null;


      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ClientTrackingScreenNew(rideId: rideId)),
      );
      return;
    }

    if (st == RideStatus.canceled) {
      _navigating = true;
      _rideSub?.cancel();
      _rideSub = null;


      if (!mounted) return;
      _showCancelledDialog();
      return;
    }

// else: requested (stay here)

    // else: requested (stay here)
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _rideSub?.cancel();
      _rideSub = null;
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final rideId = _effectiveRideId;
      if (rideId.isNotEmpty) _subscribeToRideMirror(rideId);
    }
  }

  /// Show cancelled dialog
  void _showCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            title: Text(context.tr('ride_cancelled')),
            content: Text(context.tr('ride_cancelled_message')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ClientHomeNew()),
                  );
                },
                child: Text(context.tr('ok')),

              ),
            ],
          ),
    );
  }

  final CancellationService _cancellationService =
  CancellationService();

  Future<void> _cancelRide() async {
    try {
      final rideId = _effectiveRideId;

      if (rideId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('error_try_again'))),
        );
        return;
      }

      await _rideApi.cancelRide(rideId);

      if (!mounted) return;
      _rideSub?.cancel();
      _rideSub = null;


      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ClientHomeNew()),
      );
    } catch (e) {
      debugPrint('❌ Error cancelling ride: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkGray),
          onPressed: () async {
            await _cancelRide();
          },
        ),
        title: Text(
          context.tr('finding_captain_loading'),
          style: AppTextStyles.headline2,
        ),
      ),

      body: Stack(
        children: [
          // MAIN CONTENT
          SingleChildScrollView(
            child: Column(
              children: [
                // Waiting Animation
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight,
                        ),
                        child: Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.directions_car,
                                color: AppColors.white,
                                size: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        context.tr('finding_captain_loading'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('searching_best_captain'),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.mediumGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLoadingDot(0),
                          const SizedBox(width: 8),
                          _buildLoadingDot(1),
                          const SizedBox(width: 8),
                          _buildLoadingDot(2),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),

                // Ride Details Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ride Type
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _rideType,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pickup
                      _buildLocationRow(
                        iconColor: AppColors.success,
                        bgColor: AppColors.successLight,
                        title: context.tr('pickup'),
                        value: _pickupAddress,
                      ),

                      const SizedBox(height: 16),
                      Divider(color: AppColors.divider),
                      const SizedBox(height: 16),

                      // Destination
                      _buildLocationRow(
                        iconColor: AppColors.error,
                        bgColor: AppColors.errorLight,
                        title: context.tr('destination'),
                        value: _destinationAddress,
                      ),

                      const SizedBox(height: 16),

                      // Fare
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('estimated_fare'),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.mediumGray,
                              ),
                            ),
                            Text(
                              '\$${_estimatedFare.toStringAsFixed(2)}',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Cancel Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _cancelRide,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.tr('cancel_ride'),
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 80), // space for FAB
              ],
            ),
          ),


        ],
      ),
    );
  }

  /// Build pickup / destination row
  Widget _buildLocationRow({
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.location_on,
              color: iconColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.mediumGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }


  /// Build loading dot
  Widget _buildLoadingDot(int index) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.3 + (index * 0.2)),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rideSub?.cancel();
    _rideSub = null;

    super.dispose();
  }
}