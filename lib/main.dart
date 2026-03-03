// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Controllers ---
import 'package:deliveryui/screens/auth/auth_controller.dart';
import 'package:deliveryui/screens/auth/login_page.dart';
import 'package:deliveryui/screens/deliveries/deliveries_controller.dart';
import 'package:deliveryui/screens/earnings/earnings_controller.dart';
import 'package:deliveryui/screens/home/home_controller.dart';
import 'package:deliveryui/screens/nav/bottom_nav.dart';
import 'package:deliveryui/screens/nav/nav_controller.dart';
import 'package:deliveryui/screens/profile/profile_controller.dart';
import 'package:deliveryui/screens/splash/splash_screen.dart';
import 'package:deliveryui/screens/kyc/kyc_page.dart';
import 'core/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeliveryBoyApp());
}

class DeliveryBoyApp extends StatelessWidget {
  const DeliveryBoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => NavController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProxyProvider<AuthController, HomeController>(
          create: (_) => HomeController(),
          update: (ctx, auth, previous) {
            previous ??= HomeController();
            final partnerId = auth.getCurrentUserId();
            if (partnerId != null) {
              previous.setPartnerId(partnerId);
            }
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<AuthController, DeliveriesController>(
          create: (ctx) =>
              DeliveriesController(authController: ctx.read<AuthController>()),
          update: (ctx, auth, previous) =>
          previous ?? DeliveriesController(authController: auth),
        ),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => EarningsController()),
      ],
      child: Consumer2<LocaleProvider, SettingsProvider>(
        builder: (context, localeProvider, settingsProvider, child) {
          return MaterialApp(
            title: 'Tiffinity Delivery Partner',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,

            // ✅ FORCED LIGHT MODE
            themeMode: ThemeMode.light,
            theme: AppTheme.lightTheme,

            // 🚀 Intercepts back button globally
            builder: (context, child) {
              return AppBackInterceptor(child: child!);
            },

            home: const SplashScreen(),
            routes: {
              '/home': (context) => const BottomNav(),
              '/login': (context) => const LoginPage(),
              '/kyc': (context) => const KYCPage(),
            },
          );
        },
      ),
    );
  }
}

// --- NEW BACK BUTTON INTERCEPTOR ---

class AppBackInterceptor extends StatefulWidget {
  final Widget child;
  const AppBackInterceptor({super.key, required this.child});

  @override
  State<AppBackInterceptor> createState() => _AppBackInterceptorState();
}

class _AppBackInterceptorState extends State<AppBackInterceptor> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents immediate exit
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navigator = Navigator.maybeOf(context);
        final navController = Provider.of<NavController>(context, listen: false);

        // 1. If we are deep inside a stack (like inside the KYC page), go back normally
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }

        // 2. If we are on BottomNav but NOT on the Home tab (index 0), switch to Home tab
        if (navController.currentIndex != 0) {
          navController.changeTab(0);
          return;
        }

        // 3. Double-tap to exit logic for the Home tab
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {

          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Allow the app to close on the second quick tap
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      },
      child: widget.child,
    );
  }
}