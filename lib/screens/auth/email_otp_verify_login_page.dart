// lib/screens/auth/email_otp_verify_login_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_controller.dart';
import '../nav/bottom_nav.dart';
import '../deliveries/deliveries_controller.dart';
import '../home/home_controller.dart';
import 'widgets/otp_code_field.dart';

class EmailOtpVerifyLoginPage extends StatefulWidget {
  final String email;

  const EmailOtpVerifyLoginPage({super.key, required this.email});

  @override
  State<EmailOtpVerifyLoginPage> createState() =>
      _EmailOtpVerifyLoginPageState();
}

class _EmailOtpVerifyLoginPageState extends State<EmailOtpVerifyLoginPage> {
  String _otp = '';
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final loading = auth.loading || _submitting;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 24),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Enter login code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Secure one-tap login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OtpCodeField(
                                  onCompleted: (code) {
                                    setState(() => _otp = code);
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: loading || _otp.length != 6
                                        ? null
                                        : () async {
                                      setState(() => _submitting = true);
                                      final ok = await auth.loginWithOtp(
                                        widget.email,
                                        _otp,
                                      );
                                      setState(
                                              () => _submitting = false);
                                      if (!mounted) return;

                                      if (ok) {
                                        final newUserId =
                                        auth.getCurrentUserId();
                                        if (newUserId != null) {
                                          try {
                                            final homeController = context
                                                .read<HomeController>();
                                            await homeController
                                                .initialize(newUserId);
                                            final deliveriesController =
                                            context.read<
                                                DeliveriesController>();
                                            await deliveriesController
                                                .fetchDeliveries();
                                          } catch (_) {}
                                        }

                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                            const BottomNav(),
                                          ),
                                              (route) => false,
                                        );
                                      } else {
                                        final msg = auth.error ??
                                            'Login failed';
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(msg),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      const Color(0xFF2E7D32),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: loading
                                        ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                        : const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: loading
                                      ? null
                                      : () async {
                                    final ok =
                                    await auth.requestLoginOtp(
                                      widget.email,
                                    );
                                    if (!mounted) return;
                                    if (ok) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'OTP resent to your email'),
                                        ),
                                      );
                                    } else {
                                      final msg = auth.error ??
                                          'Failed to resend OTP';
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(msg),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Resend code',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (auth.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                auth.error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
