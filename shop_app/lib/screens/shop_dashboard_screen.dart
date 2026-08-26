import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';

class ShopDashboardScreen extends StatefulWidget {
  const ShopDashboardScreen({super.key});

  @override
  State<ShopDashboardScreen> createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  final List<Map<String, dynamic>> orders = [
    {'id': '#1042', 'customer': 'Amara Okonkwo', 'items': 'Truffle Pasta x1', 'status': 'preparing', 'amount': 28.5},
    {'id': '#1041', 'customer': 'Chidi Nwankwo', 'items': 'Wagyu Burger x2', 'status': 'ready', 'amount': 62.0},
    {'id': '#1040', 'customer': 'Ngozi Adebayo', 'items': 'Sushi Platter x1', 'status': 'pending', 'amount': 45.0},
  ];

  @override
  void initState() {
    super.initState();
    SocketService.connect();
  }

  void _updateStatus(int index, String newStatus) {
    setState(() => orders[index]['status'] = newStatus);
    SocketService.emitStatusUpdate('demo-order-${orders[index]['id'].replaceAll('#', '')}', newStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(
        title: Text('Golden Crust Bistro', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Icon(Icons.access_time_filled_rounded, color: LuxTheme.gold, size: 16),
                const SizedBox(width: 4),
                Text('Live', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: LuxTheme.success)),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 24),
          Text('Active Orders', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
          const SizedBox(height: 16),
          ...orders.asMap().entries.map((entry) => _buildOrderCard(entry.key, entry.value)).toList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() => Row(
    children: [
      Expanded(child: _SummaryTile(icon: Icons.restaurant_rounded, label: 'Today', value: '142', color: LuxTheme.gold)),
      const SizedBox(width: 12),
      Expanded(child: _SummaryTile(icon: Icons.check_circle_rounded, label: 'Completed', value: '89', color: LuxTheme.success)),
    ],
  );

  Widget _buildOrderCard(int index, Map<String, dynamic> order) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: LuxTheme.surfaceElevated,
      border: Border.all(color: LuxTheme.gold.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: LuxTheme.deepBlack, borderRadius: BorderRadius.circular(8), border: Border.all(color: LuxTheme.gold.withOpacity(0.4))),
              child: Text(order['id'] as String, style: const TextStyle(color: LuxTheme.gold, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            const Spacer(),
            Text('₦${order['amount']}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        Text(order['customer'] as String, style: const TextStyle(color: LuxTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        Text(order['items'] as String, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Row(
          children: [
            _StatusChip(status: order['status'] as String),
            const Spacer(),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () => _updateStatus(index, 'confirmed'),
                style: ElevatedButton.styleFrom(backgroundColor: LuxTheme.gold, foregroundColor: LuxTheme.deepBlack),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryTile extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _SummaryTile({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20), border: Border.all(color: LuxTheme.gold.withOpacity(0.1))),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: LuxTheme.textPrimary)),
        Text(label, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'pending' ? LuxTheme.error : status == 'ready' ? LuxTheme.success : LuxTheme.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
