// lib/screens/home/home_controller.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/delivery_model.dart';
import '../../services/delivery_service.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class HomeController extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  Timer? _pollingTimer;

  // REAL DATA from backend
  List<DeliveryModel> _allDeliveries = [];
  bool _isOnline = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _partnerId;

  // Partner stats from backend
  int _todayEarnings = 0;
  int _completedToday = 0;
  int _pendingToday = 0;
  int _cancelledToday = 0;

  // Track which new orders we already showed popup for
  final Set<String> _shownNewOrderIds = {};

  // Optional: expose a stream/callback for UI to listen to new-order events
  final StreamController<Map<String, dynamic>> _newOrderController =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get newOrderStream =>
      _newOrderController.stream;

  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLocationTracking => _locationService.isTracking;
  String? get partnerId => _partnerId;

  List<DeliveryModel> get allDeliveries => _allDeliveries;
  int get totalCount => _allDeliveries.length;
  int get todayEarnings => _todayEarnings;

  int get pendingCount => _pendingToday > 0
      ? _pendingToday
      : _allDeliveries
      .where((d) => d.status.toLowerCase() == 'pending')
      .length;

  int get completedCount => _completedToday > 0
      ? _completedToday
      : _allDeliveries
      .where((d) => d.status.toLowerCase() == 'delivered')
      .length;

  int get cancelledCount => _cancelledToday > 0
      ? _cancelledToday
      : _allDeliveries
      .where((d) => d.status.toLowerCase() == 'cancelled')
      .length;

  /// 🚨 FIXED: Current active delivery logic
  DeliveryModel? get currentDelivery {
    debugPrint('═══════════════════════════════════════');
    debugPrint('🟢 CURRENT DELIVERY GETTER CALLED:');
    debugPrint('   All deliveries count: ${_allDeliveries.length}');
    if (_allDeliveries.isEmpty) {
      debugPrint('   ❌ NO DELIVERIES IN LIST');
      debugPrint('═══════════════════════════════════════');
      return null;
    }

    for (var d in _allDeliveries) {
      debugPrint('   📦 Delivery ${d.id}: status="${d.status}", assignment="${d.assignmentStatus}"');
    }

    final current = _allDeliveries.where((d) {
      final aStatus = d.assignmentStatus.toLowerCase().trim();
      final oStatus = d.status.toLowerCase().trim();

      // 1. 🚨 THE GUARD CLAUSE 🚨
      // If the assignment is waiting to be accepted, or if it was PASSED,
      // it is NEVER the current active delivery.
      if (aStatus == 'assigned' || aStatus == 'pending' || aStatus == 'passed' || aStatus.isEmpty) {
        return false;
      }

      // ... rest of the logic remains the same

      // 2. Check if the driver is actively working on it
      final isActiveAssignment =
          aStatus == 'accepted' ||
              aStatus == 'at_pickup' ||
              aStatus == 'at_pickup_location' ||
              aStatus == 'picked_up' ||
              aStatus == 'in_transit';

      // 3. Fallback only if the driver has bypassed the pending stage
      // 🚨 REMOVED: oStatus == 'accepted' (Because the restaurant sets this, not the driver!)
      final isActiveOrder =
          oStatus == 'out_for_delivery' ||
              oStatus == 'in_transit';

      return isActiveAssignment || isActiveOrder;
    }).toList();

    debugPrint('   Filtered current count: ${current.length}');
    if (current.isNotEmpty) {
      debugPrint('   ✅ FOUND CURRENT DELIVERY:');
      debugPrint('      ID: ${current.first.id}');
      debugPrint('      Status: ${current.first.status}');
      debugPrint('      Customer: ${current.first.customerName}');
    } else {
      debugPrint('   ❌ NO CURRENT DELIVERY FOUND');
    }

    debugPrint('═══════════════════════════════════════');
    return current.isNotEmpty ? current.first : null;
  }

  /// Upcoming deliveries
  List<DeliveryModel> get upcomingDeliveries {
    return _allDeliveries
        .where((d) {
      final aStatus = d.assignmentStatus.toLowerCase().trim();
      return aStatus == 'accepted';
    })
        .skip(1)
        .toList();
  }

  /// Set partner ID
  void setPartnerId(String id) {
    _partnerId = id;
    debugPrint('✅ [HOME_CONTROLLER] Partner ID set: $id');
  }

  /// Start polling for active + new orders
  void startPolling() {
    if (_partnerId == null || _partnerId!.isEmpty) {
      debugPrint(
          '❌ [HOME_CONTROLLER] Cannot start polling: Partner ID is null');
      return;
    }

    stopPolling();

    debugPrint(
        '🔄 [HOME_CONTROLLER] Starting order polling (every 5 seconds)');
    debugPrint('   Partner ID: $_partnerId');
    debugPrint('   Is Online: $_isOnline');

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      debugPrint('⏰ [HOME_CONTROLLER] Polling tick #${timer.tick}');

      if (_isOnline && _partnerId != null && _partnerId!.isNotEmpty) {
        debugPrint('   ✅ Fetching deliveries...');
        await fetchDeliveries();
        await _pollNewOrders();
      } else {
        debugPrint('   ⏸️ Skipping poll (offline or no partner ID)');
      }
    });

    debugPrint(
        '✅ [HOME_CONTROLLER] Timer created: ${_pollingTimer?.isActive}');
  }

  /// Stop polling
  void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      debugPrint('⏹️ [HOME_CONTROLLER] Polling stopped');
    }
  }

  /// Poll get_new_orders.php and emit events for UI to show popup
  Future<void> _pollNewOrders() async {
    if (_partnerId == null || _partnerId!.isEmpty) {
      return;
    }

    try {
      debugPrint(
          '🔍 [HOME_CONTROLLER] Checking new orders for partner: $_partnerId');
      final result = await DeliveryService.getNewOrders(
        deliveryPartnerId: _partnerId!,
      );

      debugPrint(
          '📥 [HOME_CONTROLLER] New Orders Result: success=${result['success']} count=${result['count']}');

      if (result['success'] == true) {
        final List orders = result['orders'] ?? [];
        for (final o in orders) {
          final orderId =
          (o['order_id'] ?? o['id'])?.toString();
          final status =
          o['status']?.toString().toLowerCase().trim();

          if (orderId == null) continue;

          // treat 'assigned' and 'confirmed' as new incoming orders
          if ((status == 'assigned' || status == 'confirmed') &&
              !_shownNewOrderIds.contains(orderId)) {
            debugPrint(
                '🆕 [HOME_CONTROLLER] New order detected: $orderId (status=$status)');
            _shownNewOrderIds.add(orderId);

            // Push event to stream; UI can listen and show dialog
            _newOrderController.add(o as Map<String, dynamic>);
          }
        }
      }
    } catch (e, st) {
      debugPrint('❌ [HOME_CONTROLLER] Error polling new orders: $e');
      debugPrint('   Stack: $st');
    }
  }

  /// Fetch partner stats from backend
  Future<void> fetchPartnerStats() async {
    if (_partnerId == null || _partnerId!.isEmpty) {
      debugPrint(
          '❌ [HOME_CONTROLLER] Cannot fetch stats: Partner ID is null');
      return;
    }

    try {
      debugPrint('📊 [HOME_CONTROLLER] Fetching partner stats...');
      final result = await DeliveryService.getPartnerStats(
        deliveryPartnerId: _partnerId!,
      );

      if (result['success'] == true && result['stats'] != null) {
        final stats = result['stats'];

        _todayEarnings = ((stats['todayearnings'] ?? 0) as num).toInt();
        _completedToday = (stats['completedtoday'] ?? 0) as int;
        _pendingToday = (stats['pendingtoday'] ?? 0) as int;
        _cancelledToday = (stats['cancelledtoday'] ?? 0) as int;

        debugPrint('✅ [HOME_CONTROLLER] Stats fetched successfully:');
        debugPrint('   Today Earnings: ₹$_todayEarnings');
        debugPrint('   Completed: $_completedToday');
        debugPrint('   Pending: $_pendingToday');
        debugPrint('   Cancelled: $_cancelledToday');

        notifyListeners();
      } else {
        debugPrint(
            '⚠️ [HOME_CONTROLLER] Stats not available from backend');
      }
    } catch (e) {
      debugPrint('❌ [HOME_CONTROLLER] Error fetching stats: $e');
    }
  }

  /// Fetch deliveries from backend
  Future<void> fetchDeliveries() async {
    if (_partnerId == null || _partnerId!.isEmpty) {
      debugPrint('❌ [HOME_CONTROLLER] Cannot fetch: Partner ID is null');
      return;
    }

    try {
      debugPrint(
          '📋 [HOME_CONTROLLER] Fetching deliveries for partner: $_partnerId');
      final data = await DeliveryService.getActiveDeliveries(_partnerId!);
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔵 [HOME_CONTROLLER] FETCHED DELIVERIES FROM API:');
      debugPrint('   Total count: ${data.length}');
      if (data.isEmpty) {
        debugPrint('   ⚠️ No deliveries returned from API');
      } else {
        for (var delivery in data) {
          debugPrint('   📦 Order ${delivery.id}: ${delivery.status}');
        }
      }
      _allDeliveries = data;
      debugPrint(
          '   ✅ Updated _allDeliveries list with ${_allDeliveries.length} items');
      debugPrint('═══════════════════════════════════════');
      _errorMessage = null;
      notifyListeners();
      debugPrint('✅ [HOME_CONTROLLER] Deliveries fetched and notified');
    } catch (e, stackTrace) {
      debugPrint('❌ [HOME_CONTROLLER] Error fetching deliveries: $e');
      debugPrint('   Stack trace: $stackTrace');
      _errorMessage = 'Failed to fetch deliveries';
      _allDeliveries = [];
      notifyListeners();
    }
  }

  /// Toggle online/offline status
  Future<void> toggleOnline() async {
    if (_isLoading) return;
    if (_partnerId == null || _partnerId!.isEmpty) {
      debugPrint('❌ Cannot toggle: Partner ID is null');
      return;
    }

    final newStatus = !_isOnline;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔄 Sending status update...');
      debugPrint('   Partner ID: $_partnerId');
      debugPrint('   Status: ${newStatus ? 1 : 0}');
      debugPrint('═══════════════════════════════════════');

      final result = await ApiService.updatePartnerStatus(
        partnerId: _partnerId!,
        isOnline: newStatus,
        partnerName: 'Delivery Partner',
      );

      if (result['success'] == true || result['status'] == 'success') {
        _isOnline = newStatus;
        debugPrint(
            '✅ Status updated: ${_isOnline ? 'Online' : 'Offline'}');

        if (_isOnline) {
          debugPrint('🌍 Starting location tracking...');
          _locationService.startLocationTracking(
            _partnerId!,
            onError: (error) {
              _errorMessage = error;
              notifyListeners();
            },
          );

          startPolling();

          await fetchDeliveries();
          await fetchPartnerStats();
        } else {
          debugPrint('🛑 Stopping location tracking...');
          _locationService.stopLocationTracking();
          stopPolling();
        }
      } else {
        _errorMessage = result['message'] ?? 'Failed to update status';
        debugPrint('❌ Error: $_errorMessage');
      }
    } catch (e) {
      debugPrint('❌ Error toggling status: $e');
      _errorMessage = 'Failed to update status';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch current status from backend
  Future<void> fetchOnlineStatus() async {
    if (_partnerId == null || _partnerId!.isEmpty) {
      debugPrint('❌ Cannot fetch status: Partner ID is null');
      return;
    }

    try {
      debugPrint('🔄 Fetching status for partner: $_partnerId');
      final result = await ApiService.getPartnerStatus(
        partnerId: _partnerId!,
      );

      if (result['success'] == true || result['status'] == 'success') {
        final statusValue = result['is_online'] ?? result['status'];
        _isOnline = statusValue == 1 ||
            statusValue == '1' ||
            statusValue == true ||
            statusValue == 'online';
        debugPrint(
            '✅ Fetched status: ${_isOnline ? 'Online' : 'Offline'}');

        if (_isOnline) {
          debugPrint('🌍 Starting location tracking...');
          _locationService.startLocationTracking(
            _partnerId!,
            onError: (error) {
              _errorMessage = error;
              notifyListeners();
            },
          );

          startPolling();
          debugPrint('✅ Polling started after fetching status');
        } else {
          _locationService.stopLocationTracking();
          stopPolling();
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error fetching status: $e');
    }
  }

  /// Initialize controller
  Future<void> initialize(String partnerId) async {
    debugPrint('🚀 [HOME_CONTROLLER] Initializing for partner: $partnerId');
    _partnerId = partnerId;
    try {
      await fetchOnlineStatus();
      await fetchDeliveries();
      await fetchPartnerStats();
      debugPrint('✅ [HOME_CONTROLLER] Initialized successfully');
      debugPrint('   Final delivery count: ${_allDeliveries.length}');
      debugPrint('   Is Online: $_isOnline');
      debugPrint(
          '   Polling Active: ${_pollingTimer?.isActive ?? false}');
    } catch (e) {
      debugPrint('❌ [HOME_CONTROLLER] Error initializing: $e');
      _errorMessage = 'Failed to initialize';
      notifyListeners();
    }
  }

  /// Force refresh all data
  Future<void> refresh() async {
    debugPrint('🔄 [HOME_CONTROLLER] Refreshing all data...');
    try {
      await fetchOnlineStatus();
      await fetchDeliveries();
      await fetchPartnerStats();
      debugPrint('✅ [HOME_CONTROLLER] All data refreshed');
    } catch (e) {
      debugPrint('❌ [HOME_CONTROLLER] Error refreshing data: $e');
      _errorMessage = 'Failed to refresh data';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setOnlineStatus(bool status) {
    if (_isOnline != status) {
      _isOnline = status;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPolling();
    //_locationService.dispose();
    _newOrderController.close();
    super.dispose();
  }
}