import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import 'order_tracking_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final List<Map<String, dynamic>> featuredShops = [
    {'name': 'Mama Nkem Amala Palace', 'cuisine': 'Amala • Ewedu • Gbegiri • Swallow & Soup', 'rating': 4.9, 'image': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&q=80'},
    {'name': 'Suya Palace Abuja', 'cuisine': 'Suya • Grilled • Nigerian Street Food', 'rating': 4.7, 'image': 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&q=80'},
    {'name': 'Jollof Republic Lagos', 'cuisine': 'Jollof Rice • Fried Rice • Nigerian Classic', 'rating': 4.8, 'image': 'https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?w=600&q=80'},
  ];

  @override
  void initState() {
    super.initState();
    SocketService.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxTheme.deepBlack,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 160,
              floating: true,
              backgroundColor: LuxTheme.deepBlack,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [LuxTheme.surface, LuxTheme.deepBlack], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('LuxFeast', style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w700, color: LuxTheme.gold)),
                        const SizedBox(height: 4),
                        Text('Premium Dining • Real-Time Tracking', style: GoogleFonts.inter(fontSize: 13, color: LuxTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: _buildSearchBar()),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: LuxTheme.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: LuxTheme.gold.withOpacity(0.2))),
                      child: const Icon(Icons.filter_alt_rounded, color: LuxTheme.gold, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text('Curated for You', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w600, color: LuxTheme.textPrimary)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.85),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ShopCard(shop: featuredShops[index], onOrder: () => _openOrder(context, featuredShops[index])),
                  childCount: featuredShops.length,
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openOrder(context, featuredShops[0]),
        backgroundColor: LuxTheme.gold,
        foregroundColor: LuxTheme.deepBlack,
        icon: const Icon(Icons.delivery_dining_rounded),
        label: const Text('Track Active Order', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSearchBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: LuxTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: LuxTheme.gold.withOpacity(0.15)),
    ),
    child: const Row(
      children: [
        Icon(Icons.search, color: LuxTheme.textSecondary, size: 20),
        SizedBox(width: 12),
        Expanded(child: Text('Search restaurants, cuisines...', style: TextStyle(color: LuxTheme.textSecondary, fontSize: 14))),
      ],
    ),
  );

  void _openOrder(BuildContext context, Map<String, dynamic> shop) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderTrackingScreen()));
  }
}

class _ShopCard extends StatelessWidget {
  final Map<String, dynamic> shop;
  final VoidCallback onOrder;
  const _ShopCard({required this.shop, required this.onOrder});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOrder,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: LuxTheme.surfaceElevated,
          border: Border.all(color: LuxTheme.gold.withOpacity(0.1)),
          image: DecorationImage(image: NetworkImage(shop['image'] as String), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.darken)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, LuxTheme.deepBlack.withOpacity(0.85)]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.star_rounded, color: LuxTheme.gold, size: 16),
                  const SizedBox(width: 4),
                  Text(shop['rating'].toString(), style: const TextStyle(color: LuxTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Text(shop['name'] as String, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: LuxTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(shop['cuisine'] as String, style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
