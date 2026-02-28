// lib/screens/delivery/widgets/delivery_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/delivery_model.dart';
import '../../../services/delivery_service.dart';
import '../../map/osm_navigation_screen.dart';
import '../order_tracking_controller.dart';

class DeliveryConfirmationScreen extends StatefulWidget {
  final DeliveryModel order;

  const DeliveryConfirmationScreen({
    super.key,
    required this.order,
  });

  @override
  State<DeliveryConfirmationScreen> createState() => _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState extends State<DeliveryConfirmationScreen> {
  bool _isProcessing = false;

  Future<void> _startOtpFlow(BuildContext context) async {
    final controller = context.read<OrderTrackingController>();
    final orderId = widget.order.id;

    setState(() => _isProcessing = true);

    try {
      final gen = await DeliveryService.generateDeliveryOtp(
        orderId: orderId,
        customerId: widget.order.customerId,
      );

      if (gen['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(gen['message'] ?? 'Failed to generate OTP'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final otpController = TextEditingController();
      final enteredOtp = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 12),
                const Text('Enter Delivery OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Ask ${widget.order.customerName} for the 4-digit OTP to confirm delivery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "••••",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: const Text('Cancel', style: TextStyle(fontSize: 16, color: Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx, otpController.text.trim());
                        },
                        child: const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

      if (enteredOtp == null || enteredOtp.isEmpty) return;

      setState(() => _isProcessing = true);

      final verify = await DeliveryService.verifyDeliveryOtp(
        orderId: orderId,
        otp: enteredOtp,
      );

      if (verify['success'] == true) {
        final success = await controller.markDelivered();
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(children: [Icon(Icons.celebration, color: Colors.white), SizedBox(width: 12), Text('Delivery Completed Successfully!')]),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(controller.errorMessage ?? 'Error finalizing delivery.'), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(verify['message'] ?? 'Invalid OTP entered.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred during verification.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivered = widget.order.status.toLowerCase() == 'delivered';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Header Status
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: delivered ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      delivered ? Icons.check_circle : Icons.delivery_dining,
                      size: 64,
                      color: delivered ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    delivered ? 'Order Delivered' : 'On the way',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    delivered
                        ? 'You have successfully delivered the order to the customer.'
                        : 'Deliver the order to the customer and complete with OTP.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  // Customer Details Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                          title: Text(widget.order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(widget.order.deliveryAddress ?? '', style: TextStyle(color: Colors.grey[600])),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: const Icon(Icons.currency_rupee, color: Colors.green),
                          ),
                          title: Text('₹${widget.order.amount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: const Text('Total order value'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- BUTTONS AT BOTTOM ---
          if (!delivered) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate to Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () {
                  if (widget.order.latitude != null && widget.order.longitude != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OSMNavigationScreen(
                          destinationLat: widget.order.latitude!,
                          destinationLng: widget.order.longitude!,
                          destinationName: widget.order.customerName,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer location not available'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified_user),
                label: Text(_isProcessing ? 'Verifying...' : 'Enter OTP & Deliver', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isProcessing ? null : () => _startOtpFlow(context),
              ),
            ),
          ],

          if (delivered)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Go back to Home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}