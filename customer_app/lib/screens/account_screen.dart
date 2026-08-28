import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/session.dart';
import '../services/socket_service.dart';
import '../services/push_service.dart';
import 'auth_screen.dart';

/// Chowdeck-style account tab — sign in / profile / sign out.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    final user = Session.user;
    return Scaffold(
      backgroundColor: LuxTheme.bg,
      appBar: AppBar(
        backgroundColor: LuxTheme.primary,
        title:
            Text('Account', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---- profile card ----
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: LuxTheme.surface),
            ),
            child: Session.isLoggedIn
                ? Row(children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: LuxTheme.primary,
                      child: Text(
                        Session.name.isNotEmpty ? Session.name.substring(0, 1).toUpperCase() : '👤',
                        style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(Session.name,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: LuxTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${user?['email'] ?? ''}',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: LuxTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: LuxTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('VERIFIED CUSTOMER',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: LuxTheme.primary)),
                        ),
                      ]),
                    ),
                  ])
                : Column(children: [
                    const Icon(Icons.person_outline_rounded,
                        color: LuxTheme.primary, size: 44),
                    const SizedBox(height: 12),
                    Text('You\'re browsing as a guest',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: LuxTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Text('Sign in to order, track deliveries and keep your history.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: LuxTheme.textSecondary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (ctx) => AuthScreen(
                            role: 'customer',
                            title: 'Welcome to Nature Fete',
                            onAuthed: () => Navigator.of(ctx).pop(true),
                          ),
                        )).then((ok) {
                          if (ok == true) setState(() {});
                        }),
                        child: const Text('Sign in'),
                      ),
                    ),
                  ]),
          ),
          const SizedBox(height: 16),

          // ---- info tiles ----
          _tile(Icons.location_on_rounded, 'Delivery address', '4 Fola Osibo Rd, Lekki Phase 1, Lagos'),
          _tile(Icons.payments_rounded, 'Payment', 'Paystack (card / transfer)'),
          _tile(Icons.support_agent_rounded, 'Support', 'support@naturefete.ng'),
          _tile(Icons.info_outline_rounded, 'About', 'Nature Fete v4.1.0'),

          if (Session.isLoggedIn) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LuxTheme.error,
                  side: const BorderSide(color: LuxTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  final logout = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Text('Log out?',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800, color: LuxTheme.textPrimary)),
                      content: Text(
                          'You can keep browsing — your cart stays on this device.',
                          style: GoogleFonts.inter(
                              color: LuxTheme.textSecondary, fontSize: 13)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Stay')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Log out',
                                style: TextStyle(color: LuxTheme.error))),
                      ],
                    ),
                  );
                  if (logout == true) {
                    await PushService.unregister();
                    await Session.clear();
                    SocketService.disconnect();
                    if (mounted) setState(() {});
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log out',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: LuxTheme.surface),
        ),
        child: Row(children: [
          Icon(icon, color: LuxTheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: LuxTheme.textPrimary)),
            Text(subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: LuxTheme.textSecondary)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: LuxTheme.textSecondary, size: 20),
        ]),
      );
}
