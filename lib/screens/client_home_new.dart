import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'dart:async';
import '../core/localization/localization_helper.dart';
import '../services/address_service.dart';
import '../services/firestore_legacy_do_not_use.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../services/notification_service.dart';
import '../utils/native_notification_settings.dart';
import 'client_login_screen.dart';
import 'client_phone_login_screen.dart';
import 'client_ride_request_screen.dart';
import 'client_ride_selection_screen.dart';
import 'client_email_login_screen.dart';
import 'client_profile_screen.dart';
import 'client_ride_history_screen.dart';
import 'client_settings_screen.dart';
import 'client_tracking_screen_new.dart';
import 'client_wallet_screen.dart';
import 'client_support_screen.dart';
//import 'client_emergency_screen.dart';
import '../services/api_client.dart';
import '../services/ride_api.dart';
import '../services/session_store.dart';
import '../core/ride/ride_status.dart';


class ClientHomeNew extends StatefulWidget {
  const ClientHomeNew({super.key});

  @override
  State<ClientHomeNew> createState() => _ClientHomeNewState();
}

class _ClientHomeNewState extends State<ClientHomeNew> with WidgetsBindingObserver {

  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(31.2001, 29.9187);
  bool _pickupManuallyChanged = false;

  bool _isLoading = true;
  String _currentLocationName = '';


  LatLng? _pickupPosition;


  final AddressService _addressService = AddressService();
  //final FirestoreService _firestoreService = FirestoreService();

  final _rideApi = RideApi(ApiClient());
  final _session = SessionStore();


  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  List<AddressSuggestion> _pickupSuggestions = [];
  List<AddressSuggestion> _destinationSuggestions = [];

  bool _showPickupSuggestions = false;
  bool _showDestinationSuggestions = false;
  bool _navigatedToActiveRide = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureNotificationsEnabled();
    });

    _getUserLocation();
    _checkActiveRideFromBackend();
    WidgetsBinding.instance.addObserver(this);

  }

  bool _isActiveRideStatus(String? status) {
    final st = rideStatusFromAny(status);
    return st == RideStatus.requested ||
        st == RideStatus.accepted ||
        st == RideStatus.arrived ||
        st == RideStatus.started;
  }

  Future<void> _ensureNotificationsEnabled() async {
    final granted = await NotificationService().debugRequestAndroidPermission();
    if (!mounted) return;

    if (!granted) {
      await NativeNotificationSettings.open();
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkActiveRideFromBackend();
    }
  }

  Future<void> _checkActiveRideFromBackend() async {
    if (_navigatedToActiveRide) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final active = await _rideApi.getActiveRide();
      if (!mounted) return;

      if (active == null) return;

      final activeId = active.id.trim();
      if (activeId.isEmpty) return;

      if (!_isActiveRideStatus(active.status)) return;

      _navigatedToActiveRide = true;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ClientRideRequestScreen(rideId: activeId),
        ),
      );
    } catch (_) {}
  }




  Future<void> _getUserLocation() async {
    try {
      Location location = Location();

      // Request permission
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
      }

      if (permissionGranted != PermissionStatus.granted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Get location
      try {
        LocationData locationData = await location.getLocation();

        if (mounted && locationData.latitude != null && locationData.longitude != null) {
          setState(() {
            _currentPosition = LatLng(locationData.latitude!, locationData.longitude!);
            _isLoading = false;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
          _getAddressFromCoordinates();
        }
      } catch (e) {
        debugPrint('Location error: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          _getAddressFromCoordinates();
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _centerToCurrentLocation() async {
    try {
      Location location = Location();

      PermissionStatus permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }

      if (permission != PermissionStatus.granted) return;

      final data = await location.getLocation();
      if (data.latitude == null || data.longitude == null) return;

      final latLng = LatLng(data.latitude!, data.longitude!);

      setState(() {
        _currentPosition = latLng;
        _pickupPosition = latLng;
        _pickupController.text = _currentLocationName;
        _pickupManuallyChanged = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(latLng),
      );
    } catch (e) {
      debugPrint('❌ center location error: $e');
    }
  }

  Future<void> _getAddressFromCoordinates() async {
    try {
      if (_pickupManuallyChanged) return; // 🔥 CRITICAL

      final address = await _addressService.reverseGeocode(_currentPosition);
      if (mounted && address != null) {
        setState(() {
          _currentLocationName = address;
          _pickupController.text = address;
          _pickupPosition = _currentPosition; // 🔥 SYNC
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }


  Future<void> _searchPickupAddresses(String query) async {
    if (query.isEmpty) {
      setState(() => _pickupSuggestions = []);
      return;
    }

    try {
      final suggestions = await _addressService.searchAddress(query);
      setState(() => _pickupSuggestions = suggestions);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _searchDestinationAddresses(String query) async {
    if (query.isEmpty) {
      setState(() => _destinationSuggestions = []);
      return;
    }

    try {
      final suggestions = await _addressService.searchAddress(query);
      setState(() => _destinationSuggestions = suggestions);
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _selectPickupLocation(AddressSuggestion suggestion) {
    setState(() {
      _pickupController.text = suggestion.mainText;
      _pickupManuallyChanged = false;
      _pickupSuggestions = [];

      if (suggestion.latLng != null) {
        _pickupPosition = suggestion.latLng!;
      }
    });

    if (_pickupPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_pickupPosition!),
      );
    }
  }



  void _selectDestinationLocation(AddressSuggestion suggestion) {
    setState(() {
      _destinationController.text = suggestion.mainText;
      _showDestinationSuggestions = false;
      _destinationSuggestions = [];
    });

    if (_pickupController.text.isNotEmpty && _destinationController.text.isNotEmpty) {
      _openRideSelection(suggestion);
    }
  }

  void _openRideSelection(AddressSuggestion destinationSuggestion) {
    // Get destination coordinates
    LatLng? destinationLatLng = destinationSuggestion.latLng;

    // If no latLng, try to geocode the address
    if (destinationLatLng == null) {
      _addressService.geocodeAddress(_destinationController.text).then((latLng) {
        if (latLng != null) {
          destinationLatLng = latLng;
          _navigateToRideSelection(destinationLatLng, _destinationController.text);
        }
      });
    } else {
      _navigateToRideSelection(destinationLatLng, _destinationController.text);
    }
  }

  void _navigateToRideSelection(
      LatLng? destinationLatLng,
      String destinationAddress,
      ) async {
    if (destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(context.tr('home_invalid_destination'))),

      );
      return;
    }

    // 🔥 FORCE pickup to be valid
    if (_pickupPosition == null) {
      final latLng = await _addressService.geocodeAddress(
        _pickupController.text,
      );

      if (latLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(context.tr('home_invalid_pickup'))),

        );
        return;
      }

      _pickupPosition = latLng;
    }

    debugPrint(
      '📍 FINAL PICKUP = ${_pickupPosition!.latitude}, ${_pickupPosition!.longitude}',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientRideSelectionScreen(
          pickupPosition: _pickupPosition!,
          pickupAddress: _pickupController.text,
          destinationPosition: destinationLatLng,
          destinationAddress: destinationAddress,
          onRideRequested: (rideId) {},
        ),
      ),
    );
  }


  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.primary),
              title: Text(context.tr('menu_profile')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: Text(context.tr('menu_history')),

              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientRideHistoryScreen()));
              },
            ),
            /*ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
              title: const Text('Wallet'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientWalletScreen()));
              },
            ),*/
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.primary),
              title: Text(context.tr('menu_settings')),

              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientSettingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.help, color: AppColors.primary),
              title: Text(context.tr('menu_support')),

              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientSupportScreen()));
              },
            ),
            /*ListTile(
              leading: const Icon(Icons.emergency, color: AppColors.primary),
              title: const Text('Emergency & Safety'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientEmergencyScreen()));
              },
            ),*/
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                context.tr('menu_logout'),
                style: const TextStyle(color: Colors.red),
              ),

              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await _session.clearAll();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientLoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // If not logged in, show login screen
    if (user == null) {
      return const ClientLoginScreen();
    }


    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {
                      debugPrint('Menu tapped');
                      _showMenuBottomSheet();
                    },
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
                      child: const Icon(Icons.menu, color: AppColors.darkGray, size: 24),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {},
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
                      child: const Icon(Icons.fullscreen, color: AppColors.darkGray, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📍 CURRENT LOCATION BUTTON
          Positioned(
            bottom: 250, // ⬅️ above bottom sheet
            right: 16,
            child: FloatingActionButton(
              backgroundColor: AppColors.primary,
              elevation: 6,
              onPressed: _centerToCurrentLocation,
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
              ),
            ),
          ),


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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ================= PICKUP =================
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white, // ✅ REMOVE BLUE
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red, // 🔴 thin red border
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: TypeAheadField<AddressSuggestion>(
                        direction: AxisDirection.up,

                        textFieldConfiguration: TextFieldConfiguration(
                          controller: _pickupController,
                          decoration:  InputDecoration(
                            hintText: context.tr('pickup_hint'),

                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            _pickupManuallyChanged = true;
                            _pickupPosition = null; // 🔥 INVALIDATE OLD COORDS
                            _searchPickupAddresses(value);
                          },

                        ),

                        suggestionsCallback: (_) => _pickupSuggestions,
                        debounceDuration:
                        const Duration(milliseconds: 400),

                        suggestionsBoxDecoration:
                        SuggestionsBoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          constraints:
                          const BoxConstraints(maxHeight: 260),
                        ),

                        itemBuilder: (_, s) => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            s.mainText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        onSuggestionSelected:
                        _selectPickupLocation,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ================= DESTINATION =================
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white, // ✅ REMOVE BLUE
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red, // 🔴 thin red border
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: TypeAheadField<AddressSuggestion>(
                        direction: AxisDirection.up,

                        textFieldConfiguration: TextFieldConfiguration(
                          controller: _destinationController,
                          decoration:  InputDecoration(
                            hintText: context.tr('destination_hint'),

                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            _searchDestinationAddresses(value);
                          },
                        ),

                        suggestionsCallback: (_) =>
                        _destinationSuggestions,

                        suggestionsBoxDecoration:
                        SuggestionsBoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          constraints:
                          const BoxConstraints(maxHeight: 260),
                        ),

                        itemBuilder: (_, s) => Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            s.mainText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        onSuggestionSelected:
                        _selectDestinationLocation,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _mapController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
