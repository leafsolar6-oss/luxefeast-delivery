import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'cart_sheet.dart';

/// Browse a shop's live menu. Adding items goes straight into the cart
/// (no login needed) — checkout happens in the cart sheet.
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
  bool loading = true;
  String? error;

  int get _shopId => idOf(widget.shop['id']);
  String get _shopName => '${widget.shop['name']}';

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

  /// If the cart holds another shop's food, ask before replacing it.
  Future<bool> _ensureCartShop() async {
    final cart = CartService.instance;
    if (!cart.conflictsWith(_shopId)) return true;
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LuxTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Start a new cart?',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
        content: Text(
            'Your cart has items from ${cart.shopName}. Ordering from $_shopName will replace them.',
            style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep old cart',
                  style: TextStyle(color: LuxTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Start fresh',
                  style: TextStyle(color: LuxTheme.gold))),
        ],
      ),
    );
    return replace == true;
  }

  Future<void> _add(Map<String, dynamic> item) async {
    if (!await _ensureCartShop()) return;
    CartService.instance.addItem(
      shopId: _shopId,
      shopName: _shopName,
      itemId: idOf(item['id']),
      name: '${item['name']}',
      price: double.tryParse('${item['price']}') ?? 0,
    );
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
        _buildCartBar(),
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
              colors: [Colors.transparent, LuxTheme.primaryDark.withOpacity(0.92)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
      ),
      Positioned(
        left: 20, right: 20, bottom: 12,
        child: Row(children: [
          Expanded(
              child: Text(_shopName,
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
          Text('~${widget.shop['avg_prep_minutes']} min',
              style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
      Positioned(
        top: 12, right: 12,
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.black.withOpacity(0.35),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
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
    final id = idOf(item['id']);
    final price = double.tryParse('${item['price']}') ?? 0;
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final qty = CartService.instance.qtyOf(_shopId, id);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: qty > 0
                    ? LuxTheme.gold.withOpacity(0.5)
                    : LuxTheme.gold.withOpacity(0.08)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${item['name']}',
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
      },
    );
  }

  Widget _stepper(int id, int qty) {
    if (qty == 0) {
      return OutlinedButton(
        onPressed: () async => _add(items.firstWhere((i) => idOf(i['id']) == id)),
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: LuxTheme.gold),
            minimumSize: const Size(64, 34)),
        child: const Text('Add',
            style: TextStyle(color: LuxTheme.gold, fontSize: 12, fontWeight: FontWeight.w700)),
      );
    }
    return Row(children: [
      _stepBtn(Icons.remove_rounded, () => CartService.instance.bump(id, -1)),
      SizedBox(
        width: 30,
        child: Text('$qty',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: LuxTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
      _stepBtn(Icons.add_rounded,
          () async => _add(items.firstWhere((i) => idOf(i['id']) == id))),
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

  /// Sticky bar showing cart state; opens the cart sheet.
  Widget _buildCartBar() {
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final cart = CartService.instance;
        if (cart.isEmpty) return const SizedBox.shrink();
        final mine = cart.shopId == _shopId;
        return Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20,
              MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated,
            border: Border(top: BorderSide(color: LuxTheme.gold.withOpacity(0.15))),
          ),
          child: Row(children: [
            Icon(mine ? Icons.shopping_bag_rounded : Icons.info_outline_rounded,
                color: LuxTheme.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mine
                    ? '${cart.count} item${cart.count > 1 ? 's' : ''} · ₦${_fmt(cart.subtotal)}'
                    : 'Cart holds items from ${cart.shopName}',
                style: GoogleFonts.inter(
                    color: LuxTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: () => showCartSheet(context),
                child: const Text('View cart'),
              ),
            ),
          ]),
        );
      },
    );
  }
}

String _fmt(double n) =>
    n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(0);
