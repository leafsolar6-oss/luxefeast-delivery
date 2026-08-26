import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  int selectedTab = 0;

  final List<Map<String, dynamic>> notifications = [
    {'title': 'New Order Ready', 'subtitle': 'Golden Crust Bistro — Order #1042', 'time': '2 min ago', 'new': true},
    {'title': 'Delivery Confirmed', 'subtitle': 'Amara Okonkwo — Delivered', 'time': '15 min ago', 'new': false},
  ];

  final List<Map<String, dynamic>> payments = [
    {'date': '26 Aug 2026', 'amount': 1250, 'status': 'Paid'},
    {'date': '25 Aug 2026', 'amount': 980, 'status': 'Paid'},
    {'date': '24 Aug 2026', 'amount': 1420, 'status': 'Paid'},
  ];

  @override
  void initState() {
    super.initState();
    SocketService.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: LuxTheme.surfaceElevated, shape: BoxShape.circle, border: Border.all(color: LuxTheme.gold.withOpacity(0.3))),
              child: const Icon(Icons.delivery_dining_rounded, color: LuxTheme.gold, size: 22),
            ),
            const SizedBox(width: 12),
            Text('Rider Hub', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_rounded, color: LuxTheme.textPrimary)),
              Positioned(right: 10, top: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: LuxTheme.error, shape: BoxShape.circle))),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildTabs(),
          Expanded(
            child: selectedTab == 0 ? _buildNotifications() : _buildPayments(),
          ),
        ],
      ),
      floatingActionButton: selectedTab == 0 ? FloatingActionButton.extended(
        onPressed: () => _showStatusUpdateDialog(),
        backgroundColor: LuxTheme.gold,
        foregroundColor: LuxTheme.deepBlack,
        icon: const Icon(Icons.update_rounded),
        label: const Text('Update Status', style: TextStyle(fontWeight: FontWeight.w700)),
      ) : null,
    );
  }

  Widget _buildHeaderCard() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [LuxTheme.surfaceElevated, LuxTheme.surface]),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: LuxTheme.gold.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daniel Okoro', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
        const SizedBox(height: 4),
        Text('Active Rider • 142 Deliveries', style: GoogleFonts.inter(fontSize: 13, color: LuxTheme.textSecondary)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MiniStat(label: 'Today', value: '8'),
            _MiniStat(label: 'Earnings', value: '₦2,340'),
            _MiniStat(label: 'Rating', value: '4.9'),
          ],
        ),
      ],
    ),
  );

  Widget _buildTabs() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24),
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    decoration: BoxDecoration(color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        Expanded(child: _TabButton(label: 'Notifications', active: selectedTab == 0, onTap: () => setState(() => selectedTab = 0))),
        Expanded(child: _TabButton(label: 'Payment History', active: selectedTab == 1, onTap: () => setState(() => selectedTab = 1))),
      ],
    ),
  );

  Widget _buildNotifications() => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    itemCount: notifications.length,
    itemBuilder: (context, index) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: notifications[index]['new'] ? LuxTheme.gold.withOpacity(0.3) : LuxTheme.surfaceElevated.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: notifications[index]['new'] ? LuxTheme.error : LuxTheme.success, shape: BoxShape.circle)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(notifications[index]['title'] as String, style: const TextStyle(color: LuxTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Text(notifications[index]['subtitle'] as String, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
            ]),
          ),
          Text(notifications[index]['time'] as String, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 11)),
        ],
      ),
    ),
  );

  Widget _buildPayments() => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    itemCount: payments.length,
    itemBuilder: (context, index) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: LuxTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LuxTheme.gold.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: LuxTheme.deepBlack, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.account_balance_wallet_rounded, color: LuxTheme.gold)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Payment — ${payments[index]['date']}', style: const TextStyle(color: LuxTheme.textPrimary, fontWeight: FontWeight.w600)), Text('Status: ${payments[index]['status']}', style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12))])),
          Text('₦${payments[index]['amount']}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
        ],
      ),
    ),
  );

  void _showStatusUpdateDialog() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: LuxTheme.surfaceElevated,
      title: Text('Update Order Status', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w600)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: const Text('In Transit'), tileColor: LuxTheme.surface, onTap: () { Navigator.pop(context); SocketService.emitStatusUpdate('demo-order-001', 'in_transit'); }),
        ListTile(title: const Text('Delivered'), tileColor: LuxTheme.surface, onTap: () { Navigator.pop(context); SocketService.emitStatusUpdate('demo-order-001', 'delivered'); }),
      ]),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label; final String value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: LuxTheme.textPrimary)), Text(label, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 10))]);
}

class _TabButton extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? LuxTheme.deepBlack : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: LuxTheme.gold, width: 1) : null,
      ),
      child: Center(child: Text(label, style: TextStyle(color: active ? LuxTheme.gold : LuxTheme.textSecondary, fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 13))),
    ),
  );
}
