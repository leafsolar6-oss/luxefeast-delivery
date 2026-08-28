import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../services/push_service.dart';
import '../services/popup_notifier.dart';
import '../main.dart';
import '../services/socket_service.dart';

/// Live rider dashboard — dispatch offers, the atomic claim race,
/// the pickup→deliver workflow, and real ₦ earnings.
class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  int get riderId => Session.entityId > 0 ? Session.entityId : 1;

  int tab = 0;
  List<Map<String, dynamic>> offers = [];
  List<Map<String, dynamic>> active = [];
  Map<String, dynamic>? earnings;
  bool loading = true;
  String? error;
  StreamSubscription<Position>? _gpsSub;
  bool _gpsOn = false;

  @override
  void initState() {
    super.initState();
    _connectRealtime();
    _refresh();
  }

  void _connectRealtime() {
    SocketService.connect(riderId: riderId);

    // Delivery offer = money on the table → pop-up with one-tap Claim.
    SocketService.onDeliveryOffer((data) {
      final order = data['order'] as Map<String, dynamic>?;
      final fee = order?['delivery_fee'];
      PopupNotifier.banner(
        title: 'New delivery offer 🛵',
        message:
            '${data['message'] ?? 'Pickup at ${order?['shop_name'] ?? 'the shop'}'}${fee != null ? ' — earn ₦$fee' : ''}',
        icon: Icons.local_shipping_rounded,
        color: LuxTheme.primary,
        sound: true,
        duration: const Duration(seconds: 9),
        actionLabel: 'Claim',
        onAction: () => _claimOffer(order?['id']),
      );
      _refresh();
    });

    SocketService.onDeliveryTaken((data) {
      PopupNotifier.banner(
          title: 'Offer taken',
          message: 'Another rider claimed it — next one is yours.',
          icon: Icons.block_rounded,
          color: LuxTheme.textSecondary);
      _refresh();
    });
    SocketService.onAssignedConfirmed((data) {
      PopupNotifier.banner(
          title: 'You got it! ✅',
          message: '${data['message'] ?? 'Delivery assigned to you'}',
          icon: Icons.check_circle_rounded,
          color: LuxTheme.success);
      _refresh();
    });
    SocketService.onOrderReady((data) {
      PopupNotifier.banner(
          title: 'Ready for pickup 🍲',
          message: '${data['message'] ?? 'Order ready for pickup!'}',
          icon: Icons.restaurant_rounded,
          color: LuxTheme.primary,
          sound: true);
      _refresh();
    });
    SocketService.onOrderDelivered((data) {
      final payout = data['riderPayout'];
      PopupNotifier.banner(
          title: 'Payout 💰',
          message:
              '${payout != null ? 'Earned ₦$payout — ' : ''}${data['message'] ?? 'Delivered!'}',
          icon: Icons.payments_rounded,
          color: LuxTheme.success,
          sound: true);
      _refresh();
    });
    SocketService.onOrderCancelled((data) {
      PopupNotifier.banner(
          title: 'Order cancelled',
          message: '${data['message'] ?? 'Order cancelled'}',
          icon: Icons.cancel_rounded,
          color: LuxTheme.error);
      _refresh();
    });
  }

  Future<void> _claimOffer(dynamic orderId) async {
    if (orderId == null) return;
    try {
      await ApiService.claim(orderId, riderId);
      PopupNotifier.banner(
          title: 'Claimed! 🎉',
          message: 'Head to the shop for pickup.',
          icon: Icons.check_circle_rounded,
          color: LuxTheme.success);
    } catch (e) {
      PopupNotifier.banner(
          title: 'Too slow 😅',
          message: e.toString().replaceAll('Exception: ', ''),
          icon: Icons.timer_off_rounded,
          color: LuxTheme.error);
    }
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        ApiService.availableDeliveries(),
        ApiService.myActiveOrders(riderId),
        ApiService.earnings(riderId),
      ]);
      if (!mounted) return;
      setState(() {
        offers = (results[0] as List).cast<Map<String, dynamic>>();
        active = (results[1] as List).cast<Map<String, dynamic>>();
        earnings = results[2] as Map<String, dynamic>;
        loading = false;
        error = null;
      });
      _syncGpsStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  /// Stream real GPS to the customer's live map while a delivery is active.
  Future<void> _syncGpsStream() async {
    final inDelivery = active.any((o) =>
        ['picked_up', 'in_transit', 'arrived', 'ready_for_pickup', 'accepted', 'preparing']
            .contains(o['status']));
    if (!inDelivery) {
      await _gpsSub?.cancel();
      _gpsSub = null;
      if (_gpsOn && mounted) setState(() => _gpsOn = false);
      return;
    }
    if (_gpsSub != null) return; // already streaming

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _toast('📍 Enable location so customers can track you live');
      return;
    }

    _gpsSub = Geolocator.getPositionStream(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen((pos) {
      for (final o in active) {
        SocketService.sendLocation(
            orderId: o['id'], riderId: riderId, lat: pos.latitude, lng: pos.longitude);
      }
    });
    if (mounted) setState(() => _gpsOn = true);
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: LuxTheme.surfaceElevated,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _act(Future<Map<String, dynamic>> Function() action, String successMsg) async {
    try {
      await action();
      _toast(successMsg);
      await _refresh();
    } catch (e) {
      _toast('⚠️ ${e.toString().replaceAll('Exception: ', '')}');
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(
        title: Text('Nature Fete Rider',
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
              Text(_gpsOn ? 'GPS LIVE' : 'ONLINE',
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.bold, color: LuxTheme.success)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: LuxTheme.textSecondary),
            onPressed: () async {
              await PushService.unregister();
              await Session.clear();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthGate()), (r) => false);
              }
            },
          ),
        ],
      ),
      body: Column(children: [
        _buildHeader(),
        _buildTabs(),
        Expanded(
          child: RefreshIndicator(
            color: LuxTheme.gold,
            backgroundColor: LuxTheme.surfaceElevated,
            onRefresh: _refresh,
            child: loading
                ? const Center(child: CircularProgressIndicator(color: LuxTheme.gold))
                : tab == 0
                    ? _buildDeliveriesTab()
                    : _buildEarningsTab(),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    final total = earnings?['total_earnings'] ?? '0';
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [LuxTheme.surfaceElevated, LuxTheme.surface]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxTheme.gold.withOpacity(0.15)),
      ),
      child: Row(children: [
        const CircleAvatar(
            radius: 24,
            backgroundColor: LuxTheme.gold,
            child: Icon(Icons.sports_motorsports_rounded, color: LuxTheme.deepBlack)),
        const SizedBox(width: 16),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Session.name.isNotEmpty ? Session.name : 'Rider',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 16, color: LuxTheme.textPrimary)),
          Text('Motorcycle • Lagos',
              style: GoogleFonts.inter(fontSize: 12, color: LuxTheme.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₦$total',
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
          Text('total earned',
              style: GoogleFonts.inter(fontSize: 11, color: LuxTheme.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _buildTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: Row(children: [
          _TabButton(label: 'Deliveries', selected: tab == 0, onTap: () => setState(() => tab = 0)),
          const SizedBox(width: 12),
          _TabButton(label: 'Earnings', selected: tab == 1, onTap: () => setState(() => tab = 1)),
        ]),
      );

  // ─────────────────────────────────────────────── deliveries tab ──

  Widget _buildDeliveriesTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        if (error != null) _errorCard(),
        if (active.isNotEmpty) ...[
          _sectionTitle('My Active Delivery'),
          ...active.map(_activeCard),
          const SizedBox(height: 16),
        ],
        _sectionTitle('Available for Pickup'),
        if (offers.isEmpty)
          _emptyCard('No open deliveries right now.\nNew offers appear here instantly — stay online!')
        else
          ...offers.map(_offerCard),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 8),
        child: Text(t,
            style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
      );

  Widget _offerCard(Map<String, dynamic> o) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: LuxTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LuxTheme.gold.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _chip(o['code'] ?? '#${o['id']}'),
            const Spacer(),
            Text('earn ₦${o['delivery_fee']}',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: LuxTheme.gold, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          _iconLine(Icons.storefront_rounded, '${o['shop_name']} — ${o['shop_address']}'),
          const SizedBox(height: 4),
          _iconLine(Icons.location_on_rounded, '${o['delivery_address']}'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _act(() => ApiService.claim(o['id'], riderId), '✅ Delivery claimed — head to the shop!'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: LuxTheme.gold, foregroundColor: LuxTheme.deepBlack),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('CLAIM DELIVERY', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );

  /// The rider's single next action for the active delivery, per lifecycle stage.
  (String, IconData, Future<Map<String, dynamic>> Function())? _nextAction(Map<String, dynamic> o) {
    final status = o['status'] as String;
    final atShop = o['rider_at_shop_at'] != null;
    switch (status) {
      case 'accepted':
      case 'preparing':
        return atShop
            ? null // waiting for kitchen
            : ('ARRIVED AT SHOP', Icons.storefront_rounded, () => ApiService.arriveShop(o['id']));
      case 'ready_for_pickup':
        return atShop
            ? ('CONFIRM PICKUP', Icons.takeout_dining_rounded, () => ApiService.pickup(o['id'], riderId))
            : ('ARRIVED AT SHOP', Icons.storefront_rounded, () => ApiService.arriveShop(o['id']));
      case 'picked_up':
        return ('START DELIVERY', Icons.navigation_rounded, () => ApiService.startTransit(o['id']));
      case 'in_transit':
        return ('ARRIVED AT CUSTOMER', Icons.location_on_rounded, () => ApiService.arriveCustomer(o['id']));
      case 'arrived':
        return ('CONFIRM DELIVERED', Icons.check_circle_rounded, () => ApiService.deliver(o['id']));
      default:
        return null;
    }
  }

  Widget _activeCard(Map<String, dynamic> o) {
    final action = _nextAction(o);
    final waiting = action == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [LuxTheme.surfaceElevated, LuxTheme.surface]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxTheme.gold.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _chip(o['code'] ?? '#${o['id']}'),
          const Spacer(),
          _statusChip(o['status'] as String),
        ]),
        const SizedBox(height: 10),
        _iconLine(Icons.storefront_rounded, '${o['shop_name'] ?? ''}'),
        const SizedBox(height: 4),
        _iconLine(Icons.person_rounded, '${o['customer_name'] ?? 'Customer'} — ${o['delivery_address'] ?? ''}'),
        const SizedBox(height: 4),
        _iconLine(Icons.payments_rounded, 'Delivery fee: ₦${o['delivery_fee']}'),
        const SizedBox(height: 14),
        if (waiting)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: LuxTheme.deepBlack, borderRadius: BorderRadius.circular(12)),
            child: Text('⏳ Waiting for the kitchen — you\'ll be alerted when it\'s ready',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 12)),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _act(action.$3, '✅ Updated!'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: LuxTheme.success, foregroundColor: LuxTheme.deepBlack),
              icon: Icon(action.$2, size: 18),
              label: Text(action.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }

  // ───────────────────────────────────────────────── earnings tab ──

  Widget _buildEarningsTab() {
    final payments = (earnings?['payments'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        _sectionTitle('Payment History'),
        if (payments.isEmpty)
          _emptyCard('No payouts yet.\nComplete deliveries to start earning ₦!')
        else
          ...payments.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const CircleAvatar(
                      backgroundColor: LuxTheme.success,
                      radius: 18,
                      child: Icon(Icons.payments_rounded, color: LuxTheme.deepBlack, size: 18)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Order ${p['order_code'] ?? ''}',
                        style: GoogleFonts.inter(
                            color: LuxTheme.textPrimary, fontWeight: FontWeight.w600)),
                    Text('${(p['created_at'] ?? '').toString().split('T').first} • ${p['status']}',
                        style:
                            GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 11)),
                  ])),
                  Text('+₦${p['amount']}',
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
                ]),
              )),
        const SizedBox(height: 24),
      ],
    );
  }

  // ──────────────────────────────────────────────────── helpers ──

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: LuxTheme.deepBlack,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: LuxTheme.gold.withOpacity(0.4))),
        child: Text(text,
            style: const TextStyle(color: LuxTheme.gold, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  Widget _statusChip(String status) {
    final color = status == 'ready_for_pickup'
        ? LuxTheme.success
        : (status == 'in_transit' || status == 'picked_up')
            ? LuxTheme.gold
            : LuxTheme.textSecondary;
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

  Widget _iconLine(IconData icon, String text) => Row(children: [
        Icon(icon, color: LuxTheme.textSecondary, size: 15),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 12))),
      ]);

  Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.delivery_dining_rounded, color: LuxTheme.gold, size: 36),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        ]),
      );

  Widget _errorCard() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.wifi_off_rounded, color: LuxTheme.error, size: 32),
          const SizedBox(height: 10),
          Text('Cannot reach Nature Fete servers.\nPull down to retry (first load can take a minute).',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 12)),
        ]),
      );
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? LuxTheme.gold : LuxTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? LuxTheme.deepBlack : LuxTheme.textSecondary)),
          ),
        ),
      );
}
