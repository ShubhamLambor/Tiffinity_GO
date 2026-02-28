// lib/screens/delivery/widgets/waiting_for_order_screen.dart
import 'package:flutter/material.dart';
import '../../../models/delivery_model.dart';

class WaitingForOrderScreen extends StatelessWidget {
  final DeliveryModel order;
  final bool isUpdating;
  final VoidCallback onNavigateToMess;
  final Future<void> Function() onReachedPickup;

  const WaitingForOrderScreen({
    super.key,
    required this.order,
    required this.isUpdating,
    required this.onNavigateToMess,
    required this.onReachedPickup,
  });

  bool get _canReachPickup {
    final s = order.status.toLowerCase();
    final a = order.assignmentStatus.toLowerCase();
    return (s == 'confirmed' || s == 'ready') &&
        (a == 'accepted' || a == 'assigned');
  }

  @override
  Widget build(BuildContext context) {
    final canReachPickup = _canReachPickup;

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
                    Icon(Icons.info_outline, color: Colors.grey[500], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        canReachPickup
                            ? 'Navigate to pickup, then tap when you reach the kitchen.'
                            : 'Pickup already marked. Waiting for next step.',
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
          if (canReachPickup)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUpdating
                    ? null
                    : () async {
                  if (!_canReachPickup) return;
                  await onReachedPickup();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isUpdating
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Reached Pickup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}