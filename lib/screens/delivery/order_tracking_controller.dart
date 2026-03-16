// lib/controllers/delivery/order_tracking_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/delivery_model.dart';
import '../../services/delivery_service.dart';

class OrderTrackingController extends ChangeNotifier {
  final String orderId;
  final String deliveryPartnerId;

  OrderTrackingController({
    required this.orderId,
    required this.deliveryPartnerId,
  });

  DeliveryModel? order;
  bool isLoading = false;
  bool isUpdating = false;
  String? errorMessage;

  Timer? _autoRefreshTimer;

  String get status => order?.status.toLowerCase() ?? '';
  String get assignmentStatus => order?.assignmentStatus.toLowerCase() ?? '';

  // (confirmed OR ready) + accepted/assigned => waiting stage
  bool get isAtWaiting =>
      (status == 'confirmed' || status == 'ready') &&
          (assignmentStatus == 'accepted' || assignmentStatus == 'assigned');

  // (confirmed OR ready) + at_pickup => at pickup stage
  bool get isAtPickup =>
      (status == 'confirmed' || status == 'ready') &&
          (assignmentStatus == 'at_pickup' ||
              assignmentStatus == 'at_pickup_location');


  // out_for_delivery OR assignment picked_up => picked up / in transit
  bool get isPickedUp =>
      status == 'out_for_delivery' || assignmentStatus == 'picked_up';

  bool get isDelivered => status == 'delivered';

  Future<void> loadOrderDetails() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await DeliveryService.fetchOrderDetails(
        orderId,
        deliveryPartnerId,
      );
      if (result['success'] == true && result['order'] is DeliveryModel) {
        order = result['order'] as DeliveryModel;
      } else {
        errorMessage = result['message'] ?? 'Failed to load order details';
      }
    } catch (e) {
      errorMessage = 'Error loading order details';
    } finally {
      isLoading = false;
      notifyListeners();
      _startAutoRefresh();
    }
  }

  Future<bool> markReachedPickup() async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await DeliveryService.markReachedPickup(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
      );
      if (result['success'] == true) {
        await loadOrderDetails(); // ✅ re-fetches assignment_status = at_pickup
        return true;
      } else {
        errorMessage = result['message'] ?? 'Failed to update status';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error updating order status';
      return false;
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }


  Future<bool> markPickedUp() async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await DeliveryService.markPickedUp(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
      );
      if (result['success'] == true) {
        await loadOrderDetails();
        return true;
      } else {
        errorMessage = result['message'] ?? 'Failed to update status';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error updating order status';
      return false;
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  /// Optional: if you want a separate in-transit step using markInTransit()
  Future<bool> markInTransit() async {
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await DeliveryService.markInTransit(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
      );
      if (result['success'] == true) {
        await loadOrderDetails();
        return true;
      } else {
        errorMessage = result['message'] ?? 'Failed to update status';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error updating order status';
      return false;
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  // Called after OTP success – PHP already uses action = 'delivered'
  Future<bool> markDelivered(String otp) async { // 1. Added otp parameter
    isUpdating = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await DeliveryService.markDelivered(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
        otp: otp, // 2. Pass the otp to the service
      );

      if (result['success'] == true) {
        await loadOrderDetails();
        return true;
      } else {
        errorMessage = result['message'] ?? 'Failed to update status';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error updating order status: $e';
      return false;
    } finally {
      isUpdating = false;
      notifyListeners();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) async {
        await loadOrderDetails();
      },
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
