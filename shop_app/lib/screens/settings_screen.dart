import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../main.dart';
import '../widgets/shop_widgets.dart';

/// Shop settings — availability, profile, default prep time, account.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int get shopId => Session.entityId > 0 ? Session.entityId : 1;

  Map<String, dynamic>? shop;
  bool loading = true;
  bool saving = false;
  String? error;

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _cuisines;
  int _prepMinutes = 20;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _address = TextEditingController();
    _city = TextEditingController();
    _cuisines = TextEditingController();
    _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _cuisines.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await ApiService.fetchShop(shopId);
      if (!mounted) return;
      setState(() {
        shop = s;
        _name.text = s['name'] as String? ?? '';
        _phone.text = s['phone'] as String? ?? '';
        _address.text = s['address'] as String? ?? '';
        _city.text = s['city'] as String? ?? '';
        _cuisines.text = ((s['cuisines'] as List<dynamic>?) ?? []).join(', ');
        _prepMinutes = (s['avg_prep_minutes'] as num?)?.toInt() ?? 20;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _toggleOpen(bool value) async {
    final old = shop!['is_open'] == true;
    setState(() => shop!['is_open'] = value); // optimistic
    try {
      await ApiService.updateShop(shopId, {'isOpen': value});
      if (mounted) {
        shopToast(context,
            value ? '🟢 Open — customers can order again' : '🔴 Closed — hidden from customers');
      }
    } catch (e) {
      if (mounted) {
        setState(() => shop!['is_open'] = old);
        shopToast(context, '⚠️ ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await ApiService.updateShop(shopId, {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'cuisines': _cuisines.text
            .split(',')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList(),
        'avgPrepMinutes': _prepMinutes,
      });
      await _refresh();
      if (mounted) shopToast(context, '✅ Profile saved');
    } catch (e) {
      if (mounted) shopToast(context, '⚠️ ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = shop?['is_open'] == true;
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(title: const Text('Settings')),
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
              // ---- availability ----
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: LuxTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isOpen
                            ? LuxTheme.success.withOpacity(0.4)
                            : LuxTheme.error.withOpacity(0.4))),
                child: Column(children: [
                  Row(children: [
                    Icon(isOpen ? Icons.storefront_rounded : Icons.block_rounded,
                        color: isOpen ? LuxTheme.success : LuxTheme.error, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isOpen ? 'Open for orders' : 'Closed',
                                  style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: LuxTheme.textPrimary)),
                              Text(
                                  isOpen
                                      ? 'Your shop is visible in the customer app.'
                                      : 'Customers cannot see or order from you.',
                                  style: const TextStyle(
                                      color: LuxTheme.textSecondary, fontSize: 12)),
                            ])),
                    Switch(value: isOpen, activeColor: LuxTheme.gold, onChanged: _toggleOpen),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              // ---- profile form ----
              const SectionTitle('Shop profile'),
              const SizedBox(height: 16),
              _field(_name, 'Shop name', Icons.storefront_rounded),
              const SizedBox(height: 12),
              _field(_phone, 'Phone', Icons.phone_rounded,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_address, 'Address', Icons.location_on_rounded),
              const SizedBox(height: 12),
              _field(_city, 'City', Icons.location_city_rounded),
              const SizedBox(height: 12),
              _field(_cuisines, 'Cuisines (comma separated)', Icons.restaurant_rounded),

              const SizedBox(height: 20),
              // ---- default prep time ----
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: LuxTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: LuxTheme.gold.withOpacity(0.1))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.timer_outlined, color: LuxTheme.gold, size: 18),
                    const SizedBox(width: 8),
                    Text('DEFAULT PREP TIME',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: LuxTheme.gold)),
                    const Spacer(),
                    Text('$_prepMinutes min',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: LuxTheme.textPrimary)),
                  ]),
                  Slider(
                    value: _prepMinutes.toDouble(),
                    min: 5, max: 90, divisions: 17,
                    activeColor: LuxTheme.gold,
                    label: '$_prepMinutes min',
                    onChanged: (v) => setState(() => _prepMinutes = v.round()),
                  ),
                  Text('Pre-filled when accepting new orders.',
                      style: GoogleFonts.inter(
                          color: LuxTheme.textSecondary, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _save,
                  child: saving
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: LuxTheme.deepBlack))
                      : const Text('Save changes'),
                ),
              ),
              const SizedBox(height: 12),

              // ---- account ----
              const SizedBox(height: 12),
              const SectionTitle('Account'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: LuxTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  _accountRow(Icons.person_rounded, Session.name),
                  if (Session.user?['email'] != null)
                    _accountRow(Icons.mail_outline_rounded, '${Session.user!['email']}'),
                  _accountRow(Icons.verified_user_outlined,
                      'Shop #${Session.entityId > 0 ? Session.entityId : shopId}'),
                ]),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  await Session.clear();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                        (r) => false);
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: LuxTheme.error, size: 18),
                label: const Text('Log out',
                    style: TextStyle(color: LuxTheme.error, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _accountRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: LuxTheme.gold, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: LuxTheme.textPrimary, fontSize: 13))),
        ]),
      );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: LuxTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: LuxTheme.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: LuxTheme.gold, size: 20),
        filled: true,
        fillColor: LuxTheme.surfaceElevated,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: LuxTheme.gold.withOpacity(0.15))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: LuxTheme.gold.withOpacity(0.15))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: LuxTheme.gold)),
      ),
    );
  }
}
