import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/core/services/notification_service.dart';
import 'package:bems_farms/features/orders/data/models/order_model.dart';
import 'package:bems_farms/features/orders/data/repositories/api_order_repository.dart';

class TrackDeliveryPage extends StatefulWidget {
  final String? initialOrderId;
  final Order? initialOrder;

  const TrackDeliveryPage({
    super.key,
    this.initialOrderId,
    this.initialOrder,
  });

  @override
  State<TrackDeliveryPage> createState() => _TrackDeliveryPageState();
}

class _TrackDeliveryPageState extends State<TrackDeliveryPage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiOrderRepository _orderRepo = ApiOrderRepository();

  bool _isTracking = false;
  bool _isLoading = false;
  bool _isDriverArrived = false;
  bool _isConfirmingReceipt = false;
  bool _demoGoodsConfirmed = false;
  String? _referenceError;

  Order? _trackedOrder;
  socket_io.Socket? _socket;
  Timer? _trackingPoller;
  GoogleMapController? _mapController;

  double? _liveDriverLat;
  double? _liveDriverLng;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _trackedOrder = widget.initialOrder;
      _searchController.text = widget.initialOrder!.id;
      _isTracking = true;
      _setupTrackingForOrder(widget.initialOrder!);
      // Refresh in background to get latest live coordinates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLatestOrder(widget.initialOrder!.id);
      });
    } else if (widget.initialOrderId != null && widget.initialOrderId!.isNotEmpty) {
      _searchController.text = widget.initialOrderId!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trackOrder();
      });
    }
  }

  @override
  void dispose() {
    _trackingPoller?.cancel();
    _trackingPoller = null;
    _socket?.disconnect();
    _socket?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLatestOrder(String orderId) async {
    try {
      final updated = await _orderRepo.getOrderById(orderId);
      if (mounted) {
        setState(() {
          _trackedOrder = updated;
          _setupTrackingForOrder(updated);
        });
      }
    } catch (_) {
      // Keep existing data gracefully
    }
  }

  Future<void> _trackOrder() async {
    FocusScope.of(context).unfocus();
    final rawRef = _searchController.text.trim();
    final cleanRef = rawRef.replaceAll('#', '').trim();
    if (cleanRef.isEmpty) {
      setState(() {
        _referenceError = 'Enter a valid BemsFarms delivery code';
        _isTracking = false;
        _trackedOrder = null;
      });
      return;
    }

    // Handle Demo preview
    if (cleanRef.toUpperCase() == 'BF-DEMO-2026') {
      _socket?.disconnect();
      setState(() {
        _referenceError = null;
        _isTracking = true;
        _trackedOrder = null; // Triggers demo mode
        _setupDemoMarkers();
      });
      return;
    }

    // If matches initialOrder passed in
    if (widget.initialOrder != null) {
      final o = widget.initialOrder!;
      final oId = o.id.replaceAll('#', '').toLowerCase();
      final oNum = o.orderNumber.replaceAll('#', '').toLowerCase();
      final target = cleanRef.toLowerCase();
      if (oId == target || oNum == target || o.shortId.toLowerCase() == rawRef.toLowerCase()) {
        setState(() {
          _referenceError = null;
          _isTracking = true;
          _trackedOrder = widget.initialOrder;
        });
        _setupTrackingForOrder(widget.initialOrder!);
        _fetchLatestOrder(widget.initialOrder!.id);
        return;
      }
    }

    // Real API fetch
    setState(() {
      _isLoading = true;
      _referenceError = null;
    });

    try {
      Order? order;

      // 1. Search in user's order history first (instant & reliable)
      try {
        final myOrders = await _orderRepo.getMyOrders();
        for (final o in myOrders) {
          final oId = o.id.replaceAll('#', '').toLowerCase();
          final oNum = o.orderNumber.replaceAll('#', '').toLowerCase();
          final oRef = (o.rawJson?['order_ref'] ?? o.rawJson?['reference'] ?? '').toString().replaceAll('#', '').toLowerCase();
          final target = cleanRef.toLowerCase();
          if (oId == target || oNum == target || oRef == target || o.shortId.toLowerCase() == rawRef.toLowerCase()) {
            order = o;
            break;
          }
        }
      } catch (_) {}

      // 2. Query direct order by ID
      if (order == null) {
        try {
          order = await _orderRepo.getOrderById(cleanRef);
        } catch (_) {}
      }

      // 3. Fallback to public track endpoint
      if (order == null) {
        try {
          final trackRes = await _orderRepo.trackOrder(cleanRef);
          final orderMap = trackRes['order'] ?? trackRes;
          if (orderMap is Map<String, dynamic>) {
            order = Order.fromJson(orderMap);
          }
        } catch (_) {}
      }

      // 4. Try with rawRef if different
      if (order == null && rawRef != cleanRef) {
        try {
          order = await _orderRepo.getOrderById(rawRef);
        } catch (_) {}
      }

      if (order != null && mounted) {
        setState(() {
          _trackedOrder = order;
          _isTracking = true;
          _isLoading = false;
        });
        _setupTrackingForOrder(order);
        _fetchLatestOrder(order.id);
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _referenceError = 'Order "$rawRef" not found. Please verify your reference.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _referenceError = 'Could not find order "$rawRef". Please check your reference.';
        });
      }
    }
  }

  void _setupTrackingForOrder(Order order) {
    // Determine coordinates (Hub, Driver, Destination)
    final hubPos = LatLng(order.hubLat ?? 5.5245, order.hubLng ?? 7.4912);
    final destPos = LatLng(order.deliveryLat ?? 5.5123, order.deliveryLng ?? 7.4850);
    final driverPos = LatLng(
      _liveDriverLat ?? order.driverLat ?? 5.5180,
      _liveDriverLng ?? order.driverLng ?? 7.4890,
    );

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('hub'),
        position: hubPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'BemsFarms Central Hub', snippet: 'Abia State Central Logistics'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Delivery Address',
          snippet: order.deliveryAddress.isNotEmpty ? order.deliveryAddress : 'Customer Destination',
        ),
      ),
    };

    if (order.status == OrderStatus.shipped || order.status == OrderStatus.tracking) {
      markers.add(
        Marker(
          markerId: const MarkerId('courier'),
          position: driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: order.driverName ?? 'Active Courier',
            snippet: order.driverVehicle ?? 'Logistics Fleet',
          ),
        ),
      );
    }

    final polylinePoints = [hubPos, driverPos, destPos];
    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('delivery_route'),
        points: polylinePoints,
        color: const Color(0xFF2E7D32),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };

    setState(() {
      _markers = markers;
      _polylines = polylines;
      if (order.isDriverArrived) {
        _isDriverArrived = true;
      }
    });

    _animateCameraToFit(driverPos, destPos);
    _connectSocket(order.id);
  }

  void _setupDemoMarkers() {
    const demoDriver = LatLng(5.5320, 7.4859);
    const demoDest = LatLng(5.5240, 7.4920);

    setState(() {
      _markers = {
        const Marker(
          markerId: MarkerId('dispatch'),
          position: demoDriver,
          infoWindow: InfoWindow(title: 'Chukwudi Nnamdi (Demo Courier)'),
        ),
        const Marker(
          markerId: MarkerId('destination'),
          position: demoDest,
          infoWindow: InfoWindow(title: 'Umuahia Central (Demo Destination)'),
        ),
      };
      _polylines = {
        const Polyline(
          polylineId: PolylineId('demo_route'),
          points: [demoDriver, demoDest],
          color: Color(0xFF2E7D32),
          width: 4,
        ),
      };
    });
  }

  void _connectSocket(String orderId) {
    _trackingPoller?.cancel();
    _trackingPoller = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _trackedOrder != null) {
        _fetchLatestOrder(_trackedOrder!.id);
      }
    });

    _socket?.disconnect();
    _socket?.dispose();

    try {
      _socket = socket_io.io(
        'https://api.bemsfarms.com',
        socket_io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .build(),
      );

      _socket?.onConnect((_) {
        debugPrint('Connected to live tracking socket for order: $orderId');
      });

      _socket?.on('driver_location_$orderId', (data) {
        if (mounted && data != null && data is Map) {
          final lat = double.tryParse(data['latitude']?.toString() ?? '');
          final lng = double.tryParse(data['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            setState(() {
              _liveDriverLat = lat;
              _liveDriverLng = lng;
              if (_trackedOrder != null) {
                _setupTrackingForOrder(_trackedOrder!);
              }
            });
          }
        }
      });

      // Listen for driver arrival
      _socket?.on('driver_arrived_$orderId', (_) => _handleDriverArrived());
      _socket?.on('driver_arrived', (_) => _handleDriverArrived());
      _socket?.on('order_status_$orderId', (data) {
        if (data is Map && (data['status'] == 'arrived' || data['delivery_status'] == 'arrived')) {
          _handleDriverArrived();
        }
      });
    } catch (e) {
      debugPrint('Live socket connection error: $e');
    }
  }

  void _handleDriverArrived() {
    if (!mounted) return;
    setState(() {
      _isDriverArrived = true;
    });
    CustomerNotificationService.showDriverArrivedNotification(
      orderId: _trackedOrder?.shortId ?? widget.initialOrderId ?? 'Order',
      driverName: _trackedOrder?.driverName ?? 'Your Courier',
    );
  }

  Future<void> _confirmGoodsReceipt(Order order) async {
    setState(() => _isConfirmingReceipt = true);
    try {
      await _orderRepo.confirmDelivery(order.id);
      await CustomerNotificationService.showReceiptConfirmedNotification(
        orderId: order.shortId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1B5E20),
            content: Text('✓ Delivery receipt confirmed! Thank you for choosing BemsFarms.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      await _fetchLatestOrder(order.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Could not confirm receipt: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirmingReceipt = false);
      }
    }
  }

  Future<void> _confirmDemoReceipt() async {
    setState(() => _isConfirmingReceipt = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _isConfirmingReceipt = false;
        _demoGoodsConfirmed = true;
      });
      CustomerNotificationService.showReceiptConfirmedNotification(orderId: 'BF-DEMO-2026');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1B5E20),
          content: Text('✓ Delivery receipt confirmed! Thank you for choosing BemsFarms.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildArrivalAndConfirmationCard({Order? order, bool isDemo = false}) {
    final isConfirmed = isDemo ? _demoGoodsConfirmed : (order?.isCustomerConfirmed ?? false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isConfirmed ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfirmed ? const Color(0xFF81C784) : const Color(0xFFFFB300),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConfirmed ? Colors.green : Colors.amber).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConfirmed ? const Color(0xFF2E7D32) : const Color(0xFFFF8F00),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConfirmed ? Icons.check_circle : Icons.sports_motorsports,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConfirmed ? 'Goods Receipt Confirmed' : 'Courier Has Arrived At Your Doorstep!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isConfirmed ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConfirmed
                          ? 'You confirmed receipt of your package. Final handover complete.'
                          : 'Your dispatch rider is at your gate/location with your fresh produce.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isConfirmed ? const Color(0xFF2E7D32) : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isConfirmed) ...[
            const Text(
              'Please check and inspect your items. When satisfied, tap below to confirm receipt of your goods:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isConfirmingReceipt
                    ? null
                    : () {
                        if (isDemo || order == null) {
                          _confirmDemoReceipt();
                        } else {
                          _confirmGoodsReceipt(order);
                        }
                      },
                icon: _isConfirmingReceipt
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                label: Text(
                  _isConfirmingReceipt ? 'Confirming Receipt...' : '✓ Confirm I Have Received My Goods',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF2E7D32), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receipt confirmed on-file. Thank you for shopping with BemsFarms!',
                      style: TextStyle(color: Color(0xFF1B5E20), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openFullScreenMap(bool isReal, Order? order) {
    final driverPos = LatLng(
      _liveDriverLat ?? order?.driverLat ?? 5.5180,
      _liveDriverLng ?? order?.driverLng ?? 7.4890,
    );
    final destPos = LatLng(
      order?.deliveryLat ?? 5.5123,
      order?.deliveryLng ?? 7.4850,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenTrackingMapPage(
          markers: _markers,
          polylines: _polylines,
          initialTarget: _markers.isNotEmpty ? _markers.first.position : driverPos,
          orderCode: isReal && order != null ? order.shortId : 'DEMO-PREVIEW',
          statusText: isReal && order != null ? _getStatusTitle(order.status) : 'Out for Delivery',
          driverPosition: driverPos,
          destPosition: destPos,
        ),
      ),
    );
  }

  void _animateCameraToFit(LatLng p1, LatLng p2) {
    if (_mapController == null) return;
    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          p1.latitude < p2.latitude ? p1.latitude : p2.latitude,
          p1.longitude < p2.longitude ? p1.longitude : p2.longitude,
        ),
        northeast: LatLng(
          p1.latitude > p2.latitude ? p1.latitude : p2.latitude,
          p1.longitude > p2.longitude ? p1.longitude : p2.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } catch (_) {}
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Courier contact number will be provided once dispatched.')),
      );
      return;
    }
    final cleanPhone = phone.trim();
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone dialer for $cleanPhone')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dial $cleanPhone')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String? phone, String orderRef) async {
    final cleanPhone = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '2348000000000';
    final text = Uri.encodeComponent('Hello BemsFarms, I am inquiring about my delivery for Order: $orderRef');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Track Your Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header / Hero Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIVE DISPATCH LOGISTICS',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Track Your Delivery',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Direct dispatch from our Abia State central hub to all 36 States + FCT. Enter your reference to track live progress.',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  
                  // Search Box
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'ORDER REFERENCE (E.G. BF-ABC12345)',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _trackOrder,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                              )
                            : const Text('Track', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (_referenceError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_referenceError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Sample preview: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      GestureDetector(
                        onTap: () {
                          _searchController.text = 'BF-DEMO-2026';
                          _trackOrder();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BF-DEMO-2026',
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tracking Result or Informational Content
            if (_isTracking)
              _buildLiveTrackingCard()
            else
              _buildInformationalSections(),
              
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTrackingCard() {
    final isReal = _trackedOrder != null;
    final order = _trackedOrder;

    final statusText = isReal ? _getStatusTitle(order!.status) : 'Out for Delivery';
    final subtitleText = isReal
        ? _getStatusSubtitle(order!)
        : 'Your courier is nearby and approaching your delivery address.';
    final etaText = isReal ? order!.estimatedDeliveryTime : '~20 mins';
    final bool isInTransitOrBeyond = isReal
        ? (order!.status == OrderStatus.shipped ||
            order.status == OrderStatus.delivered ||
            order.status == OrderStatus.tracking)
        : true;
    final courierName = isReal
        ? (isInTransitOrBeyond
            ? (order!.driverName ?? 'Assigned Courier')
            : 'Will be assigned upon dispatch')
        : 'Chukwudi Nnamdi';
    final courierPhone = isReal ? order!.driverPhone : null;
    final destination = isReal
        ? (order!.deliveryAddress.isNotEmpty ? order.deliveryAddress : 'Delivery Address Provided')
        : 'Umuahia Central, Abia State';
    final itemsSummary = isReal
        ? (order!.items.isNotEmpty
            ? order.items.map((i) => '${i.name} (${i.quantity} ${i.unit})').join(', ')
            : 'Farm Produce Package')
        : 'Stone-Free Rice (25kg), Pure Palm Oil (5L), Brown Beans (10kg)';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Status Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              isReal ? 'ORDER ${order!.shortId.toUpperCase()}' : 'SAMPLE LIVE PREVIEW',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(4)),
                            child: Text('ETA: $etaText', style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          _socket?.disconnect();
                          setState(() {
                            _isTracking = false;
                            _trackedOrder = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                          child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitleText, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            
            // Stepper
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildStepper(isReal ? order!.status : OrderStatus.shipped),
            ),
            
            // Driver Arrival & Confirm Goods Receipt Banner
            if ((isReal && (order!.isDriverArrived || _isDriverArrived)) || (!isReal && _isDriverArrived)) ...[
              _buildArrivalAndConfirmationCard(order: order, isDemo: !isReal),
            ],

            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
            
            // Map and Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dispatch Info
                  const Text('DISPATCH PERSONNEL', style: TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(courierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      if (isReal && order!.driverVehicle != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(order.driverVehicle!, style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text.rich(TextSpan(
                    children: [
                      const TextSpan(text: 'Destination: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      TextSpan(text: destination, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  )),
                  const SizedBox(height: 4),
                  Text.rich(TextSpan(
                    children: [
                      const TextSpan(text: 'Items: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      TextSpan(text: itemsSummary, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  )),
                  const SizedBox(height: 16),
                  
                  // Action Buttons / Status Call
                  if (isInTransitOrBeyond) ...[
                    // Call Button (WhatsApp commented out for now in this version)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _makeCall(courierPhone),
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text(
                          courierPhone != null && courierPhone.isNotEmpty
                              ? 'Call Driver'
                              : 'Call Dispatcher',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    /*
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(courierPhone, isReal ? order!.id : 'BF-DEMO-2026'),
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text('WhatsApp', style: TextStyle(color: Colors.black87)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    */
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Order is currently packaging. Driver calling will be enabled once your order is In Transit.',
                              style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Live Map Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _markers.isNotEmpty
                                  ? _markers.first.position
                                  : const LatLng(5.5320, 7.4859),
                              zoom: 13.5,
                            ),
                            zoomControlsEnabled: false,
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                            markers: _markers,
                            polylines: _polylines,
                            onMapCreated: (controller) {
                              _mapController = controller;
                            },
                          ),

                          // Top-right Expand to Fullscreen / Landscape button
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              elevation: 4,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => _openFullScreenMap(isReal, order),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fullscreen, color: AppColors.primary, size: 20),
                                      SizedBox(width: 4),
                                      Text(
                                        'Full Map',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom Live indicator
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00E676),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isReal ? 'Live GPS Dispatch' : 'Live Map Preview',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  String _getStatusTitle(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing:
        return 'Order Packaging';
      case OrderStatus.shipped:
      case OrderStatus.tracking:
        return 'Out for Delivery';
      case OrderStatus.delivered:
        return 'Order Delivered';
      case OrderStatus.cancelled:
        return 'Order Cancelled';
    }
  }

  String _getStatusSubtitle(Order order) {
    switch (order.status) {
      case OrderStatus.processing:
        return 'Your farm produce is currently being cleaned, quality-checked, and packaged.';
      case OrderStatus.shipped:
      case OrderStatus.tracking:
        final courier = order.driverName != null ? ' with courier ${order.driverName}' : '';
        return 'Your package is on route$courier towards your delivery destination.';
      case OrderStatus.delivered:
        return 'Your package was safely delivered to your destination address.';
      case OrderStatus.cancelled:
        return 'This order was cancelled.';
    }
  }

  Widget _buildStepper(OrderStatus currentStatus) {
    final isProcessing = currentStatus == OrderStatus.processing;
    final isInTransit = currentStatus == OrderStatus.shipped || currentStatus == OrderStatus.tracking;
    final isDelivered = currentStatus == OrderStatus.delivered;

    return Row(
      children: [
        _buildStep(
          icon: Icons.inventory_2,
          label: 'Packaging',
          isActive: isProcessing,
          isCompleted: isInTransit || isDelivered,
        ),
        _buildLine(isCompleted: isInTransit || isDelivered),
        _buildStep(
          icon: Icons.local_shipping,
          label: 'In Transit',
          isActive: isInTransit,
          isCompleted: isDelivered,
        ),
        _buildLine(isCompleted: isDelivered),
        _buildStep(
          icon: Icons.home,
          label: 'Delivered',
          isActive: isDelivered,
          isCompleted: isDelivered,
        ),
      ],
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color bg;
    Color fg;
    if (isCompleted) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else if (isActive) {
      bg = Colors.amber;
      fg = Colors.black87;
    } else {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade500;
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(isCompleted ? Icons.check : icon, size: 18, color: fg),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
              color: isActive || isCompleted ? Colors.black87 : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLine({required bool isCompleted}) {
    return Expanded(
      child: Container(
        height: 2,
        color: isCompleted ? AppColors.primary : Colors.grey.shade300,
        margin: const EdgeInsets.only(bottom: 20),
      ),
    );
  }

  Widget _buildInformationalSections() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
            child: const Text('SIMPLE & RELIABLE', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          const Text('How Our Delivery Process Works', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          
          _buildInfoCard('01', 'Order Placement', 'Select your farm produce and staples. Enter your delivery address during secure checkout.'),
          const SizedBox(height: 12),
          _buildInfoCard('02', 'Sorting & Sealed Packaging', 'Grains are de-stoned, quality-inspected, and oils are packed into tamper-proof containers at our Abia State hub.'),
          const SizedBox(height: 12),
          _buildInfoCard('03', 'Doorstep Dispatch Everywhere', 'Our direct couriers and inter-state logistics partners deliver safely to your doorstep across Nigeria.'),
          
          const SizedBox(height: 40),
          const Text('Delivery Coverage & Dispatch Hubs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Centrally coordinated from Abia State with nationwide coverage across all states in Nigeria.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          
          _buildCoverageCard('Abia State (HQ & Central Hub)', 'Same-Day / Next-Day', 'Umuahia, Aba, Ohafia, Arochukwu, Osisioma, Isiala Ngwa & all surrounding towns'),
          const SizedBox(height: 12),
          _buildCoverageCard('Regional & South-East / South-South', '1 - 2 Business Days', 'Port Harcourt, Owerri, Enugu, Uyo, Calabar, Asaba, Onitsha, Warri, Benin City'),
          
          const SizedBox(height: 40),
          const Text('Frequently Asked Delivery Questions', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          
          _buildFaq('How does nationwide delivery work from Abia State?', 'We partner with reliable interstate logistics companies to ensure your produce reaches you safely, no matter where you are in Nigeria.'),
          _buildFaq('How is delivery fee calculated?', 'Delivery fees are calculated based on the weight of your items and the distance from our central hub in Abia State.'),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String number, String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Text(number, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCoverageCard(String title, String eta, String areas) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(eta, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(areas, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFaq(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(answer, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Fullscreen Interactive Map Page supporting both Portrait & Landscape orientation
class FullScreenTrackingMapPage extends StatefulWidget {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng initialTarget;
  final String orderCode;
  final String statusText;
  final LatLng? driverPosition;
  final LatLng? destPosition;

  const FullScreenTrackingMapPage({
    super.key,
    required this.markers,
    required this.polylines,
    required this.initialTarget,
    required this.orderCode,
    required this.statusText,
    this.driverPosition,
    this.destPosition,
  });

  @override
  State<FullScreenTrackingMapPage> createState() => _FullScreenTrackingMapPageState();
}

class _FullScreenTrackingMapPageState extends State<FullScreenTrackingMapPage> {
  GoogleMapController? _mapController;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    // Allow full sensor-based orientation (Portrait & Landscape)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Restore portrait lock upon exiting
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
    });
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _centerOnDriver() {
    if (widget.driverPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: widget.driverPosition!, zoom: 16),
        ),
      );
    }
  }

  void _centerOnDestination() {
    if (widget.destPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: widget.destPosition!, zoom: 16),
        ),
      );
    }
  }

  void _fitAllMarkers() {
    if (_mapController == null || widget.driverPosition == null || widget.destPosition == null) return;
    try {
      final p1 = widget.driverPosition!;
      final p2 = widget.destPosition!;
      final bounds = LatLngBounds(
        southwest: LatLng(
          p1.latitude < p2.latitude ? p1.latitude : p2.latitude,
          p1.longitude < p2.longitude ? p1.longitude : p2.longitude,
        ),
        northeast: LatLng(
          p1.latitude > p2.latitude ? p1.latitude : p2.latitude,
          p1.longitude > p2.longitude ? p1.longitude : p2.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isDeviceLandscape = orientation == Orientation.landscape;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full Screen Interactive Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialTarget,
              zoom: 14.5,
            ),
            markers: widget.markers,
            polylines: widget.polylines,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            onMapCreated: (ctrl) {
              _mapController = ctrl;
              Future.delayed(const Duration(milliseconds: 300), _fitAllMarkers);
            },
          ),

          // 2. Top Control & Navigation Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Back Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
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
                  const SizedBox(width: 10),

                  // Order & Status Header Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #${widget.orderCode.toUpperCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  widget.statusText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                                SizedBox(width: 4),
                                Text(
                                  'LIVE GPS',
                                  style: TextStyle(
                                    color: Color(0xFF1B5E20),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Rotate / Landscape Toggle Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: isDeviceLandscape ? 'Switch to Portrait' : 'Rotate to Landscape',
                      icon: Icon(
                        isDeviceLandscape ? Icons.screen_lock_portrait : Icons.screen_rotation,
                        color: AppColors.primary,
                      ),
                      onPressed: _toggleOrientation,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Floating Action Controls (Right Side)
          Positioned(
            right: 14,
            bottom: isDeviceLandscape ? 20 : 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recenter Driver Button
                FloatingActionButton.small(
                  heroTag: 'fs_driver_center',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _centerOnDriver,
                  tooltip: 'Focus Driver',
                  child: const Icon(Icons.sports_motorsports),
                ),
                const SizedBox(height: 8),

                // Recenter Destination Button
                FloatingActionButton.small(
                  heroTag: 'fs_dest_center',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  onPressed: _centerOnDestination,
                  tooltip: 'Focus Destination',
                  child: const Icon(Icons.place),
                ),
                const SizedBox(height: 8),

                // Fit Full Route Button
                FloatingActionButton.small(
                  heroTag: 'fs_fit_route',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: _fitAllMarkers,
                  tooltip: 'Fit Entire Route',
                  child: const Icon(Icons.fit_screen),
                ),
                const SizedBox(height: 12),

                // Zoom In Button
                FloatingActionButton.small(
                  heroTag: 'fs_zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: _zoomIn,
                  tooltip: 'Zoom In',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),

                // Zoom Out Button
                FloatingActionButton.small(
                  heroTag: 'fs_zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: _zoomOut,
                  tooltip: 'Zoom Out',
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
