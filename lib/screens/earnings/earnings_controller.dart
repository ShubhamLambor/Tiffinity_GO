// lib/controllers/earnings_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/earnings_service.dart';
import '../../services/wallet_service.dart'; // ✅ Added WalletService import

class EarningsController extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  // --- Earnings Properties ---
  double _totalEarnings = 0;
  int _totalDeliveries = 0;
  double _avgPerDelivery = 0;
  List<Map<String, dynamic>> _recent = [];

  // --- Wallet Properties (NEW) ---
  double _walletBalance = 0.0;
  double _lockedBalance = 0.0;
  double _availableBalance = 0.0;
  List<dynamic> _statements = [];

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

  // --- Wallet Getters (NEW) ---
  double get walletBalance => _walletBalance;
  double get lockedBalance => _lockedBalance;
  double get availableBalance => _availableBalance;
  List<dynamic> get statements => _statements;

  // ✅ Start auto-refresh
  void startAutoRefresh(String partnerId, {String period = 'today'}) {
    _currentPartnerId = partnerId;
    _currentPeriod = period;

    // Initial fetch
    fetchEarnings(partnerId, period: period);

    // Auto-refresh every 30 seconds
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      print('🔄 [EARNINGS & WALLET] Auto-refresh triggered');
      fetchEarnings(partnerId, period: period, silent: true);
    });
  }

  // ✅ Stop auto-refresh
  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    print('⏸️ [EARNINGS & WALLET] Auto-refresh stopped');
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

    try {
      // ✅ Fetch both Earnings and Wallet Data concurrently for speed
      await Future.wait([
        _fetchEarningsStats(partnerId, period),
        fetchWalletData(partnerId),
      ]);
    } catch (e) {
      _error = 'Error: $e';
      print('❌ [EARNINGS CONTROLLER] Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Internal method just for earnings stats
  Future<void> _fetchEarningsStats(String partnerId, String period) async {
    final result = await EarningsService.getPartnerEarnings(
      deliveryPartnerId: partnerId,
      period: period,
    );

    if (result['success'] == true) {
      final stats = result['stats'] ?? {};
      _totalEarnings = (stats['total_earnings'] ?? 0).toDouble();
      _totalDeliveries = (stats['total_deliveries'] ?? 0) as int;
      _avgPerDelivery = (stats['avg_per_delivery'] ?? 0).toDouble();
      _recent = (result['recent_deliveries'] as List? ?? []).cast<Map<String, dynamic>>();

      print('✅ [EARNINGS] Loaded: $_totalDeliveries deliveries, ₹$_totalEarnings');
    } else {
      throw Exception(result['message'] ?? 'Failed to load earnings');
    }
  }

  // ✅ Fetch Wallet Balances and Statements (NEW)
  Future<void> fetchWalletData(String partnerId) async {
    try {
      // 1. Fetch Balance
      final balanceData = await WalletService.getBalance(partnerId);
      if (balanceData['balance'] != null) {
        _walletBalance = double.tryParse(balanceData['balance'].toString()) ?? 0.0;
        _lockedBalance = double.tryParse(balanceData['locked_balance'].toString()) ?? 0.0;
        _availableBalance = double.tryParse(balanceData['available'].toString()) ?? 0.0;
        print('✅ [WALLET] Available: ₹$_availableBalance | Locked: ₹$_lockedBalance');
      }

      // 2. Fetch Statements (Transactions)
      _statements = await WalletService.getStatements(partnerId);
    } catch (e) {
      print('❌ [WALLET] Fetch Error: $e');
      throw Exception('Failed to load wallet data');
    }
  }

  // ✅ Request a Withdrawal (NEW)
  Future<bool> requestWithdrawal(String partnerId, double amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await WalletService.requestWithdrawal(partnerId, amount);

      if (result['request_id'] != null || result['success'] == true) {
        print('✅ [WALLET] Withdrawal requested successfully');
        await fetchWalletData(partnerId); // Refresh balances instantly to move funds to "locked"
        return true;
      } else {
        _error = result['message'] ?? 'Failed to request withdrawal';
        return false;
      }
    } catch (e) {
      _error = 'Error requesting withdrawal: $e';
      print('❌ [WALLET] Withdrawal Error: $e');
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