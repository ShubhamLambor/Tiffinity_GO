// lib/controllers/deliveries_controller.dart

import 'package:flutter/material.dart';

import '../../data/repository/delivery_repository.dart';
import '../../models/delivery_model.dart';
import '../../services/delivery_service.dart';
import '../auth/auth_controller.dart';

class DeliveriesController extends ChangeNotifier {
  final DeliveryRepository _repo = DeliveryRepository();
  final AuthController? _authController;

  DeliveriesController({AuthController? authController})
      : _authController = authController;

  /// Tab filters: 'All', 'New', 'Pending', 'Completed', 'Cancelled'
  String _filter = 'All';
  String get filter => _filter;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<DeliveryModel> get _all => _repo.getAllDeliveries();

  /// ---------- NEW: date + sort state ----------
  DateTimeRange? _dateRange;
  String _sortBy = 'Newest'; // 'Newest', 'Oldest', 'Amount'

  DateTimeRange? get dateRange => _dateRange;
  String get sortBy => _sortBy;

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    notifyListeners();
  }

  void setSortBy(String value) {
    _sortBy = value;
    notifyListeners();
  }
  /// --------------------------------------------

  /// Map backend status to UI status groups
  /// Backend examples:
  /// - 'pending', 'out_for_delivery', 'picked_up' -> 'Pending'
  /// - 'delivered' -> 'Completed'
  /// - 'cancelled' -> 'Cancelled'
  /// - 'assigned/created' -> 'New'
  String _normalizeStatus(String backendStatus) {
    final s = backendStatus.toLowerCase();
    if (s == 'delivered') return 'Completed';
    if (s == 'cancelled' || s == 'canceled' || s == 'rejected') return 'Cancelled';
    if (s == 'pending' || s == 'out_for_delivery' || s == 'picked_up' ||
        s == 'in_transit' || s == 'accepted' || s == 'reached_pickup') {
      return 'Pending';
    }
    if (s == 'assigned' || s == 'created' || s == 'confirmed') return 'New';
    // Fallback to original text if unknown
    return backendStatus;
  }

  /// List exposed to UI, filtered by current tab + date + sort
  List<DeliveryModel> get filteredDeliveries {
    Iterable<DeliveryModel> list = _all;

    // status tab filter
    if (_filter != 'All') {
      list = list.where((d) {
        final normalized = _normalizeStatus(d.status);
        return normalized == _filter;
      });
    }

    // date range filter (expects delivery.time as ISO or parsable string)
    if (_dateRange != null) {
      list = list.where((d) {
        final dt = DateTime.tryParse(d.time ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return !dt.isBefore(_dateRange!.start) &&
            !dt.isAfter(_dateRange!.end);
      });
    }

    // sort
    List<DeliveryModel> sorted = List.of(list);
    switch (_sortBy) {
      case 'Oldest':
        sorted.sort((a, b) {
          final da = DateTime.tryParse(a.time ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse(b.time ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        });
        break;
      case 'Amount':
        sorted.sort((a, b) {
          final aa = double.tryParse(a.amount ?? '') ?? 0;
          final ab = double.tryParse(b.amount ?? '') ?? 0;
          return ab.compareTo(aa); // high to low
        });
        break;
      default: // 'Newest'
        sorted.sort((a, b) {
          final da = DateTime.tryParse(a.time ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse(b.time ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
    }

    return sorted;
  }

  /// Get new orders that need acceptance (optional usage)
  List<DeliveryModel> get newOrders {
    return _all.where((d) => _normalizeStatus(d.status) == 'New').toList();
  }

  int get totalCount => _all.length;
  int get newCount =>
      _all.where((d) => _normalizeStatus(d.status) == 'New').length;
  int get pendingCount =>
      _all.where((d) => _normalizeStatus(d.status) == 'Pending').length;
  int get completedCount =>
      _all.where((d) => _normalizeStatus(d.status) == 'Completed').length;
  int get cancelledCount =>
      _all.where((d) => _normalizeStatus(d.status) == 'Cancelled').length;

  void changeFilter(String value) {
    if (_filter == value) return;
    _filter = value;
    notifyListeners();
  }

  DeliveryModel? getById(String id) {
    try {
      return _all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  void _updateStatus(String id, String newStatus) {
    final delivery = getById(id);
    if (delivery == null) return;

    final updated = DeliveryModel(
      id: delivery.id,
      orderId: delivery.orderId,
      customerName: delivery.customerName,
      customerPhone: delivery.customerPhone,
      item: delivery.item,
      address: delivery.address,
      deliveryAddress: delivery.deliveryAddress,
      latitude: delivery.latitude,
      longitude: delivery.longitude,
      pickupLatitude: delivery.pickupLatitude,
      pickupLongitude: delivery.pickupLongitude,
      eta: delivery.eta,
      amount: delivery.amount,
      totalAmount: delivery.totalAmount,
      time: delivery.time,
      status: newStatus,
      assignmentStatus: delivery.assignmentStatus, // ⬅ important
      messName: delivery.messName,
      messAddress: delivery.messAddress,
      messPhone: delivery.messPhone,
      paymentMethod: delivery.paymentMethod,
      distBoyToMess: delivery.distBoyToMess,
      distMessToCust: delivery.distMessToCust,
      totalDistance: delivery.totalDistance,
    );


    _repo.addOrUpdateOrder(updated);
    notifyListeners();
  }

  /// ✅ Fetch/refresh all deliveries from backend
  Future fetchDeliveries() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) {
        debugPrint('⚠️ Cannot fetch deliveries: User not authenticated');
        _isLoading = false;
        _errorMessage = 'User not authenticated';
        notifyListeners();
        return;
      }

      debugPrint('🔄 Fetching deliveries for partner: $deliveryPartnerId');

      // Clear current cache
      _repo.clearDeliveries();

      // ✅ Load all types of orders
      await fetchNewOrders();
      await fetchActiveOrders();
      await fetchOrderHistory();

      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      debugPrint('✅ All deliveries fetched successfully');
      debugPrint('   Total orders: ${_repo.realDeliveryCount}');
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to fetch deliveries: $e';
      notifyListeners();
      debugPrint('❌ Error fetching deliveries: $e');
    }
  }

  /// ✅ Fetch active/ongoing orders
  Future<void> fetchActiveOrders() async {
    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) return;

      debugPrint('🔄 Fetching active orders...');
      final result = await DeliveryService.getActiveOrders(
        deliveryPartnerId: deliveryPartnerId,
      );

      if (result['success'] == true) {
        final orders = result['orders'] as List? ?? [];
        debugPrint('✅ Fetched ${result['count']} active orders');

        for (var orderData in orders) {
          try {
            final delivery = DeliveryModel.fromJson(orderData);
            _repo.addOrUpdateOrder(delivery);
            debugPrint('   ➕ Added active order: ${delivery.id}');
          } catch (e) {
            debugPrint('   ⚠️ Error parsing order: $e');
          }
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error fetching active orders: $e');
    }
  }

  /// ✅ Fetch new orders from server
  Future<void> fetchNewOrders() async {
    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) return;

      debugPrint('🔄 Fetching new orders...');
      final result = await DeliveryService.getNewOrders(
        deliveryPartnerId: deliveryPartnerId,
      );

      if (result['success'] == true) {
        final orders = result['orders'] as List? ?? [];
        debugPrint('✅ Fetched ${result['count']} new orders');

        for (var orderData in orders) {
          try {
            final delivery = DeliveryModel.fromJson(orderData);
            _repo.addOrUpdateOrder(delivery);
            debugPrint('   ➕ Added new order: ${delivery.id}');
          } catch (e) {
            debugPrint('   ⚠️ Error parsing order: $e');
          }
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error fetching new orders: $e');
    }
  }

  /// ✅ Fetch order history with optional filters
  Future<void> fetchOrderHistory({
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
    String status = 'all',
  }) async {
    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) return;

      debugPrint('🔄 Fetching order history...');

      // Use getDeliveryHistory if we have date filters, otherwise use getOrderHistory
      if (startDate != null || endDate != null || status != 'all') {
        debugPrint('   Using filtered history API...');
        if (startDate != null || endDate != null) {
          debugPrint('   Date: ${startDate?.toString().split(' ')[0] ?? 'All'} - ${endDate?.toString().split(' ')[0] ?? 'All'}');
        }
        debugPrint('   Status: $status');

        final result = await DeliveryService.getDeliveryHistory(
          deliveryPartnerId: deliveryPartnerId,
          startDate: startDate,
          endDate: endDate,
          status: status,
          limit: limit ?? 100,
        );

        if (result['success'] == true) {
          final orders = result['deliveries'] as List? ?? [];
          debugPrint('✅ Fetched ${result['count']} filtered historical orders');

          for (var orderData in orders) {
            try {
              final delivery = DeliveryModel.fromJson(orderData);
              _repo.addOrUpdateOrder(delivery);
            } catch (e) {
              debugPrint('   ⚠️ Error parsing history order: $e');
            }
          }

          notifyListeners();
        }
      } else {
        // Default: use existing getOrderHistory method
        debugPrint('   Using default history API...');
        final result = await DeliveryService.getOrderHistory(
          deliveryPartnerId: deliveryPartnerId,
          limit: limit ?? 100,
        );

        if (result['success'] == true) {
          final orders = result['orders'] as List? ?? [];
          debugPrint('✅ Fetched ${result['count']} historical orders');

          for (var orderData in orders) {
            try {
              final delivery = DeliveryModel.fromJson(orderData);
              _repo.addOrUpdateOrder(delivery);
            } catch (e) {
              debugPrint('   ⚠️ Error parsing history order: $e');
            }
          }

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching order history: $e');
    }
  }

  /// ✅ NEW: Fetch filtered deliveries specifically for history view
  Future<List<DeliveryModel>> fetchFilteredHistory({
    DateTime? startDate,
    DateTime? endDate,
    String status = 'all',
  }) async {
    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) return [];

      debugPrint('🔄 Fetching filtered history for display...');
      debugPrint('   Date: ${startDate?.toString().split(' ')[0] ?? 'All'} - ${endDate?.toString().split(' ')[0] ?? 'All'}');
      debugPrint('   Status: $status');

      final result = await DeliveryService.getDeliveryHistory(
        deliveryPartnerId: deliveryPartnerId,
        startDate: startDate,
        endDate: endDate,
        status: status,
        limit: 500,
      );

      if (result['success'] == true) {
        final orders = result['deliveries'] as List? ?? [];
        debugPrint('✅ Fetched ${result['count']} filtered deliveries for display');

        return orders.map((json) => DeliveryModel.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('❌ Error fetching filtered history: $e');
      return [];
    }
  }

  /// ✅ Fetch partner stats
  Future<Map<String, dynamic>?> fetchPartnerStats() async {
    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) return null;

      debugPrint('📊 Fetching partner stats...');
      final result = await DeliveryService.getPartnerStats(
        deliveryPartnerId: deliveryPartnerId,
      );

      if (result['success'] == true) {
        debugPrint('✅ Partner stats fetched');
        return result['stats'] as Map<String, dynamic>?;
      }
    } catch (e) {
      debugPrint('❌ Error fetching partner stats: $e');
    }
    return null;
  }

  /// ✅ Refresh all data
  Future<void> refresh() async {
    debugPrint('🔄 Refreshing all delivery data...');
    await fetchDeliveries();
  }

  /// Accept Order using DeliveryService
  Future<bool> acceptOrder(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
        notifyListeners();
        return false;
      }

      debugPrint('✅ Accepting order: $orderId');
      final result = await DeliveryService.acceptOrder(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
      );

      _isLoading = false;
      if (result['success'] == true) {
        _updateStatus(orderId, 'Pending');
        _errorMessage = null;
        await fetchDeliveries();
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Failed to accept order';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error accepting order: $e';
      notifyListeners();
      debugPrint('❌ Error accepting order: $e');
      return false;
    }
  }

  /// Reject Order using DeliveryService
  Future<bool> rejectOrder(String orderId, {String? reason}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
        notifyListeners();
        return false;
      }

      debugPrint('❌ Rejecting order: $orderId');
      final result = await DeliveryService.rejectOrder(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
        reason: reason,
      );

      _isLoading = false;
      if (result['success'] == true) {
        _repo.removeDelivery(orderId);
        _errorMessage = null;
        await fetchDeliveries();
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Failed to reject order';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error rejecting order: $e';
      notifyListeners();
      debugPrint('❌ Error rejecting order: $e');
      return false;
    }
  }

  /// ✅ Mark order as picked up
  Future<bool> markPickedUp(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
        notifyListeners();
        return false;
      }

      final result = await DeliveryService.markPickedUp(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
      );

      _isLoading = false;
      if (result['success'] == true) {
        _updateStatus(orderId, 'Pending');
        await fetchDeliveries();
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Failed to mark as picked up';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error marking as picked up: $e';
      notifyListeners();
      return false;
    }
  }

  /// ✅ Mark order as delivered
  /// ✅ Mark order as delivered
  Future<bool> markDelivered(String orderId, {required String otp, String? notes}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deliveryPartnerId = _authController?.user?.id ?? '';
      if (deliveryPartnerId.isEmpty) {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
        notifyListeners();
        return false;
      }

      // ✅ Pass the OTP to the DeliveryService
      final result = await DeliveryService.markDelivered(
        orderId: orderId,
        deliveryPartnerId: deliveryPartnerId,
        otp: otp, // <-- Added here!
        notes: notes,
      );

      _isLoading = false;
      if (result['success'] == true) {
        _updateStatus(orderId, 'Completed');
        await fetchDeliveries();
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Failed to mark as delivered';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error marking as delivered: $e';
      notifyListeners();
      return false;
    }
  }

  /// Old local-only helpers still usable from bottom sheet
  void markCompleted(String id) => _updateStatus(id, 'Completed');
  void markCancelled(String id) => _updateStatus(id, 'Cancelled');

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// ✅ Get delivery partner ID
  String? get partnerId => _authController?.user?.id;

  /// ✅ Check if user is authenticated
  bool get isAuthenticated => partnerId != null && partnerId!.isNotEmpty;
}
