import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/checkout/presentation/providers/checkout_provider.dart';

class MapPickerDialog extends ConsumerStatefulWidget {
  final LatLng? initialPosition;

  const MapPickerDialog({super.key, this.initialPosition});

  @override
  ConsumerState<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends ConsumerState<MapPickerDialog> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(5.5255, 7.4916); // Default Umuahia Central Hub
  
  String _formattedAddress = 'Locating on map...';
  String _street = '';
  String _city = '';
  String _state = '';
  String _postalCode = '';

  bool _isLoading = false;
  bool _isMoving = false;
  Timer? _debounceTimer;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null &&
        widget.initialPosition!.latitude != 0.0 &&
        widget.initialPosition!.longitude != 0.0) {
      _currentPosition = widget.initialPosition!;
      _reverseGeocodeAndVerify(_currentPosition);
    } else {
      _determineCurrentLocation();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determineCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _reverseGeocodeAndVerify(_currentPosition);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _reverseGeocodeAndVerify(_currentPosition);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _reverseGeocodeAndVerify(_currentPosition);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final newPos = LatLng(position.latitude, position.longitude);
      _currentPosition = newPos;
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));
      }
      _reverseGeocodeAndVerify(newPos);
    } catch (_) {
      _reverseGeocodeAndVerify(_currentPosition);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentPosition = position.target;
    if (!_isMoving) {
      setState(() => _isMoving = true);
    }
    _debounceTimer?.cancel();
  }

  void _onCameraIdle() {
    setState(() => _isMoving = false);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _reverseGeocodeAndVerify(_currentPosition);
    });
  }

  Future<void> _reverseGeocodeAndVerify(LatLng loc) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Placemark> placemarks = await Geocoding().placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        final streetPart = place.street ?? place.thoroughfare ?? place.name ?? '';
        final lgaPart = place.subAdministrativeArea ?? place.subLocality ?? '';
        final localityPart = place.locality ?? '';
        final adminArea = place.administrativeArea ?? '';
        final pCode = place.postalCode ?? '';

        // Resolved city: prefer locality (e.g. Umuahia, Port Harcourt), fallback to subAdmin / LGA
        String cityResolved = localityPart.isNotEmpty ? localityPart : lgaPart;
        if (cityResolved.isEmpty) cityResolved = 'Umuahia';

        String stateResolved = adminArea.replaceAll('State', '').trim();
        if (stateResolved.isEmpty) stateResolved = 'Abia';

        // Compose full clean address
        final parts = [streetPart, cityPartCombined(streetPart, lgaPart), stateResolved, 'Nigeria']
            .where((p) => p.isNotEmpty)
            .toSet()
            .toList();

        final fullAddr = parts.join(', ');

        if (mounted) {
          setState(() {
            _formattedAddress = fullAddr.isNotEmpty ? fullAddr : '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';
            _street = streetPart.isNotEmpty ? streetPart : fullAddr;
            _city = cityResolved;
            _state = stateResolved;
            _postalCode = pCode;
            _searchController.text = _formattedAddress;
            _isLoading = false;
          });
        }

        // Live backend zone verification
        await ref.read(checkoutProvider.notifier).verifyLocation(
          _formattedAddress,
          _state,
          loc.latitude,
          loc.longitude,
          city: _city,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _formattedAddress = '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}';
          _isLoading = false;
        });
      }
    }
  }

  String cityPartCombined(String street, String lga) {
    if (lga.isEmpty || street.contains(lga)) return '';
    return lga;
  }

  Future<void> _searchAndFlyToQuery() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      List<Location> locs = await Geocoding().locationFromAddress(q);
      if (locs.isNotEmpty) {
        final target = LatLng(locs.first.latitude, locs.first.longitude);
        _currentPosition = target;
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        await _reverseGeocodeAndVerify(target);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find location for "$q"')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmAndReturn() {
    Navigator.pop(context, {
      'address': _formattedAddress,
      'street': _street.isNotEmpty ? _street : _formattedAddress,
      'city': _city,
      'state': _state,
      'postalCode': _postalCode,
      'lat': _currentPosition.latitude,
      'lng': _currentPosition.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(checkoutProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 16),
            onMapCreated: (ctrl) => _mapController = ctrl,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),

          // 2. Stationary Center Pin with Floating Bounce Effect
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: AnimatedScale(
                scale: _isMoving ? 1.25 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isMoving ? 'Move map to doorstep' : 'Delivery Pin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.location_on,
                      size: 46,
                      color: AppColors.primary,
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isMoving ? 6 : 14,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: _isMoving ? 0.2 : 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Floating Modern Top Bar (Header & Search)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Bar Row
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pin Exact Delivery Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                'Drag map so pin sits directly at your doorstep/gate',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar Input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search landmark, street, or city...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_circle_right, color: AppColors.primary),
                          onPressed: _searchAndFlyToQuery,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _searchAndFlyToQuery(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating "My Location" Button
          Positioned(
            right: 16,
            bottom: 240,
            child: FloatingActionButton(
              heroTag: 'gps_recenter',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _determineCurrentLocation,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // 5. Bottom Location Info Card & Action
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Address Title & Subtitle
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.place, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _street.isNotEmpty ? _street : 'Pinned Location',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formattedAddress,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Live Fee & Zone pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4), // light green
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  checkoutState.deliveryOptionName ?? 'Direct Farm Route',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                                Text(
                                  'ETA: ${checkoutState.deliveryEta ?? '30-45 mins'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'DELIVERY FEE',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            Text(
                              '₦${checkoutState.deliveryFee.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Button
                  ElevatedButton.icon(
                    onPressed: _confirmAndReturn,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                    label: const Text(
                      'Confirm This Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
