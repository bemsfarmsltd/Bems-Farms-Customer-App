import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_update_gate.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize customer notification channels and local notification permissions
  await CustomerNotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: BemsFarmsApp(),
    ),
  );
}

class BemsFarmsApp extends StatelessWidget {
  const BemsFarmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BemsFarms',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      builder: (context, child) {
        return AppUpdateGate(
          appType: 'customer',
          child: child!,
        );
      },
    );
  }
}
