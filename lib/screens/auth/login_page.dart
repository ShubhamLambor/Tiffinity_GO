// lib/screens/auth/login_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../nav/bottom_nav.dart';
import '../deliveries/deliveries_controller.dart';
import '../home/home_controller.dart';
import 'auth_controller.dart';
import 'email_otp_login_page.dart';
import 'signup_page.dart';
import 'widgets/login_form.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();

    return LoginForm(
      loading: controller.loading,
      onSubmit: (email, password) async {
        final success = await controller.login(email, password);

        if (success) {
          if (!context.mounted) return;

          // ✅ Save login state
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          // ✅ Force refresh controllers with new user ID
          final newUserId = controller.getCurrentUserId();
          if (newUserId != null) {
            debugPrint('🔄 [LOGIN] Refreshing controllers for user: $newUserId');

            try {
              // Refresh HomeController
              final homeController = context.read<HomeController>();
              await homeController.initialize(newUserId);
              debugPrint('✅ [LOGIN] HomeController refreshed');

              // Refresh DeliveriesController
              final deliveriesController =
              context.read<DeliveriesController>();
              await deliveriesController.fetchDeliveries();
              debugPrint('✅ [LOGIN] DeliveriesController refreshed');
            } catch (e) {
              debugPrint('⚠️ [LOGIN] Error refreshing controllers: $e');
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Navigate to home
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BottomNav()),
          );
        } else {
          if (!context.mounted) return;
          final error = controller.error ?? "Login failed";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      onTapRegister: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignupPage()),
        );
      },
      // New: login with email OTP
      onTapLoginWithOtp: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmailOtpLoginPage()),
        );
      },
      // New: forgot password
      onTapForgotPassword: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
        );
      },
    );
  }
}
