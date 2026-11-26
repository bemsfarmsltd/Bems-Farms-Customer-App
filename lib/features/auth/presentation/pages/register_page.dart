import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bems_farms/features/auth/data/repositories/token_storage.dart';
import 'package:bems_farms/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:bems_farms/features/home/presentation/pages/main_nav_page.dart';
import 'package:bems_farms/features/checkout/presentation/widgets/map_picker_dialog.dart';

import 'package:sign_in_button/sign_in_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/auth/presentation/pages/verify_email_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController(text: '440221');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedState = 'Abia';
  double? _pinnedLat;
  double? _pinnedLng;
  bool _isMapPinned = false;

  static const List<String> _states = [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno',
    'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT - Abuja', 'Gombe',
    'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos',
    'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto',
    'Taraba', 'Yobe', 'Zamfara'
  ];

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
        if (street.isNotEmpty) {
          _addressController.text = street;
        } else if ((result['address'] as String? ?? '').isNotEmpty) {
          _addressController.text = result['address'];
        }
        if (city.isNotEmpty) _cityController.text = city;
        if (postal.isNotEmpty) _postalCodeController.text = postal;
        _selectedState = resolvedState;
        _pinnedLat = lat;
        _pinnedLng = lng;
        _isMapPinned = true;
      });
    }
  }

  String _normalizeState(String raw) {
    if (raw.isEmpty) return 'Abia';
    final clean = raw.replaceAll(RegExp(r'\bstate\b', caseSensitive: false), '').trim();
    if (clean.toLowerCase().contains('abuja') ||
        clean.toLowerCase().contains('fct') ||
        clean.toLowerCase().contains('federal capital')) {
      return 'FCT - Abuja';
    }
    for (final s in _states) {
      if (clean.toLowerCase() == s.toLowerCase()) {
        return s;
      }
    }
    for (final s in _states) {
      if (s.toLowerCase().contains(clean.toLowerCase()) ||
          clean.toLowerCase().contains(s.toLowerCase())) {
        return s;
      }
    }
    return 'Abia';
  }

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  Future<void> _handleRegister() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final postalCode = _postalCodeController.text.trim().isNotEmpty
        ? _postalCodeController.text.trim()
        : '440221';
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showError('Please fill in all required fields');
      return;
    }

    if (!_validatePassword(password)) {
      _showError('Password is not strong enough. Min 8 chars, 1 uppercase, 1 number.');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    // Default to Abia / Umuahia coordinates if not manually pinned
    final lat = _pinnedLat ?? 5.5255;
    final lng = _pinnedLng ?? 7.4916;

    try {
      await ref.read(authProvider.notifier).register(
            name: '$firstName $lastName',
            email: email,
            phone: phone.startsWith('+234') ? phone : '+234$phone',
            password: password,
            address: address.isNotEmpty ? address : 'Umuahia, Abia State',
            city: city.isNotEmpty ? city : 'Umuahia',
            stateStr: _selectedState,
            latitude: lat,
            longitude: lng,
            postalCode: postalCode,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful. Please verify your email.'),
          backgroundColor: AppColors.primary,
        ),
      );

      // Navigate to verification page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailPage(email: email)),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back to home button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: AppColors.textPrimary),
                      SizedBox(width: 8),
                      Text(
                        'BACK TO HOME',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Hero Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/banner.jpg'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'JOIN BEMSFARMS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Create your\nFree Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Shop fresh produce and trusted grocery brands with an account built around your household.',
                      style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                '— BACK TO LANDING PAGE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Steps Indicator
              Row(
                children: [
                  _buildStepIndicator('1', true),
                  _buildStepLine(),
                  _buildStepIndicator('2', false),
                  _buildStepLine(),
                  _buildStepIndicator('3', false),
                ],
              ),

              const SizedBox(height: 32),
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Already have an account? ', style: TextStyle(color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Form Fields: First Name & Last Name
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('FIRST NAME'),
                        _buildTextField(_firstNameController, 'John'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('LAST NAME'),
                        _buildTextField(_lastNameController, 'Doe'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLabel('EMAIL'),
              _buildTextField(_emailController, 'you@example.com', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),

              _buildLabel('PHONE NUMBER'),
              _buildPhoneField(),
              const SizedBox(height: 4),
              const Text('Enter exactly 10 digits (e.g. 8012345678)', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 16),

              // Delivery Street Address & Map Pin
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel('DELIVERY STREET ADDRESS & MAP PIN'),
                  if (_isMapPinned && _pinnedLat != null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                          SizedBox(width: 4),
                          Text('GPS Verified', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              _buildAddressFieldWithPinButton(),
              const SizedBox(height: 16),

              // City/LGA and State Dropdown
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('CITY / LGA'),
                        _buildTextField(_cityController, 'e.g. Umuahia'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('STATE'),
                        _buildStateDropdown(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Postal Code
              _buildLabel('POSTAL CODE'),
              _buildTextField(_postalCodeController, '440221', keyboardType: TextInputType.number),
              const SizedBox(height: 16),

              _buildLabel('PASSWORD'),
              _buildPasswordField(_passwordController, _obscurePassword, () => setState(() => _obscurePassword = !_obscurePassword)),
              const SizedBox(height: 4),
              const Text('Min 8 chars, 1 uppercase, 1 number, 1 symbol', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
              const SizedBox(height: 16),

              _buildLabel('CONFIRM PASSWORD'),
              _buildPasswordField(_confirmPasswordController, _obscureConfirmPassword, () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A2B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: isLoading ? null : _handleRegister,
                  child: isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create account', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),

              const Center(child: Text('OR', style: TextStyle(color: AppColors.textHint, fontSize: 12))),
              const SizedBox(height: 16),

              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: SignInButton(
                      Buttons.google,
                      text: "Sign up with Google",
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      onPressed: () => _handleSocialLogin('Google'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: SignInButton(
                      Buttons.appleDark,
                      text: "Sign up with Apple",
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      onPressed: () => _handleSocialLogin('Apple'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Center(
                child: Text(
                  'By continuing, you agree to our Terms and acknowledge our Privacy\nPolicy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressFieldWithPinButton() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _isMapPinned ? AppColors.primary : Colors.grey.shade200,
          width: _isMapPinned ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _addressController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: "Type street or click '📍 Pin Map'",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ElevatedButton.icon(
              onPressed: _openMapPicker,
              icon: const Text('📍', style: TextStyle(fontSize: 13)),
              label: Text(
                _isMapPinned ? 'Pinned' : 'Pin Map',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSocialLogin(String provider) async {
    if (provider == 'Google') {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } else if (provider == 'Apple') {
      await ref.read(authProvider.notifier).signInWithApple();
    }

    if (!mounted) return;

    final authState = ref.read(authProvider);
    authState.when(
      data: (user) async {
        if (user != null) {
          final hasSeenOnboarding = await TokenStorage().hasSeenOnboarding();
          if (!mounted) return;
          if (hasSeenOnboarding) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => MainNavPage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => OnboardingPage()),
            );
          }
        }
      },
      error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      },
      loading: () {},
    );
  }

  Widget _buildStepIndicator(String number, bool isActive) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E3A2B) : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        height: 1,
        color: Colors.grey.shade200,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '+234',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade200),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '8012345678',
                hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedState,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: _states.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => _selectedState = newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
