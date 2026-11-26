import 'package:bems_farms/features/support/presentation/pages/support_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/orders/data/models/order_model.dart';
import 'package:bems_farms/features/orders/presentation/providers/order_providers.dart';
import 'package:bems_farms/core/services/notification_service.dart';
import 'package:bems_farms/core/services/customer_order_monitor.dart';
import 'package:bems_farms/features/notifications/presentation/widgets/customer_notifications_sheet.dart';
import 'track_delivery_page.dart';

class OrderDetailPage extends ConsumerWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  String _formatMoney(num amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '₦${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isInTransit = order.isInTransit;
    final isDelivered = order.isDelivered;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        title: const Text(
          'Order Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(customerNotificationStoreProvider).unreadCount;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
                    onPressed: () => CustomerNotificationsSheet.show(context),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportChatPage(initialOrderId: order.id),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF1B3B2B),
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Driver Arrival & Confirm Goods Receipt Alert
            if (order.isDriverArrived) ...[
              _buildArrivalCard(context, ref, order),
              const SizedBox(height: 16),
            ],

            // 1. Consignment Tracking Card
            _buildConsignmentTrackingCard(context, order, isInTransit, isDelivered),
            const SizedBox(height: 16),

            // 2. Items Ordered Card
            _buildItemsOrderedCard(order),
            const SizedBox(height: 16),

            // 3. Assigned Courier Card (Strictly only when In Transit)
            if (isInTransit) ...[
              _buildAssignedCourierCard(context, order),
              const SizedBox(height: 16),
            ],

            // 4. Shipping & Logistics Section with Live Map Preview
            _buildShippingLogisticsCard(context, order, isInTransit),
            const SizedBox(height: 16),

            // 5. Payment Summary Card
            _buildPaymentSummaryCard(order),
            const SizedBox(height: 24),

            // 6. Action Buttons
            // Primary: Live Map & Courier Tracking
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3020),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackDeliveryPage(initialOrderId: order.id, initialOrder: order),
                  ),
                );
              },
              icon: const Icon(Icons.explore_outlined, color: Colors.white),
              label: const Text(
                'Live Map & Courier Tracking',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary: Electronic Receipt
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _showElectronicReceipt(context, order),
              icon: const Icon(Icons.receipt_long_outlined, size: 20, color: Colors.black87),
              label: const Text(
                'Electronic Receipt',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalCard(BuildContext context, WidgetRef ref, Order order) {
    final isConfirmed = order.isCustomerConfirmed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isConfirmed ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConfirmed ? const Color(0xFF81C784) : const Color(0xFFFFB300),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isConfirmed ? Colors.green : Colors.amber).withValues(alpha: 0.12),
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
                      isConfirmed ? 'Goods Receipt Confirmed' : 'Courier Has Arrived At Your Gate!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isConfirmed ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConfirmed
                          ? 'You confirmed receipt of your goods. Final handover complete.'
                          : 'Your courier is outside with your package. Inspect and confirm receipt.',
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
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(ordersProvider.notifier).confirmDelivery(order.id);
                    CustomerNotificationService.showReceiptConfirmedNotification(orderId: order.shortId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF1B5E20),
                          content: Text('✓ Delivery receipt confirmed! Thank you for choosing BemsFarms.'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text('Could not confirm receipt: $e'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                label: const Text(
                  '✓ Confirm I Have Received My Goods',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
                      'Receipt confirmed on-file. Thank you for choosing BemsFarms!',
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

  // --- 1. CONSIGNMENT TRACKING CARD ---
  Widget _buildConsignmentTrackingCard(BuildContext context, Order order, bool isInTransit, bool isDelivered) {
    int activeStep = 0;
    if (isDelivered) {
      activeStep = 2;
    } else if (isInTransit) {
      activeStep = 1;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONSIGNMENT TRACKING',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9E7D3B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            order.estimatedDeliveryTime,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            'Scheduled Dispatch • Order ${order.shortId}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Stepper Track
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepIcon(Icons.inventory_2_outlined, 'Packaging', activeStep >= 0, isCurrent: activeStep == 0),
              Expanded(child: Container(height: 2, color: activeStep >= 1 ? const Color(0xFF1B3B2B) : Colors.grey.shade300)),
              _buildStepIcon(Icons.local_shipping_outlined, 'In Transit', activeStep >= 1, isCurrent: activeStep == 1),
              Expanded(child: Container(height: 2, color: activeStep >= 2 ? const Color(0xFF1B3B2B) : Colors.grey.shade300)),
              _buildStepIcon(Icons.location_on_outlined, 'Delivered', activeStep >= 2, isCurrent: activeStep == 2),
            ],
          ),
          const SizedBox(height: 20),

          // Note Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  activeStep == 2
                      ? Icons.check_circle_outline
                      : (activeStep == 1 ? Icons.local_shipping : Icons.lock_outline),
                  size: 18,
                  color: const Color(0xFF1B3B2B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    activeStep == 2
                        ? 'Package safely delivered to your doorstep. Verification complete.'
                        : (activeStep == 1
                            ? (order.isDriverArrived
                                ? 'Courier has arrived at your gate / doorstep!'
                                : 'Courier is in-transit and approaching your delivery address.')
                            : 'Packed in insulated isothermal case. Verification complete.'),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIcon(IconData icon, String label, bool isReached, {bool isCurrent = false}) {
    final bgColor = isReached ? const Color(0xFF1B3B2B) : Colors.grey.shade100;
    final iconColor = isReached ? Colors.white : Colors.grey.shade400;

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: Colors.green, width: 2) : null,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isReached ? FontWeight.bold : FontWeight.w500,
            color: isReached ? Colors.black87 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // --- 2. ITEMS ORDERED CARD ---
  Widget _buildItemsOrderedCard(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Items Ordered',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${order.items.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...order.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: Colors.green.shade50,
                              child: const Icon(Icons.shopping_bag, color: Colors.green),
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: Colors.green.shade50,
                            child: const Icon(Icons.shopping_bag, color: Colors.green),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.unit} • ${_formatMoney(item.price)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Qty: ${item.quantity}x',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                              ),
                            ),
                            Text(
                              'Subtotal: ${_formatMoney(item.subtotal)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1B3B2B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- 3. ASSIGNED COURIER CARD (Strictly shown when In Transit) ---
  Widget _buildAssignedCourierCard(BuildContext context, Order order) {
    final driverName = (order.driverName != null && order.driverName!.isNotEmpty)
        ? order.driverName!
        : (order.isDriverAssigned ? 'Assigned Courier' : 'Dispatching Courier...');
    final driverVehicle = (order.driverVehicle != null && order.driverVehicle!.isNotEmpty)
        ? order.driverVehicle!
        : 'Courier Fleet';
    final driverPhone = order.driverPhone;
    final driverAvatar = order.driverAvatar;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ASSIGNED COURIER',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'On Shift',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: (driverAvatar != null && driverAvatar.isNotEmpty)
                    ? Image.network(
                        driverAvatar,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildCourierAvatarFallback(),
                      )
                    : _buildCourierAvatarFallback(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      driverVehicle,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () async {
                  if (driverPhone != null && driverPhone.isNotEmpty) {
                    final uri = Uri.parse('tel:$driverPhone');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Calling courier at $driverPhone')),
                      );
                    }
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Courier phone number is not available yet')),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.phone, color: Color(0xFF1B3B2B), size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourierAvatarFallback() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delivery_dining, size: 30, color: Color(0xFF1B3B2B)),
    );
  }

  // --- 4. SHIPPING & LOGISTICS SECTION ---
  Widget _buildShippingLogisticsCard(BuildContext context, Order order, bool isInTransit) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Shipping & Logistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Express Sector',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Map Preview
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackDeliveryPage(initialOrderId: order.id, initialOrder: order),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  children: [
                    if (isInTransit)
                      const GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(4.8156, 7.0498), // Port Harcourt hub coordinates
                          zoom: 12.5,
                        ),
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        myLocationButtonEnabled: false,
                      )
                    else
                      Container(
                        color: Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, size: 36, color: Colors.grey.shade400),
                            const SizedBox(height: 6),
                            Text(
                              'Live radar activates upon dispatch',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.navigation, color: Colors.greenAccent, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Hub Delta -> Delivery Corridor',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Live Radar',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Delivery Destination Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on, color: Color(0xFF1B3B2B), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery Destination',
                      style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.deliveryAddress,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 5. PAYMENT SUMMARY CARD ---
  Widget _buildPaymentSummaryCard(Order order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Settled',
                  style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal Provisions', _formatMoney(order.subtotal)),
          const SizedBox(height: 8),
          _buildSummaryRow('Freight & Delivery', _formatMoney(order.deliveryFee)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                _formatMoney(order.total),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B3B2B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment, size: 16, color: Color(0xFF1B3B2B)),
                    const SizedBox(width: 8),
                    Text(
                      order.paymentMethod == 'cod' ? 'Cash on Delivery' : 'Online Payment Authorized',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const Text(
                  'Secured',
                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  // --- 6. ELECTRONIC RECEIPT MODAL ---
  void _showElectronicReceipt(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text('Electronic Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              Text('Order Number: ${order.shortId}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Date: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const Divider(height: 24),
              ...order.items.map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${i.name} (x${i.quantity})', style: const TextStyle(fontSize: 13)),
                        Text(_formatMoney(i.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  )),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Fee', style: TextStyle(fontSize: 13)),
                  Text(_formatMoney(order.deliveryFee), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_formatMoney(order.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final cleanId = (order.orderNumber.isNotEmpty ? order.orderNumber : order.id)
                      .replaceAll('#', '')
                      .trim();
                  final webUrl = (order.receiptUrl != null && order.receiptUrl!.isNotEmpty)
                      ? order.receiptUrl!
                      : 'https://www.bemsfarms.com/orders/$cleanId';

                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(webUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.verified_outlined, size: 18, color: AppColors.primary),
                      label: const Text(
                        'Verify Receipt on Web',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
