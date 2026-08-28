import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_api.dart';
import '../services/session.dart';

/// Login → Register → Verify (email + SMS OTP) flow, luxury dark theme.
class AuthScreen extends StatefulWidget {
  final String role; // 'customer' | 'shop' | 'rider'
  final String title;
  final VoidCallback onAuthed;
  const AuthScreen({super.key, required this.role, required this.title, required this.onAuthed});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { login, register, verify }

class _AuthScreenState extends State<AuthScreen> {
  _Mode mode = _Mode.login;
  bool busy = false;

  final identifier = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController(text: '+234');
  final shopName = TextEditingController();
  final emailCode = TextEditingController();
  final phoneCode = TextEditingController();

  dynamic pendingUserId;
  String? devEmailCode;
  String? devPhoneCode;
  bool emailVerified = false;
  bool phoneVerified = false;

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: LuxTheme.surfaceElevated,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      _toast('⚠️ ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _login() => _run(() async {
        final r = await AuthApi.login(identifier.text.trim(), password.text);
        if (r['needsVerification'] == true) {
          pendingUserId = r['userId'];
          devEmailCode = r['devEmailCode'];
          devPhoneCode = r['devPhoneCode'];
          emailVerified = r['user']?['emailVerified'] ?? false;
          phoneVerified = r['user']?['phoneVerified'] ?? false;
          setState(() => mode = _Mode.verify);
          _toast('Verify your account — codes sent');
          return;
        }
        await Session.save(r['token'], r['user']);
        widget.onAuthed();
      });

  Future<void> _register() => _run(() async {
        final r = await AuthApi.register(
          name: name.text.trim(),
          email: email.text.trim(),
          phone: phone.text.trim(),
          password: password.text,
          role: widget.role,
          shopName: widget.role == 'shop' ? shopName.text.trim() : null,
        );
        pendingUserId = r['userId'];
        devEmailCode = r['devEmailCode'];
        devPhoneCode = r['devPhoneCode'];
        emailVerified = false;
        phoneVerified = false;
        setState(() => mode = _Mode.verify);
        _toast('Account created — verify email & phone');
      });

  Future<void> _verify(String channel, String code) => _run(() async {
        final r = await AuthApi.verify(pendingUserId, channel, code.trim());
        _toast(r['message'] ?? 'Verified');
        if (channel == 'email') emailVerified = true;
        if (channel == 'phone') phoneVerified = true;
        if (r['fullyVerified'] == true && r['token'] != null) {
          await Session.save(r['token'], r['user']);
          widget.onAuthed();
        } else {
          setState(() {});
        }
      });

  Future<void> _resend(String channel) => _run(() async {
        final r = await AuthApi.resend(pendingUserId, channel);
        if (channel == 'email') devEmailCode = (r['devCode'] ?? devEmailCode)?.toString();
        if (channel == 'phone') devPhoneCode = (r['devCode'] ?? devPhoneCode)?.toString();
        setState(() {});
        _toast(r['message'] ?? 'Code re-sent');
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Nature Fete',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 36, fontWeight: FontWeight.w700, color: LuxTheme.gold)),
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: LuxTheme.textSecondary)),
              const SizedBox(height: 32),
              if (mode == _Mode.login) ..._loginForm(),
              if (mode == _Mode.register) ..._registerForm(),
              if (mode == _Mode.verify) ..._verifyForm(),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _loginForm() => [
        _field(identifier, 'Email or phone number', Icons.person_rounded),
        _field(password, 'Password', Icons.lock_rounded, obscure: true),
        const SizedBox(height: 20),
        _primaryBtn('SIGN IN', busy ? null : _login),
        const SizedBox(height: 12),
        _linkBtn('New here? Create an account', () => setState(() => mode = _Mode.register)),
        const SizedBox(height: 20),
        Text('Demo: ${widget.role}@luxefeast.com / demo123',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, color: LuxTheme.textSecondary)),
      ];

  List<Widget> _registerForm() => [
        _field(name, 'Full name', Icons.badge_rounded),
        if (widget.role == 'shop') _field(shopName, 'Restaurant name', Icons.storefront_rounded),
        _field(email, 'Email address', Icons.email_rounded),
        _field(phone, 'Phone (+234...)', Icons.phone_rounded),
        _field(password, 'Password (min 6 chars)', Icons.lock_rounded, obscure: true),
        const SizedBox(height: 20),
        _primaryBtn('CREATE ACCOUNT', busy ? null : _register),
        const SizedBox(height: 12),
        _linkBtn('Already registered? Sign in', () => setState(() => mode = _Mode.login)),
      ];

  List<Widget> _verifyForm() => [
        Text('Verify your account',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
        const SizedBox(height: 8),
        Text('Enter the 6-digit codes sent to your email and phone.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: LuxTheme.textSecondary)),
        if (devEmailCode != null || devPhoneCode != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: LuxTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LuxTheme.gold.withOpacity(0.3))),
            child: Text(
              '🧪 SANDBOX MODE — codes for testing:\n'
              '${devEmailCode != null ? 'Email: $devEmailCode  ' : ''}'
              '${devPhoneCode != null ? 'SMS: $devPhoneCode' : ''}\n'
              '(live email/SMS activates once provider keys are configured)',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: LuxTheme.gold),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (!emailVerified) ...[
          _field(emailCode, 'Email code', Icons.email_rounded),
          Row(children: [
            Expanded(child: _primaryBtn('VERIFY EMAIL', busy ? null : () => _verify('email', emailCode.text))),
            const SizedBox(width: 8),
            _linkBtn('Resend', () => _resend('email')),
          ]),
          const SizedBox(height: 16),
        ] else
          _verifiedRow('Email verified'),
        if (!phoneVerified) ...[
          _field(phoneCode, 'SMS code', Icons.sms_rounded),
          Row(children: [
            Expanded(child: _primaryBtn('VERIFY PHONE', busy ? null : () => _verify('phone', phoneCode.text))),
            const SizedBox(width: 8),
            _linkBtn('Resend', () => _resend('phone')),
          ]),
        ] else
          _verifiedRow('Phone verified'),
        const SizedBox(height: 16),
        _linkBtn('Back to sign in', () => setState(() => mode = _Mode.login)),
      ];

  Widget _verifiedRow(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle_rounded, color: LuxTheme.success, size: 18),
          const SizedBox(width: 8),
          Text(t, style: GoogleFonts.inter(color: LuxTheme.success, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _field(TextEditingController c, String hint, IconData icon, {bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          obscureText: obscure,
          style: GoogleFonts.inter(color: LuxTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13),
            prefixIcon: Icon(icon, color: LuxTheme.gold, size: 20),
            filled: true,
            fillColor: LuxTheme.surfaceElevated,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      );

  Widget _primaryBtn(String label, VoidCallback? onTap) => SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: LuxTheme.gold,
              foregroundColor: LuxTheme.deepBlack,
              disabledBackgroundColor: LuxTheme.gold.withOpacity(0.4)),
          child: busy
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: LuxTheme.deepBlack))
              : Text(label, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
      );

  Widget _linkBtn(String label, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Text(label, style: GoogleFonts.inter(color: LuxTheme.gold, fontSize: 13)),
      );
}
