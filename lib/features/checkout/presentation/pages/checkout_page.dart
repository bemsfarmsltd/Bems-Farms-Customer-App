import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/cart/presentation/providers/cart_provider.dart';
import 'package:bems_farms/features/checkout/presentation/providers/checkout_provider.dart';
import 'package:bems_farms/features/profile/presentation/providers/address_provider.dart';
import 'package:bems_farms/features/checkout/presentation/widgets/map_picker_dialog.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/wallet/data/models/customer_wallet_model.dart';
import 'package:bems_farms/features/wallet/presentation/providers/customer_wallet_provider.dart';
import 'package:bems_farms/features/wallet/presentation/widgets/wallet_setup_dialog.dart';
import 'package:bems_farms/features/wallet/presentation/pages/customer_wallet_page.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerWalletProvider.notifier).fetchWallet(silent: true);
    });
  }

  @override
  void dispose() {
    _couponController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  final TextEditingController _couponController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  
  String _state = 'Rivers';
  bool _isNewAddressMapPinned = false;
  String _pinnedLocationDisplay = '';
  double? _pinnedLat;
  double? _pinnedLng;

  static const List<String> kNigerianStates = [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno',
    'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT - Abuja', 'Gombe',
    'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos',
    'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto',
    'Taraba', 'Yobe', 'Zamfara'
  ];

  String _normalizeState(String raw) {
    if (raw.isEmpty) return 'Rivers';
    final clean = raw.replaceAll(RegExp(r'\bstate\b', caseSensitive: false), '').trim();
    if (clean.toLowerCase().contains('abuja') ||
        clean.toLowerCase().contains('fct') ||
        clean.toLowerCase().contains('federal capital')) {
      return 'FCT - Abuja';
    }
    for (final s in kNigerianStates) {
      if (clean.toLowerCase() == s.toLowerCase()) {
        return s;
      }
    }
    for (final s in kNigerianStates) {
      if (s.toLowerCase().contains(clean.toLowerCase()) ||
          clean.toLowerCase().contains(s.toLowerCase())) {
        return s;
      }
    }
    return 'Rivers';
  }

  void _syncAddressToProvider() {
    _formKey.currentState?.save();
    ref.read(checkoutProvider.notifier).setNewAddressForm({
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'street': _streetController.text,
      'city': _cityController.text,
      'state': _state,
      'postal_code': _postalCodeController.text,
    }, lat: _pinnedLat, lng: _pinnedLng);
  }

  Future<void> _openMapPicker() async {
    final initialPos = (_pinnedLat != null && _pinnedLng != null)
        ? LatLng(_pinnedLat!, _pinnedLng!)
        : null;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerDialog(initialPosition: initialPos),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      final street = (result['street'] as String? ?? '').trim();
      final city = (result['city'] as String? ?? '').trim();
      final rawState = (result['state'] as String? ?? '').trim();
      final postal = (result['postalCode'] as String? ?? '').trim();
      final lat = result['lat'] as double?;
      final lng = result['lng'] as double?;

      final resolvedState = _normalizeState(rawState);

      setState(() {
        if (street.isNotEmpty) _streetController.text = street;
        if (city.isNotEmpty) _cityController.text = city;
        if (postal.isNotEmpty) _postalCodeController.text = postal;
        _state = resolvedState;
        _pinnedLat = lat;
        _pinnedLng = lng;
        _isNewAddressMapPinned = true;
        _pinnedLocationDisplay = city.isNotEmpty
            ? '$city, $resolvedState'
            : (result['address'] as String? ?? '');
      });

      _syncAddressToProvider();
    }
  }

  String _fmt(double val) => '₦${val.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',')}';

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartProvider.notifier).subtotal;
    final checkoutState = ref.watch(checkoutProvider);
    final authUser = ref.watch(authProvider).valueOrNull;

    if (authUser != null) {
      if (_nameController.text.isEmpty && authUser.name.isNotEmpty) {
        _nameController.text = authUser.name;
      }
      if (_emailController.text.isEmpty && authUser.email.isNotEmpty) {
        _emailController.text = authUser.email;
      }
      if (_phoneController.text.isEmpty && authUser.phone != null && authUser.phone!.isNotEmpty) {
        _phoneController.text = authUser.phone!;
      }
    }

    final total = subtotal + checkoutState.deliveryFee - checkoutState.discountAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAF9),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: const Text('Secure Doorstep Checkout',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: cartItems.isEmpty
          ? const Center(child: Text('Your cart is empty', style: TextStyle(color: Colors.grey, fontSize: 16)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('1', 'Delivery Address', 'Where should our farm dispatch deliver your order?'),
                  const SizedBox(height: 16),
                  _buildAddressToggle(checkoutState),
                  const SizedBox(height: 16),
                  checkoutState.isEnteringNewAddress
                      ? _buildNewAddressForm()
                      : _buildSavedAddresses(checkoutState),
                  const SizedBox(height: 32),
                  
                  _buildSectionTitle('2', 'Order Summary', 'Review your items and apply discounts'),
                  const SizedBox(height: 16),
                  _buildOrderSummary(cartItems, subtotal, checkoutState, total),
                  const SizedBox(height: 32),

                  _buildSectionTitle('3', 'Payment Method', 'Choose your preferred method of payment'),
                  const SizedBox(height: 16),
                  _buildPaymentMethods(checkoutState),
                  const SizedBox(height: 100), // padding for bottom bar
                ],
              ),
            ),
      bottomSheet: cartItems.isEmpty ? null : _buildBottomBar(checkoutState, total),
    );
  }

  Widget _buildSectionTitle(String step, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddressToggle(CheckoutState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(checkoutProvider.notifier).toggleNewAddress(false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !state.isEnteringNewAddress ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !state.isEnteringNewAddress ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : [],
                ),
                child: Center(
                  child: Text('Saved Delivery Address', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: !state.isEnteringNewAddress ? AppColors.primary : Colors.grey.shade600, fontSize: 13)),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(checkoutProvider.notifier).toggleNewAddress(true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: state.isEnteringNewAddress ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: state.isEnteringNewAddress ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))] : [],
                ),
                child: Center(
                  child: Text('Deliver to Another Location', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: state.isEnteringNewAddress ? AppColors.primary : Colors.grey.shade600, fontSize: 13)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAddresses(CheckoutState state) {
    final addressesAsync = ref.watch(addressProvider);
    final authUser = ref.watch(authProvider).valueOrNull;
    return addressesAsync.when(
      data: (addresses) {
        if (addresses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No saved addresses found.', style: TextStyle(color: Colors.grey)),
          );
        }
        if (state.selectedAddressId == null && !state.isEnteringNewAddress) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final defaultAddr = addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
            ref.read(checkoutProvider.notifier).selectAddress(defaultAddr.id);
          });
        }
        return ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: addresses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final addr = addresses[index];
            final isSelected = state.selectedAddressId == addr.id;
            return GestureDetector(
              onTap: () => ref.read(checkoutProvider.notifier).selectAddress(addr.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200, width: isSelected ? 2 : 1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (isSelected) BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))
                  ]
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? AppColors.primary : Colors.grey.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(addr.label.isNotEmpty ? addr.label : 'Address', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                          if (addr.isDefault) ...[
                            const SizedBox(height: 2),
                            Text('PERMANENT DEFAULT', style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                          ],
                          const SizedBox(height: 6),
                          Text('${addr.street}${addr.city.isNotEmpty ? ', ${addr.city}' : ''}, ${addr.state}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                          const SizedBox(height: 4),
                          Builder(builder: (context) {
                            final name = addr.recipientName.isNotEmpty ? addr.recipientName : (authUser?.name ?? '-');
                            final phone = addr.phone.isNotEmpty ? addr.phone : (authUser?.phone ?? '-');
                            final isVerified = addr.isVerified || (addr.latitude != null && addr.longitude != null && addr.latitude != 0.0 && addr.longitude != 0.0);
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Recipient: $name - Phone: $phone', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(isVerified ? Icons.location_on : Icons.warning_amber_rounded, size: 12, color: isVerified ? Colors.green : Colors.orange.shade800),
                                      const SizedBox(width: 4),
                                      Text(isVerified ? 'GPS Verified Coordinates' : 'Unverified Location', style: TextStyle(fontSize: 11, color: isVerified ? Colors.green : Colors.orange.shade800, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Text('Error loading addresses', style: TextStyle(color: Colors.red)),
    );
  }
  Widget _buildNewAddressForm() {
    return Form(
      key: _formKey,
      onChanged: _syncAddressToProvider,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              label: 'Recipient Full Name *',
              controller: _nameController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Phone Number (For Dispatch Rider) *',
              keyboardType: TextInputType.phone,
              controller: _phoneController,
            ),
            const SizedBox(height: 16),

            // Native Pinned Banner or Pin Button
            if (_isNewAddressMapPinned)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location Pinned',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF166534),
                            ),
                          ),
                          Text(
                            _pinnedLocationDisplay.isNotEmpty
                                ? _pinnedLocationDisplay
                                : '${_cityController.text}, $_state',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF15803D),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openMapPicker,
                      icon: const Icon(Icons.edit_location_alt, size: 16, color: AppColors.primary),
                      label: const Text(
                        'Change Pin',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.location_searching, color: AppColors.primary, size: 20),
                  label: const Text(
                    'Pin exact location on map',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),
            _buildTextField(
              label: 'Street Address & Landmarks *',
              controller: _streetController,
            ),
            const SizedBox(height: 16),

            // City / LGA and State Row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'City / LGA *',
                    controller: _cityController,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: kNigerianStates.contains(_state) ? _state : 'Rivers',
                    decoration: InputDecoration(
                      labelText: 'State *',
                      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    items: kNigerianStates
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _state = val);
                        _syncAddressToProvider();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Postal Code (optional / auto-filled)
            _buildTextField(
              label: 'Postal Code (Optional)',
              controller: _postalCodeController,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, TextInputType? keyboardType, Widget? suffixIcon, TextEditingController? controller, void Function(String?)? onSaved}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
      keyboardType: keyboardType,
      onSaved: onSaved,
    );
  }

    Widget _buildOrderSummary(cartItems, subtotal, CheckoutState state, double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.product.imageUrl.isNotEmpty
                        ? Image.network(item.product.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_basket_outlined, color: Colors.green, size: 24))
                        : const Icon(Icons.shopping_basket_outlined, color: Colors.green, size: 24),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(thickness: 1, height: 1),
          const SizedBox(height: 16),
          _summaryRow('Farm Produce Subtotal', _fmt(subtotal)),
          const SizedBox(height: 12),
                    Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Doorstep Delivery', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.grey.shade700)),
                        const SizedBox(width: 8),
                        if (state.deliveryOptionName != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(state.deliveryOptionName!, style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (state.deliveryEta != null)
                      Text('Est. ETA: ${state.deliveryEta}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(_fmt(state.deliveryFee), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(thickness: 1, height: 1),
          const SizedBox(height: 16),
          _summaryRow('Total Amount', _fmt(total), isTotal: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.w500, fontSize: isTotal ? 18 : 15, color: isTotal ? Colors.black87 : Colors.grey.shade700)),
        Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.w600, fontSize: isTotal ? 20 : 15, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildPaymentMethods(CheckoutState state) {
    final walletState = ref.watch(customerWalletProvider);
    final wallet = walletState.wallet;
    final isWalletActive = wallet != null && wallet.isActivated;
    final walletBalance = wallet?.balance ?? 0.0;

    final String walletSubtitle;
    if (isWalletActive) {
      walletSubtitle = 'Available: ₦${walletBalance.toStringAsFixed(2)} • Zero card fees';
    } else {
      walletSubtitle = 'Activate dedicated NUBAN to enjoy 1-tap checkout & zero card fees';
    }

    return Column(
      children: [
        _paymentTile(
          state, 
          'wallet', 
          'Dedicated Bems Wallet', 
          walletSubtitle, 
          Icons.account_balance_wallet_outlined,
          isEnabled: true,
          badge: isWalletActive ? 'Instant' : 'Setup Required',
        ),
        const SizedBox(height: 12),
        _paymentTile(
          state, 
          'card', 
          'Cards / Instant Bank Transfer / USSD', 
          'Visa, Mastercard, Verve, Instant Account Transfer & USSD', 
          Icons.credit_card_outlined,
          isEnabled: true,
        ),
        const SizedBox(height: 12),
        _paymentTile(
          state, 
          'cod', 
          'Cash on Delivery / POS', 
          state.isCodEnabled 
              ? 'Pay with cash or card swipe when your farm groceries arrive'
              : 'Temporarily unavailable for this delivery route', 
          Icons.payments_outlined,
          isEnabled: state.isCodEnabled,
        ),
      ],
    );
  }

  Widget _paymentTile(CheckoutState state, String value, String title, String subtitle, IconData icon, {bool isEnabled = true, String? badge}) {
    final isSelected = state.selectedPaymentMethod == value && isEnabled;
    return GestureDetector(
      onTap: isEnabled ? () => ref.read(checkoutProvider.notifier).setPaymentMethod(value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.shade100,
          border: Border.all(
            color: isSelected 
                ? AppColors.primary 
                : (isEnabled ? Colors.grey.shade200 : Colors.grey.shade300), 
            width: isSelected ? 2 : 1
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isSelected 
                  ? Icons.radio_button_checked 
                  : (isEnabled ? Icons.radio_button_unchecked : Icons.block), 
              color: isSelected 
                  ? AppColors.primary 
                  : (isEnabled ? Colors.grey.shade400 : Colors.grey.shade400)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 15,
                            color: isEnabled ? Colors.black87 : Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badge == 'Instant' ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badge == 'Instant' ? const Color(0xFF1B5E20) : const Color(0xFFF57F17),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (!isEnabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                          child: const Text('Unavailable', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: TextStyle(
                      fontSize: 12, 
                      color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400, 
                      height: 1.3
                    )
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: isEnabled ? Colors.grey.shade500 : Colors.grey.shade400, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(CheckoutState state, double total) {
    final String methodStr;
    if (state.selectedPaymentMethod == 'wallet') {
      methodStr = 'Bems Wallet';
    } else if (state.selectedPaymentMethod == 'cod') {
      methodStr = 'Cash on Delivery';
    } else {
      methodStr = 'Card / Bank Transfer';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, offset: Offset(0, -2), blurRadius: 10)],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: state.isProcessing ? null : () async {
                  if (state.isEnteringNewAddress) {
                    if (!_isNewAddressMapPinned) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please pin your exact location on the map first.'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        )
                      );
                      return;
                    }
                    _formKey.currentState?.save();
                  }

                  if (state.selectedPaymentMethod == 'card') {
                    final url = await ref.read(checkoutProvider.notifier).launchMonnifyCheckout();
                    if (!mounted) return;
                    if (url != null) {
                      _showPaymentWaitingSheet(context, total);
                    } else {
                      final err = ref.read(checkoutProvider).errorMessage ?? 'Failed to open payment gateway.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        )
                      );
                    }
                    return;
                  }

                  if (state.selectedPaymentMethod == 'wallet') {
                    _processWalletCheckout(context, total);
                    return;
                  }

                  // Cash on Delivery
                  final success = await ref.read(checkoutProvider.notifier).confirmOrder();
                  final updatedState = ref.read(checkoutProvider);
                  if (success && mounted) {
                    _showSuccessModal(context);
                  } else if (mounted) {
                    final err = updatedState.errorMessage ?? 'Failed to place order. Please try again.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      )
                    );
                  }
                },
                child: state.isProcessing 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Confirm Order - ${_fmt(total)} ($methodStr)', style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text('Guaranteed safe checkout - Direct farm packaging & prompt dispatch', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _processWalletCheckout(BuildContext context, double total) async {
    await ref.read(customerWalletProvider.notifier).fetchWallet(silent: true);
    final walletState = ref.read(customerWalletProvider);
    final wallet = walletState.wallet;

    if (!mounted) return;

    if (wallet == null || !wallet.isActivated) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Wallet Setup Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Your dedicated Bems Wallet NUBAN is not activated yet. Please complete quick verification with BVN or NIN to use wallet checkout.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                WalletSetupDialog.show(context);
              },
              child: const Text('Activate Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (wallet.balance < total) {
      _showInsufficientBalanceSheet(context, wallet, total);
      return;
    }

    if (!wallet.hasPaymentPin) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Payment PIN Required', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'You need to set a 4-digit security PIN for your Bems Wallet to authorize checkouts.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerWalletPage()),
                );
              },
              child: const Text('Set PIN in Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    _showWalletPinEntrySheet(context, total);
  }

  void _showInsufficientBalanceSheet(BuildContext context, CustomerWallet wallet, double total) {
    final diff = total - wallet.balance;
    final bankName = wallet.bankName ?? 'Wema Bank';
    final accountNumber = wallet.accountNumber ?? '';
    final accountName = wallet.accountName ?? 'BEMS CUSTOMER';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Insufficient Wallet Balance',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Required Total:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(_fmt(total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Available in Wallet:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      Text('₦${wallet.balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shortfall Needed:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                      Text('₦${diff.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transfer to your dedicated NUBAN to fund your wallet instantly:',
              style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFAED581)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bankName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Text(accountNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      Text(accountName, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: accountNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF1B5E20),
                          content: Text('✓ Account number copied!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 14, color: Colors.white),
                    label: const Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CustomerWalletPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Open Wallet'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(checkoutProvider.notifier).setPaymentMethod('card');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Pay with Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletPinEntrySheet(BuildContext context, double total) {
    final pinController = TextEditingController();
    String? pinError;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wallet Payment Authorization',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Text(
                          'Total to charge: ${_fmt(total)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Enter your 4-digit security PIN to complete payment from your Bems Wallet:',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinController,
                autofocus: true,
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 12),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 12),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                onChanged: (_) {
                  if (pinError != null) setSheetState(() => pinError = null);
                },
              ),
              if (pinError != null) ...[
                const SizedBox(height: 8),
                Text(
                  pinError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final pin = pinController.text.trim();
                          if (pin.length != 4) {
                            setSheetState(() => pinError = 'Please enter a valid 4-digit PIN');
                            return;
                          }
                          setSheetState(() {
                            isSubmitting = true;
                            pinError = null;
                          });

                          final success = await ref.read(checkoutProvider.notifier).confirmOrder(paymentPin: pin);
                          final updatedState = ref.read(checkoutProvider);

                          if (success && mounted) {
                            Navigator.pop(sheetContext);
                            _showSuccessModal(context);
                          } else if (mounted) {
                            final err = updatedState.errorMessage ?? 'Payment failed. Please verify your PIN.';
                            setSheetState(() {
                              isSubmitting = false;
                              pinError = err;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Authorize & Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomerWalletPage()),
                    );
                  },
                  child: const Text('Forgot Wallet PIN? Reset here', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentWaitingSheet(BuildContext context, double total) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool isChecking = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Monnify Secure Payment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your payment on the opened Monnify page using Card, Transfer, or USSD.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: isChecking
                            ? null
                            : () async {
                                setSheetState(() => isChecking = true);
                                final success = await ref
                                    .read(checkoutProvider.notifier)
                                    .confirmOrder(isAfterPayment: true);
                                if (!mounted) return;
                                setSheetState(() => isChecking = false);

                                if (success) {
                                  Navigator.pop(sheetContext);
                                  _showSuccessModal(context);
                                } else {
                                  final err = ref.read(checkoutProvider).errorMessage ??
                                      'Payment could not be verified yet. Please ensure your payment on Monnify has completed.';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(err),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: isChecking
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'I Have Completed Payment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isChecking
                            ? null
                            : () {
                                final url = ref.read(checkoutProvider).checkoutUrl;
                                if (url != null && url.isNotEmpty) {
                                  launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
                                }
                              },
                        child: const Text(
                          'Re-open Payment Page',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isChecking
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                            },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessModal(BuildContext context) {
    final placed = ref.read(checkoutProvider).placedOrder;
    final orderCode = (placed != null && placed.shortId.isNotEmpty)
        ? placed.shortId
        : (placed != null && placed.id.isNotEmpty ? placed.id : 'BFWX5B9S');
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFE9F1ED), // Light green-grey background like Img1
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Checkmark Circle
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFD4E8DC), // Lighter circle
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF65C088), // Solid green check background
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 32),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Order Placed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Text(
                'Your order #$orderCode has been placed successfully and is now being processed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, // Dark green
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Track My Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      )
    );
  }
}
