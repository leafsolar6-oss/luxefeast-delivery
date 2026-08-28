import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../widgets/shop_widgets.dart';

/// Menu manager — the shop decides what customers can order.
/// Add / edit / hide / delete items; everything here is live in the
/// customer app instantly (they only see available items).
class MenuManagerScreen extends StatefulWidget {
  const MenuManagerScreen({super.key});

  @override
  State<MenuManagerScreen> createState() => _MenuManagerScreenState();
}

class _MenuManagerScreenState extends State<MenuManagerScreen> {
  int get shopId => Session.entityId > 0 ? Session.entityId : 1;

  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final data = await ApiService.fetchMenu(shopId, includeUnavailable: true);
      if (!mounted) return;
      setState(() {
        items = data.cast<Map<String, dynamic>>();
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _toggleAvailable(Map<String, dynamic> item, bool value) async {
    final old = item['is_available'];
    setState(() => item['is_available'] = value); // optimistic
    try {
      await ApiService.updateMenuItem(
          shopId, item['id'], {'isAvailable': value});
      if (mounted) {
        shopToast(context,
            value ? '🟢 "${item['name']}" is back on the menu' : '⚪ "${item['name']}" hidden from customers');
      }
    } catch (e) {
      if (mounted) {
        setState(() => item['is_available'] = old);
        shopToast(context, '⚠️ ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LuxTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete "${item['name']}"?',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
        content: Text('It will disappear from the customer app. Past orders keep their history.',
            style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep', style: TextStyle(color: LuxTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: LuxTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteMenuItem(shopId, item['id']);
      await _refresh();
    } catch (e) {
      if (mounted) shopToast(context, '⚠️ ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LuxTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _MenuItemForm(existing: existing),
    );
    if (saved == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Group items by category, preserving sort order.
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final cat = (it['category'] as String?) ?? 'Mains';
      categories.putIfAbsent(cat, () => []).add(it);
    }
    final availableCount = items.where((i) => i['is_available'] == true).length;

    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      appBar: AppBar(title: const Text('Menu')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LuxTheme.gold,
        foregroundColor: LuxTheme.deepBlack,
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        color: LuxTheme.gold,
        backgroundColor: LuxTheme.surfaceElevated,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
          children: [
            Text('Customers see $availableCount of ${items.length} items',
                style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: LuxTheme.gold)))
            else if (error != null)
              ErrorCard('Cannot reach LuxFeast servers.\nPull down to retry.')
            else if (items.isEmpty)
              _buildEmpty()
            else
              ...categories.entries.expand((e) => [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                      child: Text(e.key.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: LuxTheme.gold)),
                    ),
                    ...e.value.map(_buildItemCard),
                    const SizedBox(height: 8),
                  ]),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          const Icon(Icons.restaurant_menu_rounded, color: LuxTheme.gold, size: 36),
          const SizedBox(height: 12),
          Text('Your menu is empty.\nAdd your first dish with the + button.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        ]),
      );

  Widget _buildItemCard(Map<String, dynamic> item) {
    final available = item['is_available'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: LuxTheme.surfaceElevated,
        border: Border.all(
            color: available
                ? LuxTheme.gold.withOpacity(0.1)
                : LuxTheme.textSecondary.withOpacity(0.2)),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openEditor(existing: item),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] as String? ?? '',
                  style: TextStyle(
                      color: available ? LuxTheme.textPrimary : LuxTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              if (item['description'] != null && '${item['description']}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${item['description']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: LuxTheme.textSecondary, fontSize: 12)),
                ),
              const SizedBox(height: 6),
              Text(money(item['price']),
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: available ? LuxTheme.gold : LuxTheme.textSecondary)),
            ]),
          ),
        ),
        Switch(
          value: available,
          activeColor: LuxTheme.gold,
          onChanged: (v) => _toggleAvailable(item, v),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: LuxTheme.textSecondary, size: 20),
          onPressed: () => _deleteItem(item),
        ),
      ]),
    );
  }
}

/// Bottom-sheet form used for both "add" and "edit".
class _MenuItemForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _MenuItemForm({this.existing});

  @override
  State<_MenuItemForm> createState() => _MenuItemFormState();
}

class _MenuItemFormState extends State<_MenuItemForm> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _category;
  bool saving = false;

  static const _categoryChips = ['Mains', 'Sides', 'Proteins', 'Soups', 'Grills', 'Snacks', 'Drinks'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name'] as String? ?? '');
    _price = TextEditingController(text: e == null ? '' : '${e['price']}');
    _description = TextEditingController(text: e?['description'] as String? ?? '');
    _category = TextEditingController(text: e?['category'] as String? ?? 'Mains');
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shopId = Session.entityId > 0 ? Session.entityId : 1;
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    if (name.isEmpty) {
      shopToast(context, '⚠️ Give the dish a name');
      return;
    }
    if (price == null || price < 0) {
      shopToast(context, '⚠️ Enter a valid price');
      return;
    }
    setState(() => saving = true);
    final body = {
      'name': name,
      'price': price,
      'description': _description.text.trim(),
      'category': _category.text.trim().isEmpty ? 'Mains' : _category.text.trim(),
    };
    try {
      if (widget.existing == null) {
        await ApiService.addMenuItem(shopId, body);
      } else {
        await ApiService.updateMenuItem(shopId, widget.existing!['id'], body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        shopToast(context, '⚠️ ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(width: 44, height: 4,
              decoration: BoxDecoration(
                  color: LuxTheme.textSecondary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(height: 16),
        Text(editing ? 'Edit dish' : 'New dish',
            style: GoogleFonts.playfairDisplay(
                fontSize: 22, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
        const SizedBox(height: 20),
        _field(_name, 'Dish name', Icons.restaurant_rounded),
        const SizedBox(height: 12),
        _field(_price, 'Price (₦)', Icons.payments_rounded,
            keyboard: TextInputType.number),
        const SizedBox(height: 12),
        _field(_description, 'Short description (optional)', Icons.notes_rounded),
        const SizedBox(height: 16),
        Text('CATEGORY',
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.bold, color: LuxTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _categoryChips.map((c) {
            final selected = _category.text == c;
            return ChoiceChip(
              label: Text(c),
              selected: selected,
              onSelected: (_) => setState(() => _category.text = c),
              backgroundColor: LuxTheme.surfaceElevated,
              selectedColor: LuxTheme.gold,
              labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? LuxTheme.deepBlack : LuxTheme.textPrimary),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: LuxTheme.deepBlack))
                : Text(editing ? 'Save changes' : 'Add to menu'),
          ),
        ),
      ]),
    );
  }

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
