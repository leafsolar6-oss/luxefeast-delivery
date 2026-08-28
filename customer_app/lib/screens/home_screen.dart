import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/session.dart';
import '../services/cart_service.dart';
import '../services/push_service.dart';
import 'cart_sheet.dart';
import 'auth_screen.dart';
import 'menu_sheet.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  List<Map<String, dynamic>> shops = [];
  bool loading = true;
  String? error;

  static const Map<String, String> shopImages = {
    'Nature Fete': 'https://images.unsplash.com/photo-1546173159-315724a31696?w=600&q=80',
    'Jollof Republic Lagos': 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=600&q=80',
    'Suya Palace Abuja': 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&q=80',
  };

  @override
  void initState() {
    super.initState();
    if (Session.isLoggedIn) {
      SocketService.connect(customerId: Session.userId);
      SocketService.attachOrderNotifications();
    }
    _loadShops();
  }

  /// Guest → sign in (stays browsing afterwards); user → logout.
  Future<void> _accountAction() async {
    if (!Session.isLoggedIn) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => AuthScreen(
          role: 'customer',
          title: 'Premium Dining • Delivered',
          onAuthed: () => Navigator.of(ctx).pop(true),
        ),
      ));
      if (!mounted) return;
      if (Session.isLoggedIn) {
        SocketService.connect(customerId: Session.userId);
        SocketService.attachOrderNotifications();
        PushService.init();
        setState(() {});
      }
      return;
    }
    final logout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LuxTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Log out?',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
        content: Text('You can keep browsing and ordering after signing back in.',
            style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay',
                  style: TextStyle(color: LuxTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out', style: TextStyle(color: LuxTheme.error))),
        ],
      ),
    );
    if (logout == true) {
      await PushService.unregister();
      await Session.clear();
      SocketService.disconnect();
      setState(() {});
    }
  }

  Future<void> _loadShops() async {
    try {
      final data = await ApiService.fetchShops();
      if (!mounted) return;
      setState(() {
        shops = data.cast<Map<String, dynamic>>();
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  /// Tap a restaurant → browse its LIVE menu (managed by the shop in their app).
  void _orderFrom(Map<String, dynamic> shop) {
    showMenuSheet(
      context,
      shop,
      shopImages[shop['name']] ??
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      body: SafeArea(
        child: RefreshIndicator(
          color: LuxTheme.gold,
          backgroundColor: LuxTheme.surfaceElevated,
          onRefresh: _loadShops,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 160,
                floating: true,
                backgroundColor: LuxTheme.deepBlack,
                actions: [
                  ListenableBuilder(
                    listenable: CartService.instance,
                    builder: (context, _) {
                      final count = CartService.instance.count;
                      return IconButton(
                        icon: Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: LuxTheme.gold,
                          textColor: LuxTheme.deepBlack,
                          child: const Icon(Icons.shopping_bag_outlined,
                              color: LuxTheme.textPrimary),
                        ),
                        onPressed: () => showCartSheet(context),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                        Session.isLoggedIn
                            ? Icons.logout_rounded
                            : Icons.person_outline_rounded,
                        color: LuxTheme.textSecondary),
                    onPressed: _accountAction,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [LuxTheme.surface, LuxTheme.deepBlack],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Nature Fete',
                              style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: LuxTheme.gold)),
                          const SizedBox(height: 4),
                          Text(
                              Session.isLoggedIn
                                  ? 'Welcome back, ${Session.name.split(' ').first} ✨'
                                  : 'Browse menus · sign in to order ✨',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: LuxTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                sliver: SliverToBoxAdapter(
                  child: Text('Fresh From Our Kitchen',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: LuxTheme.textPrimary)),
                ),
              ),
              if (loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator(color: LuxTheme.gold)),
                  ),
                )
              else if (error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: LuxTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(children: [
                        const Icon(Icons.wifi_off_rounded, color: LuxTheme.error, size: 36),
                        const SizedBox(height: 12),
                        Text(
                            'Cannot reach Nature Fete servers.\nPull down to retry (first load can take a minute).',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: LuxTheme.textSecondary, fontSize: 13)),
                      ]),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _ShopCard(
                        shop: shops[i],
                        image: shopImages[shops[i]['name']] ??
                            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&q=80',
                        onOrder: () => _orderFrom(shops[i]),
                      ),
                      childCount: shops.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final String image;
  final VoidCallback onOrder;
  const _ShopCard(
      {required this.shop, required this.image, required this.onOrder});

  @override
  Widget build(BuildContext context) {
    final cuisines = (shop['cuisines'] as List<dynamic>? ?? []).join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: LuxTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LuxTheme.gold.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Image.network(
            image,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                height: 150,
                color: LuxTheme.surface,
                child: const Icon(Icons.restaurant, color: LuxTheme.gold, size: 40)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(shop['name'] ?? '',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: LuxTheme.textPrimary)),
              ),
              const Icon(Icons.star_rounded, color: LuxTheme.gold, size: 18),
              const SizedBox(width: 2),
              Text('${shop['rating']}',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: LuxTheme.gold, fontSize: 14)),
            ]),
            const SizedBox(height: 6),
            Text(cuisines,
                style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_rounded, color: LuxTheme.textSecondary, size: 14),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(shop['address'] ?? '',
                      style:
                          GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 11))),
              Text('~${shop['avg_prep_minutes']} min',
                  style: GoogleFonts.inter(color: LuxTheme.gold, fontSize: 11)),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onOrder,
                style: ElevatedButton.styleFrom(
                    backgroundColor: LuxTheme.gold, foregroundColor: LuxTheme.deepBlack),
                icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                label: const Text('Browse Menu & Order',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
