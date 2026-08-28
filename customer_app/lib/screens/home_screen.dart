import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'order_tracking_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const int customerId = 1; // Amara Okonkwo (demo login)
  static const String deliveryAddress = '4 Fola Osibo Rd, Lekki Phase 1, Lagos';

  List<Map<String, dynamic>> shops = [];
  bool loading = true;
  String? error;
  bool placing = false;

  static const Map<String, String> shopImages = {
    'Mama Nkem Amala Palace': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&q=80',
    'Jollof Republic Lagos': 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=600&q=80',
    'Suya Palace Abuja': 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&q=80',
  };

  static const Map<String, List<Map<String, dynamic>>> signatureMenu = {
    'Mama Nkem Amala Palace': [
      {'name': 'Amala + Ewedu & Gbegiri', 'quantity': 1, 'price': 3500},
      {'name': 'Assorted Goat Meat', 'quantity': 1, 'price': 2000},
    ],
    'Jollof Republic Lagos': [
      {'name': 'Party Jollof + Chicken', 'quantity': 1, 'price': 4200},
      {'name': 'Dodo (Fried Plantain)', 'quantity': 1, 'price': 1200},
    ],
    'Suya Palace Abuja': [
      {'name': 'Beef Suya (Full Stick)', 'quantity': 2, 'price': 2500},
      {'name': 'Masa + Yaji', 'quantity': 1, 'price': 1500},
    ],
  };

  @override
  void initState() {
    super.initState();
    SocketService.connect(customerId: customerId);
    _loadShops();
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

  Future<void> _orderFrom(Map<String, dynamic> shop) async {
    if (placing) return;
    setState(() => placing = true);
    try {
      final items = signatureMenu[shop['name']] ??
          [{'name': 'Chef Special', 'quantity': 1, 'price': 4000}];
      final order = await ApiService.placeOrder(
        customerId: customerId,
        shopId: shop['id'],
        items: items,
        deliveryAddress: deliveryAddress,
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: order['id'], initialOrder: order),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: LuxTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => placing = false);
    }
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
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [LuxTheme.surface, LuxTheme.deepBlack],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('LuxFeast',
                              style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: LuxTheme.gold)),
                          const SizedBox(height: 4),
                          Text('Premium Dining • Real-Time Tracking',
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
                  child: Text('Featured Restaurants',
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
                            'Cannot reach LuxFeast servers.\nPull down to retry (first load can take a minute).',
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
                        busy: placing,
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
  final bool busy;
  final VoidCallback onOrder;
  const _ShopCard(
      {required this.shop, required this.image, required this.busy, required this.onOrder});

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
                onPressed: busy ? null : onOrder,
                style: ElevatedButton.styleFrom(
                    backgroundColor: LuxTheme.gold, foregroundColor: LuxTheme.deepBlack),
                icon: const Icon(Icons.local_mall_rounded, size: 18),
                label: Text(busy ? 'Placing order…' : 'Order Signature Meal',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
