// lib/screens/home/home_page.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

// Controllers & Services
import '../../services/map_service.dart';
import '../delivery/order_tracking_screen.dart';
import 'home_controller.dart';
import '../auth/auth_controller.dart';
import '../deliveries/deliveries_controller.dart';
import '../map/osm_navigation_screen.dart';
import '../../services/delivery_service.dart';

// Models
import '../../models/delivery_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? pollingTimer;
  // ✅ REMOVED: _lastShownOrderId as it caused the double-popup bug

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      requestLocationPermission();

      final auth = context.read<AuthController>();
      final partnerId = auth.getCurrentUserId();

      if (partnerId == null || partnerId.isEmpty) {
        debugPrint('❌ Cannot initialize: User ID is null/invalid');
        return;
      }

      final home = context.read<HomeController>();
      home.initialize(partnerId).then((_) {
        debugPrint('✅ HomeController initialized');
        if (mounted) {
          startPolling();
        }
      }).catchError((error) {
        debugPrint('❌ HomeController initialization failed: $error');
      });
    });
  }

  void startPolling() {
    if (!mounted) return;

    final auth = context.read<AuthController>();
    final uid = auth.getCurrentUserId();

    if (uid == null || uid.isEmpty) return;

    pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final home = context.read<HomeController>();
      if (!home.isOnline) return;

      try {
        final result = await DeliveryService.checkPendingAssignments(uid);
        final assignment = result['assignment'];

        if (result['success'] == true &&
            result['has_pending'] == true &&
            assignment != null &&
            assignment is Map) {

          timer.cancel(); // Stop polling while sheet is open

          if (mounted) {
            final newOrder = DeliveryModel.fromJson(Map<String, dynamic>.from(assignment));
            await _showNewOrderPopup(newOrder);
            if (mounted) startPolling(); // Restart polling after sheet closes
          }
        }
      } catch (e) {
        debugPrint('❌ Polling error: $e');
      }
    });
  }

  void stopPolling() {
    if (pollingTimer != null) {
      pollingTimer!.cancel();
      pollingTimer = null;
    }
  }

  Future _handleRefresh() async {
    if (!mounted) return;
    final home = context.read<HomeController>();
    final deliveries = context.read<DeliveriesController>();

    try {
      await Future.wait([
        home.refresh(),
        deliveries.fetchDeliveries(),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 20), SizedBox(width: 12), Text('Data refreshed successfully!')]),
            backgroundColor: Colors.green, duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to refresh data'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showNewOrderPopup(DeliveryModel order) async {
    final auth = context.read<AuthController>();
    final uid = auth.getCurrentUserId() ?? '';

    await showModalBottomSheet(
      context: context, isScrollControlled: true, isDismissible: false, enableDrag: false, backgroundColor: Colors.transparent,
      builder: (ctx) => NewOrderSheet(
        order: order,
        onAccept: () async { Navigator.pop(ctx); await _handleAcceptOrderFlow(order, uid); },
        onReject: () async { Navigator.pop(ctx); await _handleRejectOrderFlow(order.id, uid); },
      ),
    );
  }

  Future<void> _handleAcceptOrderFlow(DeliveryModel order, String partnerId) async {
    if (order.assignmentStatus.toLowerCase() == 'accepted') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order already assigned!'), backgroundColor: Colors.green));
        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id, deliveryPartnerId: partnerId)));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Row(children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 16), Text('Accepting order...')]), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
    }

    final result = await DeliveryService.acceptOrder(orderId: order.id, deliveryPartnerId: partnerId);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order accepted!'), backgroundColor: Colors.green));
        await Future.wait([context.read<DeliveriesController>().fetchDeliveries(), context.read<HomeController>().fetchDeliveries()]);
        if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id, deliveryPartnerId: partnerId)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to accept order'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleRejectOrderFlow(String orderId, String partnerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order?'), content: const Text('Are you sure you want to reject this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Reject')),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final result = await DeliveryService.rejectOrder(orderId: orderId, deliveryPartnerId: partnerId, reason: 'User declined');
      if (mounted) {
        if (result['success'] == true) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order rejected'), backgroundColor: Colors.orange));
        else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Failed to reject'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error rejecting order'), backgroundColor: Colors.red));
    }
  }

  Future<void> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showLocationServiceDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showPermissionPermanentlyDeniedDialog();
      return;
    }
  }

  void _showLocationServiceDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Location Services Disabled'), content: const Text('Please enable location services.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
  }

  void _showPermissionDeniedDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Permission Required'), content: const Text('App needs location access.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () { Navigator.pop(context); requestLocationPermission(); }, child: const Text('Retry'))]));
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Permission Denied'), content: const Text('Enable location in settings.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton(onPressed: () { Geolocator.openAppSettings(); Navigator.pop(context); }, child: const Text('Settings'))]));
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();
    final auth = context.watch<AuthController>();
    final deliveriesController = context.watch<DeliveriesController>();

    final completed = home.completedCount == 0 ? deliveriesController.completedCount : home.completedCount;
    final pending = home.pendingCount == 0 ? deliveriesController.pendingCount : home.pendingCount;
    final cancelled = home.cancelledCount == 0 ? deliveriesController.cancelledCount : home.cancelledCount;

    final bool isOnline = home.isOnline;
    final String userName = auth.user?.name ?? 'Delivery Partner';
    final now = DateTime.now();
    final dateStr = DateFormat('EEE, d MMM').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.green,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ===== HEADER SECTION =====
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: 240,
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOnline ? [const Color(0xFF2E7D32), const Color(0xFF4CAF50)] : [const Color(0xFFC62828), const Color(0xFFEF5350)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hello, $userName', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                            ],
                          ),
                        ),
                        Row(
                          // children: [
                          //   Container(
                          //     decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          //     child: IconButton(icon: const Icon(Icons.support_agent, color: Colors.white, size: 26), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatbotPage())); }),
                          //   ),
                          //   const SizedBox(width: 8),
                          //   Container(
                          //     padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          //     child: CircleAvatar(radius: 20, backgroundColor: Colors.white, child: Icon(Icons.person, color: isOnline ? Colors.green : Colors.red)),
                          //   ),
                          // ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SwipeToggleButton(isOnline: isOnline, onToggle: home.isLoading ? null : home.toggleOnline),
                  ],
                ),
              ),

              // ===== STATS GRID =====
              Transform.translate(
                offset: const Offset(0, -60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true, crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6, physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStatCard('Today\'s Earnings', home.todayEarnings.toString(), Icons.currency_rupee, Colors.orange),
                      _buildStatCard('Completed', completed.toString(), Icons.check_circle, Colors.green),
                      _buildStatCard('Pending', pending.toString(), Icons.access_time, Colors.blue),
                      _buildStatCard('Cancelled', cancelled.toString(), Icons.cancel, Colors.red),
                    ],
                  ),
                ),
              ),

              // ===== NEW: ACTIVE DELIVERY BANNER =====
              if (home.currentDelivery != null)
                Transform.translate(
                  offset: const Offset(0, -70),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Delivery',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildActiveDeliveryCard(
                          context,
                          home.currentDelivery!,
                          auth.getCurrentUserId() ?? '',
                        ),
                      ],
                    ),
                  ),
                ),

              // ===== MAIN CONTENT (MAP & MESSES) =====
              Transform.translate(
                offset: Offset(0, home.currentDelivery != null ? -60 : -80),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NearbyMessesSection(
                        onViewMapTapped: () {
                          // You can link this to your global map screen later
                        },
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== UI HELPER WIDGETS =====
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
              const Spacer(),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildActiveDeliveryCard(BuildContext context, DeliveryModel delivery, String partnerId) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade400, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))
            ]
        ),
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Push the user right back to the tracking screen
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(
                              orderId: delivery.id,
                              deliveryPartnerId: partnerId
                          )
                      )
                  );
                },
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.delivery_dining, color: Colors.green, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('ACTIVE DELIVERY', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(delivery.messName ?? 'Pickup Location', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('To: ${delivery.customerName}', style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            )
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
                        ),
                      ],
                    )
                )
            )
        )
    );
  }
}

// ===== SWIPE TOGGLE BUTTON =====
class SwipeToggleButton extends StatefulWidget {
  final bool isOnline;
  final VoidCallback? onToggle;

  const SwipeToggleButton({
    super.key,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  State<SwipeToggleButton> createState() => _SwipeToggleButtonState();
}

class _SwipeToggleButtonState extends State<SwipeToggleButton> {
  double dragPosition = 0.0;
  bool isDragging = false;

  @override
  Widget build(BuildContext context) {
    final canToggle = widget.onToggle != null;

    return Opacity(
      opacity: canToggle ? 1.0 : 0.6,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width - 40;

          const height = 54.0;
          final thumbWidth = maxWidth / 2;
          final maxDrag = maxWidth - thumbWidth;

          final targetPosition = widget.isOnline ? maxDrag : 0.0;
          final currentPosition = isDragging ? dragPosition : targetPosition;
          final dragPercentage = (currentPosition / maxDrag).clamp(0.0, 1.0);

          final backgroundColor = Color.lerp(
            Colors.red.shade400,
            Colors.green.shade600,
            dragPercentage,
          )!;

          return Container(
            height: height,
            width: maxWidth,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: !widget.isOnline && !isDragging ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 200),
                          child: const Text(
                            'Offline',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: widget.isOnline && !isDragging ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 200),
                          child: const Text(
                            'Online',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedPositioned(
                  duration: isDragging ? Duration.zero : const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  left: currentPosition,
                  top: 2,
                  bottom: 2,
                  child: GestureDetector(
                    onHorizontalDragStart: canToggle
                        ? (_) => setState(() {
                      isDragging = true;
                      dragPosition = targetPosition;
                    })
                        : null,
                    onHorizontalDragUpdate: canToggle
                        ? (details) => setState(() {
                      dragPosition = (dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                    })
                        : null,
                    onHorizontalDragEnd: canToggle
                        ? (_) {
                      setState(() {
                        isDragging = false;
                        if (dragPosition > maxDrag / 2 && !widget.isOnline) {
                          HapticFeedback.lightImpact();
                          widget.onToggle?.call();
                        } else if (dragPosition < maxDrag / 2 && widget.isOnline) {
                          HapticFeedback.lightImpact();
                          widget.onToggle?.call();
                        } else {
                          dragPosition = widget.isOnline ? maxDrag : 0.0;
                        }
                      });
                    }
                        : null,
                    onTap: canToggle
                        ? () {
                      if (!isDragging) {
                        HapticFeedback.lightImpact();
                        widget.onToggle?.call();
                      }
                    }
                        : null,
                    child: Container(
                      width: thumbWidth - 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isOnline ? Icons.verified_user : Icons.power_settings_new,
                            color: backgroundColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: backgroundColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// 🛠️ WIDGET: Modern New Order Bottom Sheet
// ---------------------------------------------------------
class NewOrderSheet extends StatefulWidget {
  final DeliveryModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const NewOrderSheet({super.key, required this.order, required this.onAccept, required this.onReject});
  @override
  State<NewOrderSheet> createState() => _NewOrderSheetState();
}
class _NewOrderSheetState extends State<NewOrderSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  @override void initState() { super.initState(); _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true); }
  @override void dispose() { _pulseController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.70,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black26)]),
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.only(top: 24, bottom: 10), child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [AnimatedBuilder(animation: _pulseController, builder: (context, child) { return Container(decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.5 * _pulseController.value), blurRadius: 10 * _pulseController.value, spreadRadius: 2 * _pulseController.value)]), child: child); }, child: const Icon(Icons.notifications_active, color: Colors.orange, size: 28)), const SizedBox(width: 12), const Text('NEW REQUEST', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5))]))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 10), Text('ESTIMATED EARNINGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2)), const SizedBox(height: 4), Text('₹${widget.order.amount}', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))), const SizedBox(height: 30),
                    Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.storefront, color: Colors.orange, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.order.messName ?? 'Restaurant', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text('Pickup Location', style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)]))]),
                    Padding(padding: const EdgeInsets.only(left: 22), child: Align(alignment: Alignment.centerLeft, child: Container(height: 30, width: 2, color: Colors.grey[300]))),
                    Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_pin_circle, color: Colors.black, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.order.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(widget.order.deliveryAddress ?? widget.order.address, style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)]))]),
                    const Spacer(),
                    if (widget.order.hasDistanceData) Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.directions_bike, size: 16, color: Colors.blue), const SizedBox(width: 8), Text(widget.order.formattedTotalDistance, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))])),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 30), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -5), blurRadius: 10)]),
              child: Column(children: [SlideToAcceptButton(onAccept: widget.onAccept), const SizedBox(height: 16), TextButton(onPressed: widget.onReject, child: Text('Reject Order', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 16)))]),
            ),
          ],
        ),
      ),
    );
  }
}

class SlideToAcceptButton extends StatefulWidget {
  final VoidCallback onAccept;
  const SlideToAcceptButton({super.key, required this.onAccept});
  @override State<SlideToAcceptButton> createState() => _SlideToAcceptButtonState();
}
class _SlideToAcceptButtonState extends State<SlideToAcceptButton> {
  double _position = 0.0;
  bool _submitted = false;
  @override Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth; final maxDrag = maxWidth - 60;
      return Container(
        height: 64, width: maxWidth, decoration: BoxDecoration(color: _submitted ? Colors.green : Colors.grey[200], borderRadius: BorderRadius.circular(32)),
        child: Stack(children: [
          Center(child: Opacity(opacity: _submitted ? 0 : (1 - (_position / maxDrag)).clamp(0.0, 1.0), child: const Text('Slide to Accept Order  >>>', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 16)))),
          if (_submitted) const Center(child: Text('ACCEPTED!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5))),
          AnimatedPositioned(
            duration: Duration(milliseconds: _submitted ? 200 : 0), curve: Curves.easeOut, left: _submitted ? maxWidth - 60 : _position,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) { if (_submitted) return; setState(() { _position = (_position + details.delta.dx).clamp(0.0, maxDrag); }); },
              onHorizontalDragEnd: (details) { if (_submitted) return; if (_position > maxDrag * 0.75) { setState(() { _submitted = true; _position = maxDrag; }); widget.onAccept(); } else { setState(() { _position = 0.0; }); } },
              child: Container(height: 56, width: 56, margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: _submitted ? Colors.white : Colors.green, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]), child: Icon(_submitted ? Icons.check : Icons.chevron_right, color: _submitted ? Colors.green : Colors.white, size: 30)),
            ),
          ),
        ]),
      );
    });
  }
}

// ---------------------------------------------------------
// 🗺️ WIDGET: Nearby Messes (5km Radius Map & List)
// ---------------------------------------------------------
class NearbyMessesSection extends StatefulWidget {
  final VoidCallback onViewMapTapped;

  const NearbyMessesSection({super.key, required this.onViewMapTapped});

  @override
  State<NearbyMessesSection> createState() => _NearbyMessesSectionState();
}

class _NearbyMessesSectionState extends State<NearbyMessesSection> {
  late MapController _miniMapController;
  bool _isLoading = false;

  List<Map<String, dynamic>> _filteredMesses = [];

  @override
  void initState() {
    super.initState();
    _miniMapController = MapController(
      initMapWithUserPosition: const UserTrackingOption(enableTracking: true, unFollowUser: false),
    );
  }

  @override
  void dispose() {
    _miniMapController.dispose();
    super.dispose();
  }

  Future<void> _onMapReady(bool isReady) async {
    if (!isReady) return;

    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      GeoPoint userLocation = GeoPoint(latitude: position.latitude, longitude: position.longitude);

      await _miniMapController.moveTo(userLocation, animate: true);
      await Future.delayed(const Duration(milliseconds: 300));
      await _miniMapController.setZoom(zoomLevel: 15.0);

      await _miniMapController.drawCircle(
          CircleOSM(
            key: "5km_radius",
            centerPoint: userLocation,
            radius: 5000,
            color: Colors.lightBlueAccent.withOpacity(0.2),
            strokeWidth: 2,
            borderColor: Colors.blueAccent,
          )
      );

      final allMesses = await MapService.fetchNearbyMesses();
      List<Map<String, dynamic>> nearby = [];

      for (var mess in allMesses) {
        if (mess['latitude'] != null && mess['longitude'] != null) {
          final lat = double.tryParse(mess['latitude'].toString());
          final lng = double.tryParse(mess['longitude'].toString());

          if (lat != null && lng != null) {
            double distanceInMeters = Geolocator.distanceBetween(
                position.latitude, position.longitude, lat, lng
            );

            if (distanceInMeters <= 5000) {
              mess['distance'] = distanceInMeters;
              nearby.add(mess);

              await _miniMapController.addMarker(
                GeoPoint(latitude: lat, longitude: lng),
                markerIcon: MarkerIcon(iconWidget: _buildCustomMarker()),
              );
            }
          }
        }
      }

      nearby.sort((a, b) => a['distance'].compareTo(b['distance']));

      if (mounted) {
        setState(() { _filteredMesses = nearby; });
      }

    } catch (e) {
      debugPrint('❌ Error loading radius data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCustomMarker() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ]
      ),
      child: const Center(
        child: Icon(Icons.storefront, color: Colors.white, size: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Messes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text('Within 5km pickup radius', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
            TextButton(
              onPressed: widget.onViewMapTapped,
              child: const Text('View Map →', style: TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        GestureDetector(
          onTap: widget.onViewMapTapped,
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  AbsorbPointer(
                    absorbing: true,
                    child: OSMFlutter(
                      controller: _miniMapController,
                      onMapIsReady: _onMapReady,
                      osmOption: const OSMOption(
                        userTrackingOption: UserTrackingOption(enableTracking: true, unFollowUser: false),
                        zoomOption: ZoomOption(initZoom: 15.5, minZoomLevel: 8, maxZoomLevel: 19, stepZoom: 1.0),
                        showDefaultInfoWindow: false,
                        isPicker: false,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    Container(
                      color: Colors.white.withOpacity(0.6),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blueAccent)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (!_isLoading && _filteredMesses.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
            child: const Text('No active messes found within 5km.', style: TextStyle(color: Colors.grey)),
          ),

        if (_filteredMesses.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredMesses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final mess = _filteredMesses[index];
              final double distanceMeters = mess['distance'] ?? 0.0;
              final String distanceText = (distanceMeters / 1000).toStringAsFixed(1);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade50),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.storefront, color: Colors.blueAccent, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mess['name'] ?? 'Unknown Mess', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('$distanceText km away', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigation, color: Colors.blueAccent),
                      style: IconButton.styleFrom(backgroundColor: Colors.blue.shade50),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => OSMNavigationScreen(
                          destinationLat: double.parse(mess['latitude'].toString()),
                          destinationLng: double.parse(mess['longitude'].toString()),
                          destinationName: mess['name'],
                        )));
                      },
                    )
                  ],
                ),
              );
            },
          )
      ],
    );
  }
}