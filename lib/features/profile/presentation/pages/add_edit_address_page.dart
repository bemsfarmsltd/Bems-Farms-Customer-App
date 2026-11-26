import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import '../../data/models/address_model.dart';
import '../providers/address_provider.dart';
import 'location_picker_page.dart';
import 'address_search_delegate.dart';

class AddEditAddressPage extends ConsumerStatefulWidget {
  final Address? address;

  const AddEditAddressPage({super.key, this.address});

  @override
  ConsumerState<AddEditAddressPage> createState() => _AddEditAddressPageState();
}

class _AddEditAddressPageState extends ConsumerState<AddEditAddressPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _recipientNameController;
  late TextEditingController _phoneController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;
  
  String _selectedState = 'Lagos';
  final List<String> _states = const [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno',
    'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT (Abuja)', 'Gombe',
    'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos',
    'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto',
    'Taraba', 'Yobe', 'Zamfara'
  ];

  bool _isDefault = false;
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).value;

    _labelController = TextEditingController(text: widget.address?.label ?? '');
    _recipientNameController = TextEditingController(
      text: widget.address?.recipientName.isNotEmpty == true 
          ? widget.address!.recipientName 
          : (user?.name ?? ''),
    );
    _phoneController = TextEditingController(
      text: widget.address?.phone.isNotEmpty == true 
          ? widget.address!.phone 
          : (user?.phone ?? ''),
    );
    _streetController = TextEditingController(text: widget.address?.street ?? '');
    _cityController = TextEditingController(text: widget.address?.city ?? '');
    _postalCodeController = TextEditingController(text: widget.address?.postalCode ?? '');
    _isDefault = widget.address?.isDefault ?? false;
    _latitude = widget.address?.latitude;
    _longitude = widget.address?.longitude;

    final existingState = widget.address?.state.isNotEmpty == true 
        ? widget.address!.state 
        : (user?.state ?? '');
        
    if (_states.contains(existingState)) {
      _selectedState = existingState;
    } else if (existingState.toLowerCase().contains('abuja') || existingState.toLowerCase().contains('fct')) {
      _selectedState = 'FCT (Abuja)';
    } else if (_states.any((s) => s.toLowerCase() == existingState.toLowerCase())) {
      _selectedState = _states.firstWhere((s) => s.toLowerCase() == existingState.toLowerCase());
    } else {
      _selectedState = 'Lagos';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientNameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final newAddress = Address(
      id: widget.address?.id ?? '',
      label: _labelController.text.trim(),
      recipientName: _recipientNameController.text.trim(),
      phone: _phoneController.text.trim(),
      street: _streetController.text.trim(),
      city: _cityController.text.trim(),
      state: _selectedState,
      postalCode: _postalCodeController.text.trim(),
      isDefault: _isDefault,
      latitude: _latitude,
      longitude: _longitude,
    );

    try {
      if (widget.address == null) {
        await ref.read(addressProvider.notifier).addAddress(newAddress);
      } else {
        await ref.read(addressProvider.notifier).updateAddress(newAddress);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.address == null ? 'Add Address' : 'Edit Address', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Address Label
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Address Label (e.g. Home, Office)',
                  hintText: 'e.g. Home, Lekki Office',
                  prefixIcon: Icon(Icons.bookmark_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a label' : null,
              ),
              const SizedBox(height: 16),

              // Receiver's Full Name & Phone Number
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _recipientNameController,
                      decoration: const InputDecoration(
                        labelText: "Receiver's Full Name *",
                        hintText: "e.g. Dest Nacho",
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Receiver's Phone *",
                        hintText: "e.g. +23490...",
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // State Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'State *',
                  prefixIcon: Icon(Icons.map_outlined),
                  border: OutlineInputBorder(),
                ),
                value: _selectedState,
                items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedState = val);
                },
              ),
              const SizedBox(height: 16),

              // Map Pin button & Address search
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
                    );
                    if (result != null) {
                      setState(() {
                        _streetController.text = result['street'] ?? '';
                        if (result['state'] != null && result['state'].toString().isNotEmpty) {
                          final st = result['state'].toString();
                          if (_states.contains(st)) {
                            _selectedState = st;
                          } else if (_states.any((s) => s.toLowerCase() == st.toLowerCase())) {
                            _selectedState = _states.firstWhere((s) => s.toLowerCase() == st.toLowerCase());
                          }
                        }
                        if (result['city'] != null && result['city'].toString().isNotEmpty) {
                          _cityController.text = result['city'];
                        }
                        if (result['postalCode'] != null && result['postalCode'].toString().isNotEmpty) {
                          _postalCodeController.text = result['postalCode'];
                        } else if (result['postal_code'] != null && result['postal_code'].toString().isNotEmpty) {
                          _postalCodeController.text = result['postal_code'];
                        }
                        _latitude = result['latitude'];
                        _longitude = result['longitude'];
                      });
                    }
                  },
                  icon: const Icon(Icons.location_on, color: Color(0xFF1E3A2B)),
                  label: const Text('Pin exact location on map', style: TextStyle(color: Color(0xFF1E3A2B), fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5E9),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF81C784)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Street Address
              TextFormField(
                controller: _streetController,
                readOnly: true,
                onTap: () async {
                  final result = await showSearch(
                    context: context,
                    delegate: AddressSearchDelegate(DateTime.now().millisecondsSinceEpoch.toString()),
                  );
                  if (result != null) {
                    setState(() {
                      _streetController.text = result['street'] ?? '';
                      if (result['city'] != null && result['city'].toString().isNotEmpty) {
                        _cityController.text = result['city'];
                      }
                      if (result['postalCode'] != null && result['postalCode'].toString().isNotEmpty) {
                        _postalCodeController.text = result['postalCode'];
                      } else if (result['postal_code'] != null && result['postal_code'].toString().isNotEmpty) {
                        _postalCodeController.text = result['postal_code'];
                      }
                      if (result['state'] != null && result['state'].toString().isNotEmpty) {
                        final st = result['state'].toString();
                        if (_states.contains(st)) {
                          _selectedState = st;
                        } else if (_states.any((s) => s.toLowerCase() == st.toLowerCase())) {
                          _selectedState = _states.firstWhere((s) => s.toLowerCase() == st.toLowerCase());
                        }
                      }
                      _latitude = result['lat'];
                      _longitude = result['lng'];
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Street Address & Location Pin * (Tap to search)',
                  hintText: 'e.g. 14 Farm Road, Umuahia',
                  prefixIcon: Icon(Icons.streetview),
                  suffixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter street address' : null,
              ),
              const SizedBox(height: 16),

              // City / LGA & Postal Code
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City / LGA *',
                        hintText: 'e.g. Umuahia / Lekki',
                        prefixIcon: Icon(Icons.location_city),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _postalCodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Postal Code',
                        hintText: 'e.g. 440221',
                        prefixIcon: Icon(Icons.local_post_office_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Default Address switch
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('Set as Default Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Make this your permanent default delivery destination', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  value: _isDefault,
                  activeColor: const Color(0xFF1E3A2B),
                  onChanged: (val) {
                    setState(() => _isDefault = val);
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A2B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _saveAddress,
                  child: _isLoading 
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Address', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
