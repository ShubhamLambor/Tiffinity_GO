// lib/screens/delivery/order_tracking_screen.dart
import 'package:deliveryui/screens/delivery/widgets/delivery_confirmation_screen.dart';
import 'package:deliveryui/screens/delivery/widgets/order_status_stepper.dart';
import 'package:deliveryui/screens/delivery/widgets/pickup_screen.dart';
import 'package:deliveryui/screens/delivery/widgets/waiting_for_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'order_tracking_controller.dart';
import '../map/osm_navigation_screen.dart';
import '../../models/delivery_model.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  final String deliveryPartnerId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.deliveryPartnerId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrderTrackingController>(
      create: (_) => OrderTrackingController(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
      )..loadOrderDetails(),
      child: const _OrderTrackingView(),
    );
  }
}

class _OrderTrackingView extends StatelessWidget {
  const _OrderTrackingView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OrderTrackingController>();

    final order = controller.order;
    final isLoading = controller.isLoading && order == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Match Home background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Column(
          children: [
            const Text(
              'Track Order',
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              controller.orderId,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : order == null
          ? Center(
        child: Text(
          controller.errorMessage ?? 'Order not found',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : Column(
        children: [
          OrderStatusStepper(
            status: controller.status,
            assignmentStatus: controller.assignmentStatus,
          ),
          Expanded(
            child: _buildStageScreen(context, controller, order),
          ),
        ],
      ),
    );
  }

  Widget _buildStageScreen(
      BuildContext context,
      OrderTrackingController c,
      DeliveryModel order,
      ) {
    // Final stage
    if (c.isDelivered) {
      return DeliveryConfirmationScreen(order: order);
    }

    // Picked up / out_for_delivery stage
    if (c.isPickedUp) {
      return DeliveryConfirmationScreen(order: order);
    }

    // At pickup: assignment_status == 'at_pickup'
    if (c.isAtPickup) {
      return PickupScreen(
        order: order,
        isUpdating: c.isUpdating,
        onReachedPickup: () async {},
        onPickedUp: () async {
          await c.markPickedUp();
        },
        onNavigateToMess: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OSMNavigationScreen(
                destinationLat: order.pickupLatitude!,
                destinationLng: order.pickupLongitude!,
                destinationName: order.messName ?? 'Pickup',
              ),
            ),
          );
        },
      );
    }

    // Default: confirmed + accepted/assigned, not yet at pickup
    return WaitingForOrderScreen(
      order: order,
      isUpdating: c.isUpdating,
      onNavigateToMess: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OSMNavigationScreen(
              destinationLat: order.pickupLatitude!,
              destinationLng: order.pickupLongitude!,
              destinationName: order.messName ?? 'Pickup',
            ),
          ),
        );
      },
      onReachedPickup: () async {
        if (!c.isAtWaiting) return;
        await c.markReachedPickup();
      },
    );
  }
}