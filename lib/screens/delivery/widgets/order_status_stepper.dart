// lib/screens/delivery/widgets/order_status_stepper.dart
import 'package:flutter/material.dart';

class OrderStatusStepper extends StatelessWidget {
  final String status;
  final String assignmentStatus;

  const OrderStatusStepper({
    super.key,
    required this.status,
    required this.assignmentStatus,
  });

  int get _currentStep {
    final s = status.toLowerCase();
    final a = assignmentStatus.toLowerCase();

    if (s == 'delivered') return 3;
    if (s == 'out_for_delivery' || a == 'picked_up' || a == 'in_transit') return 2;
    if (a == 'at_pickup' || a == 'at_pickup_location') return 1;

    return 0; // confirmed / accepted
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStep;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
      child: Row(
        children: [
          _buildDot(context, 0, step, 'Accepted'),
          _buildDivider(step >= 1),
          _buildDot(context, 1, step, 'At pickup'),
          _buildDivider(step >= 2),
          _buildDot(context, 2, step, 'On the way'),
          _buildDivider(step >= 3),
          _buildDot(context, 3, step, 'Delivered'),
        ],
      ),
    );
  }

  Widget _buildDot(BuildContext context, int index, int current, String label) {
    final active = index <= current;
    final color = active ? Colors.green : Colors.grey.shade300;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: Icon(
            active ? Icons.check : Icons.circle,
            size: 16,
            color: active ? Colors.white : Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool active) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18), // Align with circles
        height: 3,
        decoration: BoxDecoration(
          color: active ? Colors.green : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}