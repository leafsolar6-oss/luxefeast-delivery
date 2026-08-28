import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/shop_widgets.dart';

/// Full order detail: items, fees, customer, rider and the complete
/// event timeline (fetched live from /api/orders/:id).
Future<void> showOrderDetailSheet(BuildContext context, dynamic orderId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: LuxTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _OrderDetailSheet(orderId: orderId),
  );
}

class _OrderDetailSheet extends StatefulWidget {
  final dynamic orderId;
  const _OrderDetailSheet({required this.orderId});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  Map<String, dynamic>? order;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.fetchOrderDetail(widget.orderId);
      if (mounted) setState(() => order = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.82;
    return SizedBox(
      height: h,
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 44, height: 4,
            decoration: BoxDecoration(
                color: LuxTheme.textSecondary.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        if (error != null)
          Expanded(child: Center(child: ErrorCard(error!)))
        else if (order == null)
          const Expanded(
              child: Center(child: CircularProgressIndicator(color: LuxTheme.gold)))
        else
          Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    final o = order!;
    final items = (o['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final events = (o['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final riderName = o['rider_name'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Row(children: [
          Text('Order ${o['code'] ?? o['id']}',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 22, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
          const Spacer(),
          StatusChip(status: o['status'] as String),
        ]),
        const SizedBox(height: 16),

        _section('Items', Icons.restaurant_rounded, [
          ...items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text('${i['quantity'] ?? 1}×',
                      style: const TextStyle(
                          color: LuxTheme.gold, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('${i['name']}',
                          style: const TextStyle(
                              color: LuxTheme.textPrimary, fontSize: 14))),
                  Text(money((double.tryParse('${i['price']}') ?? 0) *
                      ((i['quantity'] as num?)?.toDouble() ?? 1)),
                      style: const TextStyle(
                          color: LuxTheme.textSecondary, fontSize: 13)),
                ]),
              )),
          const Divider(color: LuxTheme.gold, height: 24, thickness: 0.2),
          _feeRow('Subtotal', o['subtotal']),
          _feeRow('Delivery fee', o['delivery_fee']),
          _feeRow('Service fee', o['service_fee']),
          const SizedBox(height: 6),
          Row(children: [
            const Spacer(),
            Text('Total  ${money(o['total'])}',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
          ]),
        ]),
        const SizedBox(height: 16),

        _section('Customer', Icons.person_rounded, [
          _infoRow(o['customer_name'] ?? 'Customer', o['customer_phone'] ?? ''),
          if (o['delivery_address'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on_outlined,
                    color: LuxTheme.textSecondary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('${o['delivery_address']}',
                        style: const TextStyle(
                            color: LuxTheme.textSecondary, fontSize: 12))),
              ]),
            ),
        ]),
        if (riderName != null) ...[
          const SizedBox(height: 16),
          _section('Rider', Icons.sports_motorsports_rounded, [
            _infoRow('$riderName · ${o['rider_vehicle'] ?? '—'}'
                '${o['rider_rating'] != null ? '  ⭐ ${o['rider_rating']}' : ''}',
                o['rider_phone'] ?? ''),
          ]),
        ],
        const SizedBox(height: 16),

        _section('Timeline', Icons.timeline_rounded,
            events.reversed.map((e) => _timelineRow(e)).toList()),
      ],
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LuxTheme.gold.withOpacity(0.1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: LuxTheme.gold, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Widget _feeRow(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text(label, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(money(value),
              style: const TextStyle(color: LuxTheme.textPrimary, fontSize: 13)),
        ]),
      );

  Widget _infoRow(String line1, String line2) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line1,
                style: const TextStyle(
                    color: LuxTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            if (line2.isNotEmpty)
              Text(line2,
                  style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
          ]);

  Widget _timelineRow(Map<String, dynamic> e) {
    final note = e['note'] as String? ?? '';
    final event = (e['event'] as String? ?? '').replaceAll('_', ' ');
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 20,
          child: Column(children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: LuxTheme.gold.withOpacity(0.8))),
            Expanded(
                child: Container(width: 1.5, color: LuxTheme.gold.withOpacity(0.2))),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.toUpperCase(),
                  style: const TextStyle(
                      color: LuxTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              if (note.isNotEmpty)
                Text(note,
                    style:
                        const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
              Text(shortDate('${e['created_at']}'),
                  style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 10)),
            ]),
          ),
        ),
      ]),
    );
  }
}
