import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../main.dart';
import '../widgets/shop_widgets.dart';
import 'order_detail_sheet.dart';

/// Live shop dashboard — real orders from the LuxFeast backend with
/// real-time alerts for every lifecycle event that concerns the shop.
class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key});

  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  int get shopId => Session.entityId > 0 ? Session.entityId : 1;

  List<Map<String, dynamic>> orders = [];
  Map<String, dynamic>? shop;
  bool loading = true;
  String? error;
  int deliveredToday = 0;
  int defaultPrepMinutes = 20;

  @override
  void initState() {
    super.initState();
    _connectRealtime();
    _refresh();
    _loadShop();
  }

  void _connectRealtime() {
    SocketService.connect(shopId: shopId);
    SocketService.onNewOrder((data) {
      _alertNewOrder();
      _refresh();
    });
    SocketService.onRiderAssigned((data) {
      shopToast(context, '🏍️ ${data['message'] ?? 'A rider was assigned'}');
      _refresh();
    });
    SocketService.onRiderAtShop((data) {
      shopToast(context, '📍 ${data['message'] ?? 'Rider is at your shop'}');
      _refresh();
    });
    SocketService.onOrderPickedUp((data) {
      shopToast(context, '📦 ${data['message'] ?? 'Order picked up'}');
      _refresh();
    });
    SocketService.onOrderDelivered((data) {
      shopToast(context, '✅ ${data['message'] ?? 'Order delivered'}');
      setState(() => deliveredToday++);
      _refresh();
    });
    SocketService.onOrderCancelled((data) {
      shopToast(context, '❌ ${data['message'] ?? 'Order cancelled'}');
      _refresh();
    });
  }

  /// New order = full attention: sound + vibration + banner.
  void _alertNewOrder() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.mediumImpact());
    shopToast(context, '🔔 NEW ORDER — turn up the heat!');
  }

  Future<void> _loadShop() async {
    try {
      final s = await ApiService.fetchShop(shopId);
      if (!mounted) return;
      setState(() {
        shop = s;
        defaultPrepMinutes = (s['avg_prep_minutes'] as num?)?.toInt() ?? 20;
      });
    } catch (_) {/* banner simply stays hidden */}
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
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _act(Future<Map<String, dynamic>> Function() action) async {
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) shopToast(context, '⚠️ ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// Accept flow — ask the kitchen for a realistic prep estimate.
  Future<void> _acceptFlow(Map<String, dynamic> o) async {
    var prep = defaultPrepMinutes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: LuxTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Accept ${o['code']}?',
              style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Tell the customer how long the kitchen needs:',
                style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            Text('$prep min',
                style: GoogleFonts.inter(
                    fontSize: 34, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
            Slider(
              value: prep.toDouble(),
              min: 5, max: 90, divisions: 17,
              activeColor: LuxTheme.gold,
              label: '$prep min',
              onChanged: (v) => setDialog(() => prep = v.round()),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: LuxTheme.textSecondary))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _act(() => ApiService.acceptOrder(o['id'], prepMinutes: prep));
    }
  }

  Future<void> _rejectFlow(Map<String, dynamic> o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LuxTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Reject ${o['code']}?',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
        content: Text('The customer will be told the order cannot be fulfilled and refunded.',
            style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep order', style: TextStyle(color: LuxTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject', style: TextStyle(color: LuxTheme.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await _act(() => ApiService.rejectOrder(o['id']));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(
        title: Text(
            (shop?['name'] as String?) ??
                (Session.name.isNotEmpty ? Session.name : 'My Restaurant'),
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
            if (shop != null && shop!['is_open'] == false) ...[
              _buildClosedBanner(),
              const SizedBox(height: 16),
            ],
            _buildSummaryCards(),
            const SizedBox(height: 24),
            const SectionTitle('Active Orders'),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: LuxTheme.gold)),
              )
            else if (error != null)
              ErrorCard('Cannot reach LuxFeast servers.\nPull down to retry.')
            else if (orders.isEmpty)
              _buildEmpty()
            else
              ...orders.map(_buildOrderCard),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: LuxTheme.error.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LuxTheme.error.withOpacity(0.4))),
        child: Row(children: [
          const Icon(Icons.storefront_rounded, color: LuxTheme.error),
          const SizedBox(width: 12),
          Expanded(
              child: Text('You are CLOSED — customers cannot see your shop.',
                  style: GoogleFonts.inter(fontSize: 13, color: LuxTheme.textPrimary))),
          TextButton(
              onPressed: () async {
                try {
                  await ApiService.updateShop(shopId, {'isOpen': true});
                  await _loadShop();
                  if (mounted) shopToast(context, '🟢 You are open for orders');
                } catch (e) {
                  if (mounted) shopToast(context, '⚠️ ${e.toString().replaceAll('Exception: ', '')}');
                }
              },
              child: const Text('Reopen', style: TextStyle(color: LuxTheme.gold))),
        ]),
      );

  Widget _buildSummaryCards() => Row(children: [
        Expanded(
            child: StatTile(
                icon: Icons.restaurant_rounded,
                label: 'Active',
                value: '${orders.length}',
                color: LuxTheme.gold)),
        const SizedBox(width: 12),
        Expanded(
            child: StatTile(
                icon: Icons.check_circle_rounded,
                label: 'Delivered (session)',
                value: '$deliveredToday',
                color: LuxTheme.success)),
      ]);

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
          _actionBtn('Reject', LuxTheme.error, () => _rejectFlow(o)),
          const SizedBox(width: 8),
          _actionBtn('Accept', LuxTheme.gold, () => _acceptFlow(o)),
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
    final items = (o['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final riderName = o['rider_name'];
    final isNew = o['status'] == 'placed';
    return GestureDetector(
      onTap: () => showOrderDetailSheet(context, o['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: LuxTheme.surfaceElevated,
          border: Border.all(
              color: isNew ? LuxTheme.error.withOpacity(0.5) : LuxTheme.gold.withOpacity(0.1),
              width: isNew ? 1.5 : 1),
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
            if (isNew) ...[
              const SizedBox(width: 8),
              const Icon(Icons.notifications_active_rounded, color: LuxTheme.error, size: 16),
            ],
            const Spacer(),
            Text(money(o['total']),
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Text(o['customer_name'] ?? 'Customer',
              style: const TextStyle(
                  color: LuxTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          if (o['customer_phone'] != null)
            Text(o['customer_phone'] as String,
                style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          // Itemized — the kitchen needs to see exactly what to cook.
          ...items.take(4).map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  Text('${i['quantity'] ?? 1}×',
                      style: const TextStyle(
                          color: LuxTheme.gold, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('${i['name']}',
                          style: const TextStyle(color: LuxTheme.textPrimary, fontSize: 13))),
                  Text(money(i['price']),
                      style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
                ]),
              )),
          if (items.length > 4)
            Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('+ ${items.length - 4} more items — tap for details',
                    style: const TextStyle(
                        color: LuxTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic))),
          if (riderName != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.sports_motorsports_rounded, color: LuxTheme.gold, size: 16),
              const SizedBox(width: 6),
              Text('Rider: $riderName (${o['rider_vehicle'] ?? '—'})',
                  style: const TextStyle(
                      color: LuxTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ],
          const SizedBox(height: 16),
          Row(children: [
            StatusChip(status: o['status'] as String),
            const Spacer(),
            ..._actionsFor(o),
          ]),
        ]),
      ),
    );
  }
}
