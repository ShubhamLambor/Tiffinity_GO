// lib/screens/delivery/widgets/pickup_screen.dart
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import '../../../models/delivery_model.dart';

class PickupScreen extends StatelessWidget {
  final DeliveryModel order;
  final bool isUpdating;
  final Future<void> Function() onReachedPickup;
  final Future<void> Function() onPickedUp;
  final VoidCallback onNavigateToMess;

  const PickupScreen({
    super.key,
    required this.order,
    required this.isUpdating,
    required this.onReachedPickup,
    required this.onPickedUp,
    required this.onNavigateToMess,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront, color: Colors.orange, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.messName ?? 'Pickup location',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.messAddress ?? '',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, thickness: 1),
                ),
                Row(
                  children: [
                    Icon(Icons.fastfood, color: Colors.orange[400], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have reached the pickup. Mark the order as picked up once food is collected.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isUpdating ? null : onNavigateToMess,
              icon: const Icon(Icons.navigation),
              label: const Text('Navigate to Mess', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Slider Button for Order Picked Up
          isUpdating
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.orange),
            ),
          )
              : SlideAction(
            text: 'Slide to Pick Up',
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            outerColor: Colors.orange,
            innerColor: Colors.white,
            sliderButtonIcon: const Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 20),
            submittedIcon: const Icon(Icons.check, color: Colors.orange),
            borderRadius: 12,
            elevation: 0,
            onSubmit: () async {
              await onPickedUp();
              return null;
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}