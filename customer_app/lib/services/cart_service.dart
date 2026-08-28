import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One line of the cart.
class CartItem {
  final int id;
  final String name;
  final double price;
  int quantity;
  CartItem({required this.id, required this.name, required this.price, required this.quantity});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'price': price, 'quantity': quantity};

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: int.tryParse('${j['id']}') ?? 0,
        name: '${j['name']}',
        price: (double.tryParse('${j['price']}') ?? 0),
        quantity: (int.tryParse('${j['quantity']}') ?? 1),
      );
}

/// Device-local cart — one shop at a time (Uber Eats / DoorDash pattern).
/// Persists to SharedPreferences so it survives app restarts.
class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  int? shopId;
  String? shopName;
  final List<CartItem> items = [];

  static const double deliveryFee = 850;
  static const double serviceFee = 200;

  bool get isEmpty => items.isEmpty;
  int get count => items.fold(0, (a, i) => a + i.quantity);
  double get subtotal => items.fold(0.0, (a, i) => a + i.price * i.quantity);
  double get total => subtotal + deliveryFee + serviceFee;

  CartItem? _find(int id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// Cart already holds items from a different shop?
  bool conflictsWith(int otherShopId) => !isEmpty && shopId != otherShopId;

  /// Adds an item (switches shop only when the caller cleared first).
  void addItem({
    required int shopId,
    required String shopName,
    required int itemId,
    required String name,
    required double price,
    int quantity = 1,
  }) {
    if (isEmpty || this.shopId != shopId) {
      items.clear();
      this.shopId = shopId;
      this.shopName = shopName;
    }
    final existing = _find(itemId);
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      items.add(CartItem(id: itemId, name: name, price: price, quantity: quantity));
    }
    _save();
  }

  void bump(int itemId, int delta) {
    final it = _find(itemId);
    if (it == null) return;
    it.quantity += delta;
    if (it.quantity <= 0) items.remove(it);
    if (items.isEmpty) {
      shopId = null;
      shopName = null;
    }
    _save();
  }

  /// How many of [itemId] are in the cart (0 if the cart belongs to another shop).
  int qtyOf(int shopId, int itemId) {
    if (this.shopId != shopId) return 0;
    return _find(itemId)?.quantity ?? 0;
  }

  void clear() {
    items.clear();
    shopId = null;
    shopName = null;
    _save();
  }

  /// Restores a saved cart at app start.
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('lf_cart');
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      shopId = int.tryParse('${j['shopId']}');
      shopName = j['shopName'] as String?;
      items
        ..clear()
        ..addAll(((j['items'] as List<dynamic>?) ?? [])
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {
      // corrupted cart → start fresh
      clear();
    }
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lf_cart', jsonEncode({
            'shopId': shopId,
            'shopName': shopName,
            'items': items.map((i) => i.toJson()).toList(),
          }));
    } catch (_) {}
  }
}

/// Postgres bigint ids arrive as strings in JSON ("16") — normalise once.
int idOf(dynamic v) => int.tryParse('$v') ?? 0;
