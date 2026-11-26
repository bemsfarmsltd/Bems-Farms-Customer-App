import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bems_farms/core/constants/app_colors.dart';
import 'package:bems_farms/features/auth/presentation/providers/auth_providers.dart';
import 'package:bems_farms/features/auth/presentation/pages/login_page.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  final String email;
  const VerifyEmailPage({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    
    final code = _codeController.text.trim();

    try {
      await ref.read(authProvider.notifier).verifyEmail(
            email: widget.email,
            code: code,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully! You can now log in.'),
          backgroundColor: AppColors.primary,
        ),
      );

      // Navigate to login page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider) is AsyncLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE4EDE8), Color(0xFF1E3A2B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Verify Your', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.1)),
                    const Text('Email Address', style: TextStyle(color: Colors.white, fontSize: 32, fontStyle: FontStyle.italic, fontWeight: FontWeight.w300, height: 1.1)),
                    const SizedBox(height: 16),
                    Text(
                      'We\'ve sent a 6-digit code to your email. Enter it to verify your account and continue.',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Steps Indicator
                      Row(
                        children: [
                          _buildStepIndicator('1', true),
                          _buildStepLine(true),
                          _buildStepIndicator('2', true),
                          _buildStepLine(false),
                          _buildStepIndicator('3', false),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text('— BACK TO REGISTER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 24),
                      
                      const Text('Check your email', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          children: [
                            const TextSpan(text: 'Sent to: '),
                            TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      const Text('6-DIGIT CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      
                      TextFormField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          hintText: '1 2 3 4 5 6',
                          hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
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
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                        validator: (value) => value != null && value.trim().length >= 4 ? null : 'Enter a valid code',
                      ),
                      const SizedBox(height: 8),
                      const Text('The code may take a minute to arrive. Check your spam folder if you do not see it.', style: TextStyle(fontSize: 11, color: AppColors.textHint, height: 1.5)),
                      
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A2B), // Dark green
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: isLoading ? null : _verify,
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Verify and continue', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // Resend logic
                          },
                          child: const Text('Send a new code', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      Center(
                        child: Text(
                          '© 2026 BeemsFarms. Secure registration.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 1,
        color: isActive ? const Color(0xFF1E3A2B) : Colors.grey.shade200,
      ),
    );
  }
}
