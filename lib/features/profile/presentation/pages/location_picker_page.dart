import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/core/network/api_constants.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng _currentCenter = const LatLng(9.0820, 8.6753); // Default Nigeria

  bool _isLoading = false;
  String _currentAddress = "Loading address...";
  String _currentState = "";
  String _currentCity = "";
  String _currentPostalCode = "";

  // Verification details
  bool _isVerifying = false;
  double? _deliveryFee;
  String? _zoneName;
  String? _eta;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _updateAddress(latLng);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAddress(LatLng latLng) async {
    setState(() => _currentAddress = "Fetching address...");
    try {
      List<Placemark> placemarks = await Geocoding()
          .placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        // Build clean address parts, filtering out null or "null" strings
        final parts = <String>[];
        void addPart(String? val) {
          if (val != null && val.trim().isNotEmpty && val.trim().toLowerCase() != 'null') {
            final cleaned = val.trim();
            if (!parts.contains(cleaned)) {
              parts.add(cleaned);
            }
          }
        }

        addPart(place.name);
        addPart(place.street);
        addPart(place.subLocality);
        addPart(place.locality);

        final stateStr = place.administrativeArea != null && place.administrativeArea!.toLowerCase() != 'null'
            ? place.administrativeArea!.trim()
            : '';
            
        final cityStr = (place.locality != null && place.locality!.trim().isNotEmpty && place.locality!.toLowerCase() != 'null')
            ? place.locality!.trim()
            : (place.subAdministrativeArea != null && place.subAdministrativeArea!.toLowerCase() != 'null'
                ? place.subAdministrativeArea!.trim()
                : '');

        final postalCodeStr = place.postalCode != null && place.postalCode!.trim().isNotEmpty && place.postalCode!.toLowerCase() != 'null'
            ? place.postalCode!.trim()
            : '';

        final addressStr = parts.isNotEmpty ? parts.join(', ') : 'Selected Location';

        setState(() {
          _currentAddress = addressStr;
          _currentState = stateStr;
          _currentCity = cityStr;
          _currentPostalCode = postalCodeStr;
        });

        _verifyLocationWithBackend(
            latLng.latitude, latLng.longitude, _currentAddress, _currentState);
      }
    } catch (e) {
      setState(() => _currentAddress = "Unknown Location");
    }
  }

  Future<void> _verifyLocationWithBackend(
      double lat, double lng, String addressStr, String stateStr) async {
    setState(() => _isVerifying = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/locations/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'address': addressStr,
          'state': stateStr,
          'latitude': lat,
          'longitude': lng,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        
        var zoneData = data;
        if (data['zone'] is Map) {
          zoneData = data['zone'];
        }

        setState(() {
          _deliveryFee = double.tryParse(zoneData['delivery_fee']?.toString() ??
              zoneData['fee']?.toString() ??
              data['delivery_fee']?.toString() ??
              '1000');
          _zoneName = zoneData['zone_name']?.toString() ?? 
              zoneData['delivery_option_name']?.toString() ?? 
              data['delivery_option_name']?.toString();
          _eta = zoneData['estimated_delivery_time']?.toString() ??
              zoneData['delivery_eta']?.toString() ?? 
              zoneData['eta']?.toString() ?? 
              data['delivery_eta']?.toString();
        });
      }
    } catch (e) {
      // handle error silently
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  String _fmtPrice(double v) {
    final s = v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '₦$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Delivery Location',
            style: TextStyle(fontSize: 16)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _currentCenter, zoom: 14),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) => _currentCenter = position.target,
            onCameraIdle: () => _updateAddress(_currentCenter),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child:
                  Icon(Icons.location_on, size: 50, color: AppColors.primary),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _determinePosition,
              backgroundColor: Colors.white,
              icon: const Icon(Icons.my_location, color: AppColors.primary),
              label: const Text('Use My Location',
                  style: TextStyle(color: AppColors.textPrimary)),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_currentAddress,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_zoneName ?? 'Calculating zone...',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.primary)),
                              const SizedBox(height: 4),
                              Text('Estimated Time: ${_eta ?? '...'}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade800)),
                            ],
                          ),
                        ),
                        if (_isVerifying)
                          const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else if (_deliveryFee != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('DELIVERY FEE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary)),
                              Text(_fmtPrice(_deliveryFee!),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.primary)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isVerifying || _deliveryFee == null)
                          ? null
                          : () {
                              Navigator.pop(context, {
                                'street': _currentAddress,
                                'state': _currentState,
                                'city': _currentCity,
                                'postalCode': _currentPostalCode,
                                'postal_code': _currentPostalCode,
                                'latitude': _currentCenter.latitude,
                                'longitude': _currentCenter.longitude,
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirm & Pin Location',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
