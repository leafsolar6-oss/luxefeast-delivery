import 'dart:convert';
import 'package:http/http.dart' as http;

/// REST client for the LuxFeast production API.
/// Base URL is injected at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://luxefeast-api.onrender.com
class ApiService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static Uri _u(String path) => Uri.parse('$baseUrl/api$path');

  static Future<List<dynamic>> fetchOpenOrders(int shopId) async {
    final res = await http.get(_u('/orders?shopId=$shopId&open=true'));
    if (res.statusCode != 200) throw Exception('Failed to load orders (${res.statusCode})');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      _u(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(decoded['message'] ?? 'Request failed');
    return decoded;
  }

  static Future<Map<String, dynamic>> acceptOrder(dynamic id, {int prepMinutes = 20}) =>
      _post('/orders/$id/accept', {'prepMinutes': prepMinutes});
  static Future<Map<String, dynamic>> rejectOrder(dynamic id, {String? reason}) =>
      _post('/orders/$id/reject', {'reason': reason ?? 'Unable to fulfil'});
  static Future<Map<String, dynamic>> startPreparing(dynamic id) => _post('/orders/$id/preparing');
  static Future<Map<String, dynamic>> markReady(dynamic id) => _post('/orders/$id/ready');
}
