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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEarnings();
    });
  }

  // ✅ Extract fetch logic to reuse
  void _fetchEarnings() {
    final auth = context.read<AuthController>();
    final partnerId = auth.getCurrentUserId() ?? '';
    if (partnerId.isNotEmpty) {
      context
          .read<EarningsController>()
          .fetchEarnings(partnerId, period: _period);
    }
  }

  void _changePeriod(String period) {
    if (_period == period) return;
    setState(() => _period = period);
    _fetchEarnings();
  }

  // ✅ Pull-to-refresh handler
  Future<void> _onRefresh() async {
    print('🔄 [EARNINGS] Manual refresh triggered');
    _fetchEarnings();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ✅ Withdraw Dialog
  void _showWithdrawDialog(BuildContext context, EarningsController controller) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Request Withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Available Balance: ₹${controller.availableBalance.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount to withdraw (₹)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0.0;

                if (amount <= 0 || amount > controller.availableBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid amount'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(ctx); // Close dialog

                // Trigger request
                final auth = context.read<AuthController>();
                final partnerId = auth.getCurrentUserId() ?? '';
                final success = await controller.requestWithdrawal(partnerId, amount);

                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Withdrawal requested successfully!'), backgroundColor: Colors.green),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(controller.error ?? 'Request failed'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EarningsController>();

    if (controller.isLoading && controller.totalEarnings == 0) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF43A047),
        child: CustomScrollView(
          slivers: [
            // Header + Today card + period filters + Wallet
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Earnings & Wallet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              onPressed: _onRefresh,
                              icon: const Icon(Icons.refresh, color: Colors.white, size: 26),
                            ),
                          ],
                        ),
                      ),

                      // Today's Earnings Card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF43A047).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.today,
                                  color: Color(0xFF43A047),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _getPeriodLabel(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "₹ ${controller.totalEarnings.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF43A047).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.trending_up,
                                      color: Color(0xFF43A047),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${controller.totalDeliveries} deliveries",
                                      style: const TextStyle(
                                        color: Color(0xFF43A047),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "• Avg ₹${controller.avgPerDelivery.toStringAsFixed(0)}",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Period filter buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            _periodChip('today', 'Today'),
                            const SizedBox(width: 8),
                            _periodChip('week', 'This Week'),
                            const SizedBox(width: 8),
                            _periodChip('month', 'This Month'),
                            const SizedBox(width: 8),
                            _periodChip('all', 'All Time'),
                          ],
                        ),
                      ),

                      // ✅ WALLET BALANCE SECTION (NEW)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Available to Withdraw', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '₹${controller.availableBalance.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)
                                  ),
                                  if (controller.lockedBalance > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text('Pending: ₹${controller.lockedBalance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                    ),
                                ],
                              ),
                              ElevatedButton(
                                onPressed: controller.availableBalance > 0
                                    ? () => _showWithdrawDialog(context, controller)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                ),
                                child: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Toggle between Recent Activity and Statements
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showStatements ? 'Wallet Statements' : 'Recent Activity',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    // Toggle Button
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showStatements = !_showStatements;
                        });
                      },
                      icon: Icon(_showStatements ? Icons.list_alt : Icons.account_balance_wallet, size: 16, color: Colors.green),
                      label: Text(_showStatements ? 'View Orders' : 'View Ledger', style: const TextStyle(color: Colors.green)),
                    )
                  ],
                ),
              ),
            ),

            // Dynamic List (Orders vs Statements)
            if (_showStatements)
              _buildStatementsList(controller)
            else
              _buildRecentOrdersList(controller),

            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Extracted Orders List for cleaner code
  Widget _buildRecentOrdersList(EarningsController controller) {
    if (controller.recent.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text("No recent transactions", style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final item = controller.recent[index];
          final amount = (item['total_amount'] ?? item['amount'] ?? 0).toString();
          final title = 'Order #${item['id'] ?? ''}';
          final customer = (item['customer_name'] ?? 'Customer').toString();
          final address = (item['delivery_address'] ?? '').toString();
          final time = (item['time'] ?? '').toString();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(customer, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
                trailing: Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
              ),
            ),
          );
        },
        childCount: controller.recent.length,
      ),
    );
  }

  // ✅ New Statements List view
  Widget _buildStatementsList(EarningsController controller) {
    if (controller.statements.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text("No ledger history found", style: TextStyle(color: Colors.grey[500], fontSize: 15)),
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
          final color = isCredit ? Colors.green : Colors.red;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 18),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
                trailing: Text(amountStr, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              ),
            ),
          );
        },
        childCount: controller.statements.length,
      ),
    );
  }

  // ✅ Helper to get period label
  String _getPeriodLabel() {
    switch (_period) {
      case 'today':
        return "Today's Earnings";
      case 'week':
        return "This Week's Earnings";
      case 'month':
        return "This Month's Earnings";
      case 'all':
        return "Total Earnings";
      default:
        return "Earnings";
    }
  }

  Widget _periodChip(String value, String label) {
    final bool selected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changePeriod(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF43A047) : Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}