import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/session.dart';
import '../services/socket_service.dart';
import 'auth_screen.dart';
import 'order_tracking_screen.dart';

/// The cart: review items, adjust quantities, place the order.
/// Browsing and adding to the cart needs no account — signing in is
/// only required at checkout.
Future<void> showCartSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: LuxTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const CartSheet(),
  );
}

class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  static const String deliveryAddress = '4 Fola Osibo Rd, Lekki Phase 1, Lagos';
  bool placing = false;

  Future<void> _placeOrder() async {
    final cart = CartService.instance;
    if (cart.isEmpty || placing) return;

    // ---- account gate: order only with a verified account ----
    if (!Session.isLoggedIn) {
      final signedIn = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (ctx) => AuthScreen(
          role: 'customer',
          title: 'Sign in to place your order',
          onAuthed: () => Navigator.of(ctx).pop(true),
        ),
      ));
      if (signedIn != true || !Session.isLoggedIn) return; // user backed out
      // Now we have a session — live order events need the real customer room.
      SocketService.connect(customerId: Session.userId);
      SocketService.attachOrderNotifications();
    }

    setState(() => placing = true);
    try {
      final order = await ApiService.placeOrder(
        customerId: Session.userId,
        shopId: cart.shopId,
        items: cart.items
            .map((i) => {'name': i.name, 'price': i.price, 'quantity': i.quantity})
            .toList(),
        deliveryAddress: deliveryAddress,
      );
      cart.clear();
      if (!mounted) return;
      // Back to home, then straight into live tracking.
      Navigator.of(context).popUntil((r) => r.isFirst);
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
    final h = MediaQuery.of(context).size.height * 0.78;
    return SizedBox(
      height: h,
      child: ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) {
          final cart = CartService.instance;
          return Column(children: [
            const SizedBox(height: 10),
            Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                    color: LuxTheme.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Expanded(
                    child: Text('Your cart',
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: LuxTheme.textPrimary))),
                IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: LuxTheme.textSecondary, size: 22),
                    onPressed: cart.isEmpty ? null : () => cart.clear()),
              ]),
            ),
            Expanded(
              child: cart.isEmpty
                  ? _buildEmpty()
                  : _buildItems(cart),
            ),
            _buildFooter(cart),
          ]);
        },
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.shopping_bag_outlined, color: LuxTheme.gold, size: 40),
          const SizedBox(height: 12),
          Text('Your cart is empty.\nBrowse a restaurant and add something delicious.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: LuxTheme.textSecondary, fontSize: 13)),
        ]),
      );

  Widget _buildItems(CartService cart) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      itemCount: cart.items.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              const Icon(Icons.storefront_rounded, color: LuxTheme.gold, size: 16),
              const SizedBox(width: 8),
              Text(cart.shopName ?? '',
                  style: GoogleFonts.inter(
                      color: LuxTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ]),
          );
        }
        final item = cart.items[i - 1];
        final line = item.price * item.quantity;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: LuxTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LuxTheme.gold.withOpacity(0.1)),
          ),
          child: Row(children: [
            Expanded(
                child: Text(item.name,
                    style: const TextStyle(
                        color: LuxTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14))),
            _stepBtn(Icons.remove_rounded, () => cart.bump(item.id, -1)),
            SizedBox(
              width: 30,
              child: Text('${item.quantity}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: LuxTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
            _stepBtn(Icons.add_rounded, () => cart.bump(item.id, 1)),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: Text('₦${_fmt(line)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      color: LuxTheme.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ]),
        );
      },
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LuxTheme.gold.withOpacity(0.15),
              border: Border.all(color: LuxTheme.gold.withOpacity(0.5))),
          child: Icon(icon, color: LuxTheme.gold, size: 15),
        ),
      );

  Widget _buildFooter(CartService cart) {
    final enabled = !cart.isEmpty && !placing;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 14, 24,
          MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: LuxTheme.surfaceElevated,
        border: Border(top: BorderSide(color: LuxTheme.gold.withOpacity(0.15))),
      ),
      child: cart.isEmpty
          ? const SizedBox.shrink()
          : Column(mainAxisSize: MainAxisSize.min, children: [
              _feeRow('Subtotal', cart.subtotal),
              _feeRow('Delivery fee', CartService.deliveryFee),
              _feeRow('Service fee', CartService.serviceFee),
              const SizedBox(height: 8),
              Row(children: [
                Text('Total',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: LuxTheme.textPrimary)),
                const Spacer(),
                Text('₦${_fmt(cart.total)}',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.bold, color: LuxTheme.gold)),
              ]),
              const SizedBox(height: 4),
              Text(
                  Session.isLoggedIn
                      ? 'Ordering as ${Session.name}'
                      : 'You\'ll sign in to place this order',
                  style: GoogleFonts.inter(
                      color: LuxTheme.textSecondary, fontSize: 11)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: enabled ? _placeOrder : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: enabled ? LuxTheme.gold : LuxTheme.surface),
                  icon: placing
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: LuxTheme.deepBlack))
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(placing
                      ? 'Placing order…'
                      : (Session.isLoggedIn ? 'Place order' : 'Sign in & order')),
                ),
              ),
            ]),
    );
  }

  Widget _feeRow(String label, double value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text(label,
              style: const TextStyle(color: LuxTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          Text('₦${_fmt(value)}',
              style: const TextStyle(color: LuxTheme.textPrimary, fontSize: 12)),
        ]),
      );
}

String _fmt(double n) =>
    n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(0);
