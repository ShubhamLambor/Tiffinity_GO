// lib/controllers/earnings_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/earnings_service.dart';
import '../../services/wallet_service.dart';

class EarningsController extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  // --- Earnings Properties ---
  double _totalEarnings = 0;
  int _totalDeliveries = 0;
  double _avgPerDelivery = 0;
  List<Map<String, dynamic>> _recent = [];

  // --- Wallet Properties ---
  double _walletBalance = 0.0;
  double _lockedBalance = 0.0;
  double _availableBalance = 0.0;
  List<dynamic> _allStatements = []; // Master list of all withdrawals

  Timer? _autoRefreshTimer;
  String? _currentPartnerId;
  String _currentPeriod = 'today';

  // --- Earnings Getters ---
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get totalEarnings => _totalEarnings;
  int get totalDeliveries => _totalDeliveries;
  double get avgPerDelivery => _avgPerDelivery;
  List<Map<String, dynamic>> get recent => _recent;

  // --- Wallet Getters ---
  double get walletBalance => _walletBalance;
  double get lockedBalance => _lockedBalance;
  double get availableBalance => _availableBalance;

  // ✅ FLUTTER DATE FILTERING LOGIC
  List<dynamic> get statements {
    if (_currentPeriod == 'all') return _allStatements;

    final now = DateTime.now();

    return _allStatements.where((item) {
      if (item['created_at'] == null) return false;

      try {
        // Parse the database timestamp
        final date = DateTime.parse(item['created_at'].toString());

        if (_currentPeriod == 'today') {
          // Check if it's the exact same day
          return date.year == now.year && date.month == now.month && date.day == now.day;

        } else if (_currentPeriod == 'week') {
          // Check if it's within the current calendar week (Starts Monday)
          final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
          return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));

        } else if (_currentPeriod == 'month') {
          // Check if it's the exact same month
          return date.year == now.year && date.month == now.month;
        }
      } catch (e) {
        return false; // Skip if date parsing fails
      }
      return true;
    }).toList();
  }

  // ✅ Start auto-refresh
  void startAutoRefresh(String partnerId, {String period = 'today'}) {
    _currentPartnerId = partnerId;
    _currentPeriod = period;

    fetchEarnings(partnerId, period: period);

    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      fetchEarnings(partnerId, period: period, silent: true);
    });
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future fetchEarnings(
      String partnerId, {
        String period = 'today',
        bool silent = false,
      }) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    _currentPeriod = period; // ✅ Update current period so the getter knows how to filter

    try {
      await Future.wait([
        _fetchEarningsStats(partnerId, period),
        fetchWalletData(partnerId), // We no longer need to pass period to PHP
      ]);
    } catch (e) {
      _error = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchEarningsStats(String partnerId, String period) async {
    final result = await EarningsService.getPartnerEarnings(
      deliveryPartnerId: partnerId,
      period: period, // Period is still sent here because deliveries are filtered in backend
    );

    if (result['success'] == true) {
      final stats = result['stats'] ?? {};
      _totalEarnings = (stats['total_earnings'] ?? 0).toDouble();
      _totalDeliveries = (stats['total_deliveries'] ?? 0) as int;
      _avgPerDelivery = (stats['avg_per_delivery'] ?? 0).toDouble();
      _recent = (result['recent_deliveries'] as List? ?? []).cast<Map<String, dynamic>>();
    } else {
      throw Exception(result['message'] ?? 'Failed to load earnings');
    }
  }

  // ✅ Fetch ALL Wallet Data (No period parameter needed)
  Future<void> fetchWalletData(String partnerId) async {
    try {
      // 1. Fetch Balance
      final balanceData = await WalletService.getBalance(partnerId);
      if (balanceData['balance'] != null) {
        _walletBalance = double.tryParse(balanceData['balance'].toString()) ?? 0.0;
        _lockedBalance = double.tryParse(balanceData['locked_balance'].toString()) ?? 0.0;
        _availableBalance = double.tryParse(balanceData['available'].toString()) ?? 0.0;
      }

      // 2. Fetch Statements (Gets all 100, Dart filters them)
      _allStatements = await WalletService.getStatements(partnerId);
    } catch (e) {
      throw Exception('Failed to load wallet data');
    }
  }

  // ✅ Request a Withdrawal
  Future<bool> requestWithdrawal(String partnerId, double amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await WalletService.requestWithdrawal(partnerId, amount);

      if (result['request_id'] != null || result['success'] == true) {
        await fetchWalletData(partnerId);
        return true;
      } else {
        _error = result['message'] ?? 'Failed to request withdrawal';
        return false;
      }
    } catch (e) {
      _error = 'Error requesting withdrawal: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}