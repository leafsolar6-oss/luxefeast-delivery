import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Shared building blocks for the shop app screens.

/// Formats "4550.00" / 4550 → "₦4,550".
String money(dynamic v) {
  final n = double.tryParse('$v') ?? 0;
  final fixed = n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
  final parts = fixed.split('.');
  String grouped = '';
  for (int i = 0; i < parts[0].length; i++) {
    grouped += parts[0][i];
    final remaining = parts[0].length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) grouped += ',';
  }
  return '₦$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String shortDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final local = dt.toLocal();
  return '${local.day} ${months[local.month - 1]}, '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  Color get _color => switch (status) {
        'placed' => LuxTheme.error,
        'delivered' => LuxTheme.success,
        'cancelled' || 'rejected' => LuxTheme.textSecondary,
        'ready_for_pickup' || 'picked_up' || 'in_transit' || 'arrived' => LuxTheme.success,
        _ => LuxTheme.gold,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: _color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _color.withOpacity(0.4))),
        child: Text(status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.playfairDisplay(
          fontSize: 20, fontWeight: FontWeight.w600, color: LuxTheme.textPrimary));
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const StatTile(
      {super.key, required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: LuxTheme.gold.withOpacity(0.1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.bold, color: LuxTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 11)),
        ]),
      );
}

class ErrorCard extends StatelessWidget {
  final String message;
  const ErrorCard(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.wifi_off_rounded, color: LuxTheme.error, size: 36),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        ]),
      );
}

void shopToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
    backgroundColor: LuxTheme.surfaceElevated,
    behavior: SnackBarBehavior.floating,
  ));
}
