import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/session.dart';
import '../services/cart_service.dart';
import 'cart_sheet.dart';
import 'menu_sheet.dart';

/// Chowdeck-style home: green location header + search, category chips,
/// "Popular now" quick-add row and merchant cards.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const String deliveryAddress = '4 Fola Osibo Rd, Lekki Phase 1';

  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> menu = [];
  List<Map<String, dynamic>> popular = [];
  bool loading = true;
  String? error;
  String query = '';
  String? activeCategory;

  static const Map<String, String> shopImages = {
    'Nature Fete': 'https://images.unsplash.com/photo-1546173159-315724a31696?w=600&q=80',
  };

  static const Map<String, String> categoryEmoji = {
    'Parfaits': '🥣',
    'Juices': '🧃',
    'Smoothies': '🥤',
    'Bowls': '🥗',
    'Light Bites': '🥑',
    'Drinks': '🥥',
    'Snacks': '🌰',
    'Mains': '🍲',
  };

  @override
  void initState() {
    super.initState();
    if (Session.isLoggedIn) {
      SocketService.connect(customerId: Session.userId);
      SocketService.attachOrderNotifications();
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        ApiService.fetchShops(),
        shops.isEmpty
            ? Future.value(<dynamic>[])
            : Future.value(<dynamic>[]),
      ]);
      final shopList = (results[0] as List<dynamic>).cast<Map<String, dynamic>>();
      // Load the menu of every open shop for the "Popular now" row + chips.
      final menus = await Future.wait(
          shopList.map((s) => ApiService.fetchMenu(s['id']).catchError((_) => <dynamic>[])));
      if (!mounted) return;
      setState(() {
        shops = shopList;
        menu = menus.expand((m) => (m as List<dynamic>).cast<Map<String, dynamic>>()).toList();
        popular = List.from(menu)..sort((a, b) {
          // drinks & parfaits first — the signature items
          final rank = (m) => ['Parfaits', 'Juices', 'Smoothies'].indexOf('${m['category']}');
          return rank(a).compareTo(rank(b));
        });
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = e.toString(); });
    }
  }

  List<String> get categories {
    final cats = menu.map((m) => '${m['category']}').toSet().toList();
    return cats;
  }

  List<Map<String, dynamic>> get filteredPopular {
    var items = popular;
    if (activeCategory != null) {
      items = items.where((m) => '${m['category']}' == activeCategory).toList();
    }
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      items = items.where((m) => '${m['name']}'.toLowerCase().contains(q)).toList();
    }
    return items;
  }

  void _quickAdd(Map<String, dynamic> item, Map<String, dynamic> shop) {
    CartService.instance.addItem(
      shopId: int.tryParse('${shop['id']}') ?? 0,
      shopName: '${shop['name']}',
      itemId: int.tryParse('${item['id']}') ?? 0,
      name: '${item['name']}',
      price: double.tryParse('${item['price']}') ?? 0,
    );
    showCartSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              color: LuxTheme.primary,
              onRefresh: _load,
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: LuxTheme.primary))
                  : error != null
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          _errorCard(),
                        ])
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            const SizedBox(height: 16),
                            if (categories.isNotEmpty) _buildCategories(),
                            if (filteredPopular.isNotEmpty) ...[
                              _sectionHeader('Popular now', '${filteredPopular.length} items'),
                              _buildPopularRow(),
                            ],
                            _sectionHeader('Restaurants', '${shops.length} open now'),
                            ...shops.map(_buildShopCard),
                            const SizedBox(height: 8),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  /// Green header: location, greeting, cart and search — the Chowdeck signature.
  Widget _buildHeader() {
    return Container(
      color: LuxTheme.primary,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20, bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivering to',
                  style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.75), fontSize: 11)),
              Text(
                Session.isLoggedIn
                    ? '${Session.name.split(' ').first} · $deliveryAddress'
                    : deliveryAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
          ListenableBuilder(
            listenable: CartService.instance,
            builder: (context, _) {
              final count = CartService.instance.count;
              return IconButton(
                onPressed: () => showCartSheet(context),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold)),
                  backgroundColor: LuxTheme.amber,
                  textColor: Colors.black,
                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 14),
        // Search
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: 'Search parfaits, juices, smoothies…',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: LuxTheme.textSecondary, size: 22),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCategories() {
    final chips = <String>[...categories];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final cat = chips[i];
          final selected = activeCategory == cat;
          return ChoiceChip(
            label: Text('${categoryEmoji[cat] ?? '🍽️'}  $cat',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : LuxTheme.textPrimary)),
            selected: selected,
            onSelected: (_) => setState(() =>
                activeCategory = selected ? null : cat),
            backgroundColor: Colors.white,
            selectedColor: LuxTheme.primary,
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            side: BorderSide(color: LuxTheme.surface),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, String trailing) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w800, color: LuxTheme.textPrimary)),
          const Spacer(),
          Text(trailing,
              style: GoogleFonts.inter(fontSize: 12, color: LuxTheme.textSecondary)),
        ]),
      );

  /// Horizontal quick-add cards — Chowdeck's "quick grab" pattern.
  Widget _buildPopularRow() {
    final items = filteredPopular.take(12).toList();
    final shopFor = (Map<String, dynamic> item) => shops.firstWhere(
        (s) => '${s['id']}' == '${item['shop_id']}',
        orElse: () => shops.isNotEmpty ? shops.first : <String, dynamic>{});
    return SizedBox(
      height: 168,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final item = items[i];
          final price = double.tryParse('${item['price']}') ?? 0;
          final emoji =
              categoryEmoji['${item['category']}'] ?? '🍽️';
          return Container(
            width: 132,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: LuxTheme.surface),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 54,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LuxTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(height: 8),
                Text('${item['name']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: LuxTheme.textPrimary,
                        height: 1.2)),
                const Spacer(),
                Row(children: [
                  Expanded(
                    child: Text('₦${price % 1 == 0 ? price.toInt() : price}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: LuxTheme.primary)),
                  ),
                  GestureDetector(
                    onTap: () => _quickAdd(item, shopFor(item)),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: LuxTheme.primary,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Full merchant card — image, name, meta row.
  Widget _buildShopCard(Map<String, dynamic> shop) {
    final cuisines = (shop['cuisines'] as List<dynamic>? ?? []).join(' · ');
    return GestureDetector(
      onTap: () => showMenuSheet(
          context,
          shop,
          shopImages['${shop['name']}'] ??
              'https://images.unsplash.com/photo-1546173159-315724a31696?w=600&q=80'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: LuxTheme.surface),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              shopImages['${shop['name']}'] ??
                  'https://images.unsplash.com/photo-1546173159-315724a31696?w=600&q=80',
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  color: LuxTheme.primary.withOpacity(0.08),
                  child: const Icon(Icons.restaurant_rounded,
                      color: LuxTheme.primary, size: 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${shop['name']}',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: LuxTheme.textPrimary)),
                ),
                const Icon(Icons.star_rounded, color: LuxTheme.amber, size: 16),
                const SizedBox(width: 2),
                Text('${shop['rating']}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LuxTheme.textPrimary)),
              ]),
              const SizedBox(height: 6),
              Text(cuisines,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: LuxTheme.textSecondary)),
              const SizedBox(height: 10),
              Row(children: [
                _metaChip(Icons.schedule_rounded, '${shop['avg_prep_minutes']} min'),
                const SizedBox(width: 8),
                _metaChip(Icons.pedal_bike_rounded, '₦850 delivery'),
                const SizedBox(width: 8),
                _metaChip(Icons.circle, 'OPEN',
                    dot: true),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, {bool dot = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: LuxTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: dot ? LuxTheme.primary : LuxTheme.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: dot ? LuxTheme.primary : LuxTheme.textSecondary)),
        ]),
      );

  Widget _errorCard() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            const Icon(Icons.wifi_off_rounded, color: LuxTheme.error, size: 40),
            const SizedBox(height: 12),
            Text('Cannot reach Nature Fete servers.\nPull down to retry (first load can take a minute).',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
}
