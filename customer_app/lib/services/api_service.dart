import 'dart:convert';
import 'package:http/http.dart' as http;

/// REST client for the LuxFeast production API.
/// Base URL injected at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://luxefeast-api.onrender.com
class ApiService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static Uri _u(String path) => Uri.parse('$baseUrl/api$path');

  static Future<List<dynamic>> fetchShops() async {
    final res = await http.get(_u('/shops'));
    if (res.statusCode != 200) throw Exception('Failed to load shops (${res.statusCode})');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> placeOrder({
    required int customerId,
    required dynamic shopId,
    required List<Map<String, dynamic>> items,
    required String deliveryAddress,
  }) async {
    final res = await http.post(
      _u('/orders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customerId': customerId,
        'shopId': shopId,
        'items': items,
        'deliveryAddress': deliveryAddress,
        'paymentGateway': 'paystack',
      }),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(decoded['message'] ?? 'Order failed');
    return decoded;
  }

  static Future<Map<String, dynamic>> fetchOrder(dynamic id) async {
    final res = await http.get(_u('/orders/$id'));
    if (res.statusCode != 200) throw Exception('Order not found');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
