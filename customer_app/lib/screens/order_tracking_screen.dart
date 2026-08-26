import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  String status = 'pending';
  String? riderName;

  final List<String> steps = ['pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'in_transit', 'delivered'];
  final List<String> labels = ['Order Placed', 'Confirmed', 'Preparing', 'Ready', 'Picked Up', 'On the Way', 'Delivered'];

  @override
  void initState() {
    super.initState();
    SocketService.connect();
    SocketService.joinOrder('demo-order-001');
    SocketService.listenStatusUpdated((data) {
      if (mounted) setState(() => status = data['status'] ?? 'pending');
    });
    SocketService.listenRiderAssigned((data) {
      if (mounted) setState(() => riderName = data['rider']?['name'] ?? 'Assigned');
    });
  }

  int get currentStep => steps.indexOf(status).clamp(0, steps.length - 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.builder(
                itemCount: steps.length,
                itemBuilder: (context, index) => _StepItem(index: index, label: labels[index], isActive: index <= currentStep, isCurrent: index == currentStep),
              ),
            ),
            const SizedBox(height: 24),
            if (riderName != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxTheme.gold.withOpacity(0.15))),
                child: Row(
                  children: [
                    const CircleAvatar(backgroundColor: LuxTheme.gold, child: Icon(Icons.motorcycle_rounded, color: LuxTheme.deepBlack, size: 20)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your Rider', style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)), Text(riderName!, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: LuxTheme.textPrimary))])),
                    IconButton(icon: const Icon(Icons.phone_rounded, color: LuxTheme.gold), onPressed: () {}),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [LuxTheme.surfaceElevated, LuxTheme.surface]),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: LuxTheme.gold.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(currentStep >= 6 ? Icons.check_circle_rounded : Icons.access_time_filled_rounded, color: currentStep >= 6 ? LuxTheme.success : LuxTheme.gold, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text('Order #001', style: GoogleFonts.inter(fontSize: 12, color: LuxTheme.textSecondary))),
          ],
        ),
        const SizedBox(height: 12),
        Text('Status: ${_capitalize(status)}', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (currentStep + 1) / steps.length,
          backgroundColor: LuxTheme.surface,
          valueColor: AlwaysStoppedAnimation<Color>(LuxTheme.gold),
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    ),
  );

  String _capitalize(String s) => s.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
}

class _StepItem extends StatelessWidget {
  final int index;
  final String label;
  final bool isActive;
  final bool isCurrent;
  const _StepItem({required this.index, required this.label, required this.isActive, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive ? LuxTheme.surfaceElevated.withOpacity(0.5) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent ? Border.all(color: LuxTheme.gold, width: 1.5) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? (isCurrent ? LuxTheme.gold : LuxTheme.surfaceElevated) : LuxTheme.surface,
              shape: BoxShape.circle,
              border: isActive ? null : Border.all(color: LuxTheme.textSecondary.withOpacity(0.3)),
            ),
            child: Icon(isActive ? Icons.check_rounded : Icons.circle, color: isActive ? (isCurrent ? LuxTheme.deepBlack : LuxTheme.textPrimary) : LuxTheme.textSecondary, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isActive ? LuxTheme.textPrimary : LuxTheme.textSecondary, fontSize: 14))),
        ],
      ),
    );
  }
}
