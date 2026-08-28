import 'dart:convert';
import 'package:http/http.dart' as http;

/// REST client for the LuxFeast production API.
/// Base URL injected at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://luxefeast-api.onrender.com
class ApiService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static Uri _u(String path) => Uri.parse('$baseUrl/api$path');

  static Future<List<dynamic>> _getList(String path) async {
    final res = await http.get(_u(path));
    if (res.statusCode != 200) throw Exception('Request failed (${res.statusCode})');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(_u(path),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body ?? {}));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(decoded['message'] ?? 'Request failed');
    return decoded;
  }

  /// Dispatch feed: unclaimed deliveries.
  static Future<List<dynamic>> availableDeliveries() => _getList('/orders/available-deliveries');

  /// This rider's active (not yet delivered) orders.
  static Future<List<dynamic>> myActiveOrders(int riderId) =>
      _getList('/orders?riderId=$riderId&open=true');

  static Future<Map<String, dynamic>> earnings(int riderId) async {
    final res = await http.get(_u('/riders/$riderId/earnings'));
    if (res.statusCode != 200) throw Exception('Failed to load earnings');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Delivery workflow — mirrors the international-standard lifecycle.
  static Future<Map<String, dynamic>> claim(dynamic orderId, int riderId) =>
      _post('/orders/$orderId/claim', {'riderId': riderId});
  static Future<Map<String, dynamic>> arriveShop(dynamic orderId) =>
      _post('/orders/$orderId/arrive-shop');
  static Future<Map<String, dynamic>> pickup(dynamic orderId, int riderId) =>
      _post('/orders/$orderId/pickup', {'riderId': riderId});
  static Future<Map<String, dynamic>> startTransit(dynamic orderId) =>
      _post('/orders/$orderId/in-transit');
  static Future<Map<String, dynamic>> arriveCustomer(dynamic orderId) =>
      _post('/orders/$orderId/arrive-customer');
  static Future<Map<String, dynamic>> deliver(dynamic orderId) =>
      _post('/orders/$orderId/deliver');
}
