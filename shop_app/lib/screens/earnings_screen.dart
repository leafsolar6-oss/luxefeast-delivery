import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../widgets/shop_widgets.dart';
import 'order_detail_sheet.dart';

/// Earnings & history — revenue today/all-time, order stats, best sellers
/// and a filterable list of every order the shop has ever received.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int get shopId => Session.entityId > 0 ? Session.entityId : 1;

  Map<String, dynamic>? stats;
  List<Map<String, dynamic>> history = [];
  bool loading = true;
  String? error;
  String _filter = 'all';

  static const _filters = {
    'all': 'All',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
    'rejected': 'Rejected',
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        ApiService.fetchStats(shopId),
        ApiService.fetchOrderHistory(shopId, status: _filter),
      ]);
      if (!mounted) return;
      setState(() {
        stats = results[0] as Map<String, dynamic>;
        history = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();
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
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        color: LuxTheme.gold,
        backgroundColor: LuxTheme.surfaceElevated,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (loading)
              const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator(color: LuxTheme.gold)))
            else if (error != null)
              ErrorCard('Cannot reach Nature Fete servers.\nPull down to retry.')
            else ...[
              _buildRevenueCards(),
              const SizedBox(height: 16),
              _buildTopItems(),
              const SizedBox(height: 24),
              _buildHistory(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCards() {
    final s = stats!;
    final byStatus = (s['byStatus'] as Map<String, dynamic>? ?? {});
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              LuxTheme.gold.withOpacity(0.18),
              LuxTheme.surfaceElevated,
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: LuxTheme.gold.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.trending_up_rounded, color: LuxTheme.gold, size: 18),
            const SizedBox(width: 8),
            Text('REVENUE TODAY',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
          ]),
          const SizedBox(height: 8),
          Text(money(s['revenueToday']),
              style: GoogleFonts.playfairDisplay(
                  fontSize: 40, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('${s['ordersToday']} orders today · ${byStatus['delivered'] ?? 0} delivered',
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: StatTile(
                icon: Icons.account_balance_wallet_rounded,
                label: 'All-time revenue',
                value: money(s['revenueAllTime']),
                color: LuxTheme.gold)),
        const SizedBox(width: 12),
        Expanded(
            child: StatTile(
                icon: Icons.receipt_rounded,
                label: 'Orders all-time',
                value: '${s['ordersAllTime']}',
                color: LuxTheme.success)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: StatTile(
                icon: Icons.timer_outlined,
                label: 'Avg prep (told)',
                value: '${s['avgPrepMinutes']} min',
                color: LuxTheme.goldLight)),
        const SizedBox(width: 12),
        Expanded(
            child: StatTile(
                icon: Icons.timer_rounded,
                label: 'Avg prep (actual)',
                value: '${s['avgActualPrepMinutes']} min',
                color: LuxTheme.success)),
      ]),
    ]);
  }

  Widget _buildTopItems() {
    final top = (stats!['topItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (top.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: LuxTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LuxTheme.gold.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: LuxTheme.gold, size: 18),
          const SizedBox(width: 8),
          Text('BEST SELLERS',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
        ]),
        const SizedBox(height: 14),
        ...top.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                  width: 22,
                  child: Text('${e.key + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: LuxTheme.textSecondary)),
                ),
                Expanded(
                    child: Text(e.value['name'] as String? ?? '',
                        style: const TextStyle(
                            color: LuxTheme.textPrimary, fontSize: 13))),
                Text('${e.value['quantity']} sold',
                    style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
              ]),
            )),
      ]),
    );
  }

  Widget _buildHistory() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Order history'),
      const SizedBox(height: 12),
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final key = _filters.keys.elementAt(i);
            final selected = _filter == key;
            return ChoiceChip(
              label: Text(_filters[key]!),
              selected: selected,
              onSelected: (_) {
                setState(() => _filter = key);
                _refresh();
              },
              backgroundColor: LuxTheme.surfaceElevated,
              selectedColor: LuxTheme.gold,
              labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? LuxTheme.deepBlack : LuxTheme.textPrimary),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      if (history.isEmpty)
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
          child: Center(
              child: Text('No ${_filters[_filter]!.toLowerCase()} orders yet.',
                  style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13))),
        )
      else
        ...history.map(_buildHistoryRow),
    ]);
  }

  Widget _buildHistoryRow(Map<String, dynamic> o) {
    return GestureDetector(
      onTap: () => showOrderDetailSheet(context, o['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LuxTheme.gold.withOpacity(0.08))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${o['code']} · ${o['customer_name'] ?? 'Customer'}',
                  style: const TextStyle(
                      color: LuxTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(shortDate('${o['placed_at']}'),
                  style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 11)),
            ]),
          ),
          Text(money(o['total']),
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
          const SizedBox(width: 12),
          StatusChip(status: o['status'] as String),
        ]),
      ),
    );
  }
}
