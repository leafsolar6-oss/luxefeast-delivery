import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
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
  LatLng? riderPos;
  final MapController _map = MapController();

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

    SocketService.onRiderLocation((data) {
      if (!mounted || '${data['orderId']}' != '${widget.orderId}') return;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      setState(() => riderPos = LatLng(lat, lng));
      try { _map.move(LatLng(lat, lng), 14); } catch (_) {}
    });
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
        final rl = (data['rider_lat'] as num?)?.toDouble();
        final rg = (data['rider_lng'] as num?)?.toDouble();
        if (rl != null && rg != null) riderPos = LatLng(rl, rg);
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
            const SizedBox(height: 16),
            _buildLiveMap(),
            const SizedBox(height: 20),
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

  LatLng? get _shopPos {
    final lat = (order?['shop_lat'] as num?)?.toDouble();
    final lng = (order?['shop_lng'] as num?)?.toDouble();
    return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  }

  LatLng? get _dropoffPos {
    final lat = (order?['dropoff_lat'] as num?)?.toDouble();
    final lng = (order?['dropoff_lng'] as num?)?.toDouble();
    return (lat != null && lng != null) ? LatLng(lat, lng) : null;
  }

  Widget _buildLiveMap() {
    final center = riderPos ?? _shopPos ?? _dropoffPos ?? const LatLng(6.4531, 3.4470);
    final markers = <Marker>[
      if (_shopPos != null)
        Marker(point: _shopPos!, width: 44, height: 44,
            child: _pin(Icons.storefront_rounded, LuxTheme.gold)),
      if (_dropoffPos != null)
        Marker(point: _dropoffPos!, width: 44, height: 44,
            child: _pin(Icons.home_rounded, LuxTheme.success)),
      if (riderPos != null)
        Marker(point: riderPos!, width: 48, height: 48,
            child: _pin(Icons.sports_motorsports_rounded, LuxTheme.error)),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 230,
        child: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.luxefeast.luxefeast_customer',
              ),
              if (_shopPos != null && _dropoffPos != null)
                PolylineLayer(polylines: [
                  Polyline(
                      points: [_shopPos!, if (riderPos != null) riderPos!, _dropoffPos!],
                      strokeWidth: 3,
                      color: LuxTheme.gold.withOpacity(0.7)),
                ]),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            top: 10, left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: LuxTheme.deepBlack.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle,
                    color: riderPos != null ? LuxTheme.success : LuxTheme.textSecondary, size: 8),
                const SizedBox(width: 6),
                Text(riderPos != null ? 'LIVE — rider on map' : 'Waiting for rider GPS…',
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pin(IconData icon, Color color) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: LuxTheme.deepBlack,
          border: Border.all(color: color, width: 2.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)],
        ),
        child: Icon(icon, color: color, size: 22),
      );

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
