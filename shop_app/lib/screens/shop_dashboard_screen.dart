import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

/// Live shop dashboard — real orders from the LuxFeast backend with
/// real-time alerts for every lifecycle event that concerns the shop.
class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key});

  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  static const int shopId = 1; // Mama Nkem Amala Palace (demo login)

  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? error;
  int deliveredToday = 0;

  @override
  void initState() {
    super.initState();
    _connectRealtime();
    _refresh();
  }

  void _connectRealtime() {
    SocketService.connect(shopId: shopId);
    SocketService.onNewOrder((data) {
      _toast('🔔 ${data['message'] ?? 'New order received!'}');
      _refresh();
    });
    SocketService.onRiderAssigned((data) {
      _toast('🏍️ ${data['message'] ?? 'A rider was assigned'}');
      _refresh();
    });
    SocketService.onRiderAtShop((data) {
      _toast('📍 ${data['message'] ?? 'Rider is at your shop'}');
      _refresh();
    });
    SocketService.onOrderPickedUp((data) {
      _toast('📦 ${data['message'] ?? 'Order picked up'}');
      _refresh();
    });
    SocketService.onOrderDelivered((data) {
      _toast('✅ ${data['message'] ?? 'Order delivered'}');
      setState(() => deliveredToday++);
      _refresh();
    });
    SocketService.onOrderCancelled((data) {
      _toast('❌ ${data['message'] ?? 'Order cancelled'}');
      _refresh();
    });
  }

  Future<void> _refresh() async {
    try {
      final data = await ApiService.fetchOpenOrders(shopId);
      if (!mounted) return;
      setState(() {
        orders = data.cast<Map<String, dynamic>>();
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: LuxTheme.surfaceElevated,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _act(Future<Map<String, dynamic>> Function() action) async {
    try {
      await action();
      await _refresh();
    } catch (e) {
      _toast('⚠️ ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(
        title: Text('Mama Nkem Amala Palace',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.circle, color: LuxTheme.success, size: 10),
              const SizedBox(width: 6),
              Text('LIVE',
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.bold, color: LuxTheme.success)),
            ]),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: LuxTheme.gold,
        backgroundColor: LuxTheme.surfaceElevated,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            _buildSummaryCards(),
            const SizedBox(height: 24),
            Text('Active Orders',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 22, fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: LuxTheme.gold)),
              )
            else if (error != null)
              _buildError()
            else if (orders.isEmpty)
              _buildEmpty()
            else
              ...orders.map(_buildOrderCard),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() => Row(children: [
        Expanded(
            child: _SummaryTile(
                icon: Icons.restaurant_rounded,
                label: 'Active',
                value: '${orders.length}',
                color: LuxTheme.gold)),
        const SizedBox(width: 12),
        Expanded(
            child: _SummaryTile(
                icon: Icons.check_circle_rounded,
                label: 'Delivered (session)',
                value: '$deliveredToday',
                color: LuxTheme.success)),
      ]);

  Widget _buildError() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.wifi_off_rounded, color: LuxTheme.error, size: 36),
          const SizedBox(height: 12),
          Text('Cannot reach LuxFeast servers.\nPull down to retry.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        ]),
      );

  Widget _buildEmpty() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.ramen_dining_rounded, color: LuxTheme.gold, size: 36),
          const SizedBox(height: 12),
          Text('No active orders yet.\nNew orders will appear here instantly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        ]),
      );

  /// The shop's action for each lifecycle stage.
  List<Widget> _actionsFor(Map<String, dynamic> o) {
    final status = o['status'] as String;
    switch (status) {
      case 'placed':
        return [
          _actionBtn('Reject', LuxTheme.error, () => _act(() => ApiService.rejectOrder(o['id']))),
          const SizedBox(width: 8),
          _actionBtn('Accept', LuxTheme.gold,
              () => _act(() => ApiService.acceptOrder(o['id'], prepMinutes: 20))),
        ];
      case 'accepted':
        return [
          _actionBtn('Start Preparing', LuxTheme.gold,
              () => _act(() => ApiService.startPreparing(o['id']))),
        ];
      case 'preparing':
        return [
          _actionBtn('Mark Ready', LuxTheme.success,
              () => _act(() => ApiService.markReady(o['id']))),
        ];
      default:
        return []; // ready_for_pickup onward — the rider drives the flow.
    }
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) => SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: LuxTheme.deepBlack),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      );

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final items = (o['items'] as List<dynamic>? ?? [])
        .map((i) => '${i['name']} x${i['quantity']}')
        .join(', ');
    final riderName = o['rider_name'];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: LuxTheme.surfaceElevated,
        border: Border.all(color: LuxTheme.gold.withOpacity(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: LuxTheme.deepBlack,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LuxTheme.gold.withOpacity(0.4))),
            child: Text(o['code'] ?? '#${o['id']}',
                style: const TextStyle(
                    color: LuxTheme.gold, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const Spacer(),
          Text('₦${o['total']}',
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
        ]),
        const SizedBox(height: 12),
        Text(o['customer_name'] ?? 'Customer',
            style: const TextStyle(
                color: LuxTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        Text(items, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 13)),
        if (riderName != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.sports_motorsports_rounded, color: LuxTheme.gold, size: 16),
            const SizedBox(width: 6),
            Text('Rider: $riderName',
                style: const TextStyle(color: LuxTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ],
        const SizedBox(height: 16),
        Row(children: [
          _StatusChip(status: o['status'] as String),
          const Spacer(),
          ..._actionsFor(o),
        ]),
      ]),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryTile(
      {required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LuxTheme.gold.withOpacity(0.1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 22, fontWeight: FontWeight.bold, color: LuxTheme.textPrimary)),
          Text(label, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'placed'
        ? LuxTheme.error
        : (status == 'ready_for_pickup' || status == 'picked_up' || status == 'in_transit')
            ? LuxTheme.success
            : LuxTheme.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Text(status.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
