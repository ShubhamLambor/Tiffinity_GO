// lib/screens/earnings/earnings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_controller.dart';
import 'earnings_controller.dart';

class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  String _period = 'today'; // today | week | month | all
  bool _showStatements = false; // Toggle between recent orders and wallet statements

  // --- Delivery App Theme Colors ---
  final Color primaryGreen = const Color(0xFF43A047);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEarnings();
    });
  }

  void _fetchEarnings() {
    final auth = context.read<AuthController>();
    final partnerId = auth.getCurrentUserId() ?? '';
    if (partnerId.isNotEmpty) {
      context.read<EarningsController>().fetchEarnings(partnerId, period: _period);
    }
  }

  void _changePeriod(String period) {
    if (_period == period) return;
    setState(() => _period = period);
    _fetchEarnings();
  }

  Future<void> _onRefresh() async {
    _fetchEarnings();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _showWithdrawDialog(BuildContext context, EarningsController controller) {
    final TextEditingController amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // ✅ Wrap with SingleChildScrollView to prevent overflow when keyboard opens
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, // Moves up with keyboard
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Request Withdrawal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Dark Green Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryGreen, primaryGreen.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available balance', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('₹ ${controller.availableBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'Withdrawals are created as payout requests for admin approval.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Enter Amount Label
                const Text('Enter amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),

                // 3. Text Field
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Quick Amount Chips
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _quickAmountButton('₹ 500', () => amountController.text = '500'),
                    _quickAmountButton('₹ 1000', () => amountController.text = '1000'),
                    _quickAmountButton('₹ 2000', () => amountController.text = '2000'),
                    GestureDetector(
                      onTap: () => amountController.text = controller.availableBalance.toStringAsFixed(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('MAX', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 5. Instructions Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Before you submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                      const SizedBox(height: 12),
                      _buildInstructionBullet('Request amount must be within available balance.'),
                      _buildInstructionBullet('Funds under locked balance cannot be withdrawn.'),
                      _buildInstructionBullet('Admin approval decides final payout status.'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text) ?? 0.0;

                      if (amount <= 0 || amount > controller.availableBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Amount exceeds available balance.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      final auth = context.read<AuthController>();
                      final partnerId = auth.getCurrentUserId() ?? '';
                      final success = await controller.requestWithdrawal(partnerId, amount);

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Withdrawal request submitted!'), backgroundColor: Colors.green),
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(controller.error ?? 'Request failed'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets for the Bottom Sheet ---

  Widget _quickAmountButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildInstructionBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 10),
            child: Icon(Icons.circle, size: 6, color: Colors.black54),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EarningsController>();

    if (controller.isLoading && controller.totalEarnings == 0 && controller.walletBalance == 0) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Clean light background
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: primaryGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // 1. SOLID GREEN HEADER (Background)
                  Container(
                    height: 240,
                    width: double.infinity,
                    padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: MediaQuery.of(context).padding.top + 20
                    ),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32)
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                            'My Dashboard',
                            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)
                        ),
                        GestureDetector(
                            onTap: _onRefresh,
                            child: const Icon(Icons.refresh, color: Colors.white, size: 28)
                        ),
                      ],
                    ),
                  ),

                  // 2. HERO WALLET CARD
                  // ✅ Changed from 'Positioned' to 'Padding' to fix hit-testing bug!
                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 80,
                      left: 20,
                      right: 20,
                      bottom: 10, // Adds space below the card naturally
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Available Balance',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500)
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      '₹${controller.availableBalance.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.black87, fontSize: 44, fontWeight: FontWeight.bold, letterSpacing: -1)
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                                child: Icon(Icons.account_balance_wallet, color: primaryGreen, size: 28),
                              )
                            ],
                          ),

                          if (controller.lockedBalance > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                                'Locked: ₹${controller.lockedBalance.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 13, fontWeight: FontWeight.w600)
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ✅ Withdraw Button (Will now easily receive clicks!)
                          SizedBox(
                            width: double.infinity,
                            child: Material(
                              color: controller.availableBalance > 0 ? primaryGreen : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  debugPrint('👉 Tapped Withdraw. Available: ${controller.availableBalance}');

                                  FocusScope.of(context).unfocus();

                                  if (controller.availableBalance > 0) {
                                    _showWithdrawDialog(context, controller);
                                  } else {
                                    ScaffoldMessenger.of(context).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No available balance to withdraw.',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 3),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Withdraw Funds',
                                    style: TextStyle(
                                      color: controller.availableBalance > 0 ? Colors.white : Colors.grey.shade600,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. PERIOD FILTERS (Pill shapes)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _periodPill('today', 'Today'),
                    _periodPill('week', 'Week'),
                    _periodPill('month', 'Month'),
                    _periodPill('all', 'All'),
                  ],
                ),
              ),
            ),

            // 4. METRICS ROW (Earnings & Deliveries)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Earnings Metric
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.account_balance_wallet_outlined, color: Colors.blue.shade400, size: 24)
                            ),
                            const SizedBox(height: 16),
                            Text(
                                '₹${controller.totalEarnings.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)
                            ),
                            const SizedBox(height: 4),
                            Text('Earnings', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Deliveries Metric
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.local_shipping_outlined, color: Colors.purple.shade300, size: 24)
                            ),
                            const SizedBox(height: 16),
                            Text(
                                '${controller.totalDeliveries}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)
                            ),
                            const SizedBox(height: 4),
                            Text('Deliveries', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. TAB TOGGLE (Recent Orders vs Ledger)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _tabButton(title: 'Recent Orders', isActive: !_showStatements, onTap: () => setState(() => _showStatements = false)),
                    const SizedBox(width: 24),
                    _tabButton(title: 'Wallet Ledger', isActive: _showStatements, onTap: () => setState(() => _showStatements = true)),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Dynamic List
            if (_showStatements) _buildStatementsList(controller) else _buildRecentOrdersList(controller),

            SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _periodPill(String value, String label) {
    final bool selected = _period == value;
    return GestureDetector(
      onTap: () => _changePeriod(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 3))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black87 : Colors.grey.shade600,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _tabButton({required String title, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isActive ? primaryGreen : Colors.transparent, width: 3)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            color: isActive ? primaryGreen : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrdersList(EarningsController controller) {
    if (controller.recent.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40, bottom: 40),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text("No deliveries in this period", style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final item = controller.recent[index];
          final amount = (item['amount'] ?? 0).toString();
          final title = 'Order #${item['id'] ?? ''}';
          final customer = (item['customer_name'] ?? 'Customer').toString();
          final time = (item['time'] ?? '').toString();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.green, size: 18),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                subtitle: Text('$customer • $time', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                trailing: Text('+₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              ),
            ),
          );
        },
        childCount: controller.recent.length,
      ),
    );
  }

  Widget _buildStatementsList(EarningsController controller) {
    if (controller.statements.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40, bottom: 40),
          child: Column(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text("No wallet entries yet", style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final item = controller.statements[index];
          final title = item['title'] ?? 'Transaction';
          final desc = item['description'] ?? '';
          final credit = double.tryParse(item['credit']?.toString() ?? '0') ?? 0;
          final debit = double.tryParse(item['debit']?.toString() ?? '0') ?? 0;
          final date = item['created_at']?.toString() ?? '';

          final isCredit = credit > 0;
          final amountStr = isCredit ? '+₹${credit.toStringAsFixed(0)}' : '-₹${debit.toStringAsFixed(0)}';
          final color = isCredit ? Colors.green : Colors.red.shade500;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: isCredit ? Colors.green.shade50 : Colors.red.shade50, shape: BoxShape.circle),
                  child: Icon(isCredit ? Icons.south_west : Icons.north_east, color: color, size: 18),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desc.isNotEmpty) const SizedBox(height: 4),
                    if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
                trailing: Text(amountStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              ),
            ),
          );
        },
        childCount: controller.statements.length,
      ),
    );
  }
}