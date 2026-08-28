import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

/// Live order tracking — every stage updates in real time as the shop
/// and rider act, exactly like the international delivery platforms.
class OrderTrackingScreen extends StatefulWidget {
  final dynamic orderId;
  final Map<String, dynamic>? initialOrder;
  const OrderTrackingScreen({super.key, required this.orderId, this.initialOrder});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Map<String, dynamic>? order;
  String status = 'placed';
  String? riderName;
  String? riderPhone;
  String? lastMessage;

  static const List<String> steps = [
    'placed', 'accepted', 'preparing', 'ready_for_pickup',
    'picked_up', 'in_transit', 'arrived', 'delivered',
  ];
  static const List<String> labels = [
    'Order Placed', 'Restaurant Confirmed', 'Preparing Your Food', 'Ready for Pickup',
    'Rider Picked Up', 'On the Way', 'Rider Arrived', 'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    order = widget.initialOrder;
    status = order?['status'] ?? 'placed';
    riderName = order?['rider_name'];
    _listen();
    _refresh();
  }

  void _listen() {
    SocketService.joinOrder(widget.orderId);

    void update(dynamic data, {String? overrideStatus}) {
      if (!mounted) return;
      final o = data['order'];
      setState(() {
        if (o != null && '${o['id']}' == '${widget.orderId}') {
          status = overrideStatus ?? o['status'] ?? status;
          riderName = o['rider_name'] ?? riderName;
          riderPhone = o['rider_phone'] ?? riderPhone;
        }
        lastMessage = data['message'] ?? lastMessage;
      });
    }

    SocketService.onOrderAccepted(update);
    SocketService.onOrderRejected(update);
    SocketService.onOrderPreparing(update);
    SocketService.onOrderReady(update);
    SocketService.onRiderAssigned(update);
    SocketService.onRiderAtShop(update);
    SocketService.onOrderPickedUp(update);
    SocketService.onOrderInTransit(update);
    SocketService.onOrderArrived(update);
    SocketService.onOrderDelivered(update);
    SocketService.onOrderCancelled(update);
  }

  Future<void> _refresh() async {
    try {
      final data = await ApiService.fetchOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        order = data;
        status = data['status'] ?? status;
        riderName = data['rider_name'] ?? riderName;
        riderPhone = data['rider_phone'] ?? riderPhone;
      });
    } catch (_) {}
  }

  int get currentStep {
    final i = steps.indexOf(status);
    return i < 0 ? 0 : i;
  }

  bool get isTerminatedEarly => status == 'cancelled' || status == 'rejected';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(
        title: Text(order?['code'] ?? 'Live Tracking'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: LuxTheme.gold,
        backgroundColor: LuxTheme.surfaceElevated,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 24),
            if (isTerminatedEarly)
              _buildTerminated()
            else
              ...List.generate(
                  steps.length,
                  (index) => _StepItem(
                        index: index,
                        label: labels[index],
                        isActive: index <= currentStep,
                        isCurrent: index == currentStep,
                      )),
            const SizedBox(height: 24),
            if (riderName != null) _buildRiderCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final headline = isTerminatedEarly
        ? (status == 'rejected' ? 'Order Rejected' : 'Order Cancelled')
        : labels[currentStep];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [LuxTheme.surfaceElevated, LuxTheme.surface]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LuxTheme.gold.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: LuxTheme.deepBlack,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LuxTheme.gold.withOpacity(0.4))),
            child: Text(order?['shop_name'] ?? 'LuxFeast',
                style: const TextStyle(
                    color: LuxTheme.gold, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
          const Spacer(),
          if (order?['total'] != null)
            Text('₦${order?['total']}',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        Text(headline,
            style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isTerminatedEarly ? LuxTheme.error : LuxTheme.gold)),
        if (lastMessage != null) ...[
          const SizedBox(height: 8),
          Text(lastMessage!,
              style: GoogleFonts.inter(fontSize: 13, color: LuxTheme.textSecondary)),
        ],
      ]),
    );
  }

  Widget _buildTerminated() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.cancel_rounded, color: LuxTheme.error, size: 40),
          const SizedBox(height: 12),
          Text('A full refund has been initiated to your payment method.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        ]),
      );

  Widget _buildRiderCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LuxTheme.gold.withOpacity(0.15))),
        child: Row(children: [
          const CircleAvatar(
              backgroundColor: LuxTheme.gold,
              child: Icon(Icons.motorcycle_rounded, color: LuxTheme.deepBlack, size: 20)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your Rider',
                style: TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
            Text(riderName!,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
            if (riderPhone != null)
              Text(riderPhone!,
                  style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 11)),
          ])),
          const Icon(Icons.verified_rounded, color: LuxTheme.gold),
        ]),
      );
}

class _StepItem extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;
  final bool isCurrent;
  const _StepItem(
      {required this.index,
      required this.label,
      required this.isActive,
      required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? LuxTheme.gold : LuxTheme.textSecondary.withOpacity(0.3);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Column(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? LuxTheme.gold : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
            child: isActive
                ? Icon(isCurrent ? Icons.radio_button_checked : Icons.check_rounded,
                    size: 16, color: LuxTheme.deepBlack)
                : null,
          ),
          if (index < 7)
            Container(width: 2, height: 26, color: color.withOpacity(isActive ? 0.6 : 0.25)),
        ]),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? LuxTheme.textPrimary : LuxTheme.textSecondary)),
        ),
      ]),
    );
  }
}
