import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import 'order_tracking_screen.dart';
import 'auth_screen.dart';

/// Chowdeck-style order history — every order with live status, tap to track.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    if (Session.isLoggedIn) _load();
  }

  Future<void> _load() async {
    if (!Session.isLoggedIn) return;
    try {
      final data = await ApiService.fetchMyOrders(Session.userId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.bg,
      appBar: AppBar(
        backgroundColor: LuxTheme.primary,
        title: Text('My Orders',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
        ],
      ),
      body: !Session.isLoggedIn
          ? _signInPrompt()
          : loading
              ? const Center(child: CircularProgressIndicator(color: LuxTheme.primary))
              : error != null
                  ? _centered(Column(children: [
                      const Icon(Icons.wifi_off_rounded, color: LuxTheme.error, size: 40),
                      const SizedBox(height: 12),
                      Text('Could not load your orders.\nPull down to retry.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              color: LuxTheme.textSecondary, fontSize: 13)),
                    ]))
                  : RefreshIndicator(
                      color: LuxTheme.primary,
                      onRefresh: _load,
                      child: orders.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 140),
                              Center(
                                  child: Text('No orders yet — your first parfait awaits 🥣',
                                      style: TextStyle(color: LuxTheme.textSecondary)))
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: orders.length,
                              itemBuilder: (ctx, i) => _orderCard(orders[i]),
                            ),
                    ),
    );
  }

  Widget _centered(Widget child) => Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: child,
      ));

  Widget _signInPrompt() => _centered(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_rounded, color: LuxTheme.primary, size: 44),
          const SizedBox(height: 12),
          Text('Sign in to see your orders',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
          const SizedBox(height: 6),
          Text('Your order history and live tracking live here.',
              style: GoogleFonts.inter(fontSize: 13, color: LuxTheme.textSecondary)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (ctx) => AuthScreen(
                role: 'customer',
                title: 'Sign in to see your orders',
                onAuthed: () => Navigator.of(ctx).pop(true),
              ),
            )).then((ok) {
              if (ok == true) {
                setState(() { loading = true; });
                _load();
              }
            }),
            child: const Text('Sign in'),
          ),
        ],
      ));

  Widget _orderCard(Map<String, dynamic> o) {
    final status = '${o['status']}';
    final total = double.tryParse('${o['total']}') ?? 0;
    final items = (o['items'] as List<dynamic>? ?? []);
    final placed = DateTime.tryParse('${o['placed_at']}')?.toLocal();
    final dateStr = placed == null
        ? ''
        : '${placed.day}/${placed.month} · ${placed.hour.toString().padLeft(2, '0')}:${placed.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              OrderTrackingScreen(orderId: o['id'], initialOrder: o))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LuxTheme.surface),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${o['code']}',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w800, color: LuxTheme.textPrimary)),
            const Spacer(),
            _statusChip(status),
          ]),
          const SizedBox(height: 8),
          Text(
              items.map((i) => '${i['name']} ×${i['quantity'] ?? 1}').join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12.5, color: LuxTheme.textSecondary)),
          const SizedBox(height: 10),
          Row(children: [
            Text(dateStr,
                style: GoogleFonts.inter(fontSize: 11, color: LuxTheme.textSecondary)),
            const Spacer(),
            Text('₦${total % 1 == 0 ? total.toInt() : total.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w800, color: LuxTheme.primary)),
          ]),
        ]),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'placed' => ('NEW', LuxTheme.amber),
      'delivered' => ('DELIVERED', LuxTheme.primary),
      'cancelled' || 'rejected' => (status.toUpperCase(), LuxTheme.error),
      _ => (status.replaceAll('_', ' ').toUpperCase(), LuxTheme.primaryLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
