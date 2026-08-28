import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import 'order_tracking_screen.dart';

/// Browse a shop's live menu, pick quantities, place the order.
/// Replaces the old hardcoded "signature menu" basket.
Future<void> showMenuSheet(
    BuildContext context, Map<String, dynamic> shop, String shopImage) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: LuxTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _MenuSheet(shop: shop, shopImage: shopImage),
  );
}

class _MenuSheet extends StatefulWidget {
  final Map<String, dynamic> shop;
  final String shopImage;
  const _MenuSheet({required this.shop, required this.shopImage});

  @override
  State<_MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<_MenuSheet> {
  List<Map<String, dynamic>> items = [];
  final Map<int, int> _qty = {}; // menu item id → quantity
  bool loading = true;
  String? error;
  bool placing = false;

  static const String deliveryAddress = '4 Fola Osibo Rd, Lekki Phase 1, Lagos';

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final data = await ApiService.fetchMenu(widget.shop['id']);
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

  int get _itemCount => _qty.values.fold(0, (a, b) => a + b);

  double get _subtotal {
    double sum = 0;
    for (final entry in _qty.entries) {
      final item = items.firstWhere((i) => i['id'] == entry.key,
          orElse: () => <String, dynamic>{});
      if (item.isNotEmpty) {
        sum += (double.tryParse('${item['price']}') ?? 0) * entry.value;
      }
    }
    return sum;
  }

  double get _total => _subtotal + 850 + 200; // + delivery + service fee

  void _bump(int itemId, int delta) {
    setState(() {
      final next = (_qty[itemId] ?? 0) + delta;
      if (next <= 0) {
        _qty.remove(itemId);
      } else {
        _qty[itemId] = next;
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_itemCount == 0 || placing) return;
    setState(() => placing = true);
    try {
      final chosen = _qty.entries.map((e) {
        final item = items.firstWhere((i) => i['id'] == e.key);
        return {
          'name': item['name'],
          'price': double.tryParse('${item['price']}') ?? 0,
          'quantity': e.value,
        };
      }).toList();
      final order = await ApiService.placeOrder(
        customerId: Session.userId,
        shopId: widget.shop['id'],
        items: chosen,
        deliveryAddress: deliveryAddress,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // close the menu sheet
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            OrderTrackingScreen(orderId: order['id'], initialOrder: order),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => placing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: LuxTheme.surfaceElevated,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.86;
    return SizedBox(
      height: h,
      child: Column(children: [
        _buildHeader(),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: LuxTheme.gold))
              : error != null
                  ? _buildError()
                  : items.isEmpty
                      ? _buildEmptyMenu()
                      : _buildMenuList(),
        ),
        _buildCheckoutBar(),
      ]),
    );
  }

  Widget _buildHeader() {
    return Stack(children: [
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Image.network(
          widget.shopImage,
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
              height: 120,
              color: LuxTheme.surfaceElevated,
              child: const Icon(Icons.restaurant, color: LuxTheme.gold, size: 40)),
        ),
      ),
      Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          gradient: LinearGradient(
              colors: [Colors.transparent, LuxTheme.deepBlack.withOpacity(0.92)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
      ),
      Positioned(
        left: 20, right: 20, bottom: 12,
        child: Row(children: [
          Expanded(
              child: Text(widget.shop['name'] ?? '',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 20, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary))),
          Text('~${widget.shop['avg_prep_minutes']} min',
              style: GoogleFonts.inter(
                  color: LuxTheme.gold, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
      Positioned(
        top: 12, right: 12,
        child: CircleAvatar(
          radius: 16,
          backgroundColor: LuxTheme.deepBlack.withOpacity(0.6),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, color: LuxTheme.textPrimary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    ]);
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, color: LuxTheme.error, size: 36),
            const SizedBox(height: 12),
            Text('Cannot load the menu.\nPull down to retry.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadMenu, child: const Text('Retry')),
          ]),
        ),
      );

  Widget _buildEmptyMenu() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.restaurant_menu_rounded, color: LuxTheme.gold, size: 36),
            const SizedBox(height: 12),
            Text('This restaurant hasn\'t added its menu yet.\nCheck back soon!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
          ]),
        ),
      );

  Widget _buildMenuList() {
    // Group by category in kitchen order.
    final categories = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      categories
          .putIfAbsent((it['category'] as String?) ?? 'Mains', () => [])
          .add(it);
    }
    return RefreshIndicator(
      color: LuxTheme.gold,
      backgroundColor: LuxTheme.surfaceElevated,
      onRefresh: _loadMenu,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: categories.entries
            .expand((e) => [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(e.key.toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: LuxTheme.gold)),
                  ),
                  ...e.value.map(_buildMenuItem),
                ])
            .toList(),
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final qty = _qty[id] ?? 0;
    final price = double.tryParse('${item['price']}') ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LuxTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: qty > 0 ? LuxTheme.gold.withOpacity(0.5) : LuxTheme.gold.withOpacity(0.08)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['name'] as String? ?? '',
                style: const TextStyle(
                    color: LuxTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            if (item['description'] != null && '${item['description']}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('${item['description']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: LuxTheme.textSecondary, fontSize: 11)),
              ),
            const SizedBox(height: 6),
            Text('₦${price % 1 == 0 ? price.toInt() : price.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                    color: LuxTheme.gold, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
        _stepper(id, qty),
      ]),
    );
  }

  Widget _stepper(int id, int qty) {
    if (qty == 0) {
      return OutlinedButton(
        onPressed: () => _bump(id, 1),
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: LuxTheme.gold),
            minimumSize: const Size(64, 34)),
        child: const Text('Add',
            style: TextStyle(color: LuxTheme.gold, fontSize: 12, fontWeight: FontWeight.w700)),
      );
    }
    return Row(children: [
      _stepBtn(Icons.remove_rounded, () => _bump(id, -1)),
      SizedBox(
        width: 30,
        child: Text('$qty',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: LuxTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
      _stepBtn(Icons.add_rounded, () => _bump(id, 1)),
    ]);
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LuxTheme.gold.withOpacity(0.15),
              border: Border.all(color: LuxTheme.gold.withOpacity(0.5))),
          child: Icon(icon, color: LuxTheme.gold, size: 16),
        ),
      );

  Widget _buildCheckoutBar() {
    final enabled = _itemCount > 0 && !placing;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: LuxTheme.surfaceElevated,
        border: Border(top: BorderSide(color: LuxTheme.gold.withOpacity(0.15))),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_itemCount == 0 ? 'Nothing selected' : '$_itemCount item${_itemCount > 1 ? 's' : ''} · ₦${_subtotal % 1 == 0 ? _subtotal.toInt() : _subtotal.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  color: LuxTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text('Total ₦${_total % 1 == 0 ? _total.toInt() : _total.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.bold, color: LuxTheme.textPrimary)),
        ]),
        const Spacer(),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: enabled ? _placeOrder : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: enabled ? LuxTheme.gold : LuxTheme.surface),
            child: placing
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: LuxTheme.deepBlack))
                : const Text('Place order'),
          ),
        ),
      ]),
    );
  }
}
