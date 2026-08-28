import 'dart:convert';
import 'package:http/http.dart' as http;

/// REST client for the LuxFeast production API.
/// Base URL injected at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://luxefeast-api.onrender.com
class ApiService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static Uri _u(String path) => Uri.parse('$baseUrl/api$path');
  static const Map<String, String> _json = {'Content-Type': 'application/json'};

  static dynamic _decode(http.Response res) {
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(decoded is Map && decoded['message'] != null
          ? decoded['message']
          : 'Request failed (${res.statusCode})');
    }
    return decoded;
  }

  static Future<List<dynamic>> _getList(String path) async =>
      _decode(await http.get(_u(path))) as List<dynamic>;

  static Future<Map<String, dynamic>> _get(String path) async =>
      _decode(await http.get(_u(path))) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final res = await http.post(_u(path), headers: _json, body: jsonEncode(body ?? {}));
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(_u(path), headers: _json, body: jsonEncode(body));
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(_u(path), headers: _json, body: jsonEncode(body));
    return _decode(res) as Map<String, dynamic>;
  }

  // ------------------------------------------------------------ orders ---

  static Future<List<dynamic>> fetchOpenOrders(int shopId) =>
      _getList('/orders?shopId=$shopId&open=true');

  /// Past orders for the Earnings tab. Pass status: null | 'delivered' | 'cancelled' | 'rejected'.
  static Future<List<dynamic>> fetchOrderHistory(int shopId, {String? status}) =>
      _getList('/orders?shopId=$shopId${(status != null && status != 'all') ? '&status=$status' : ''}');

  /// Full order detail incl. event timeline + customer steps.
  static Future<Map<String, dynamic>> fetchOrderDetail(dynamic id) => _get('/orders/$id');

  static Future<Map<String, dynamic>> acceptOrder(dynamic id, {int prepMinutes = 20}) =>
      _post('/orders/$id/accept', {'prepMinutes': prepMinutes});

  static Future<Map<String, dynamic>> rejectOrder(dynamic id, {String? reason}) =>
      _post('/orders/$id/reject', {'reason': reason ?? 'Unable to fulfil'});

  static Future<Map<String, dynamic>> startPreparing(dynamic id) => _post('/orders/$id/preparing');

  static Future<Map<String, dynamic>> markReady(dynamic id) => _post('/orders/$id/ready');

  // ------------------------------------------------------ shop profile ---

  static Future<Map<String, dynamic>> fetchShop(int shopId) => _get('/shops/$shopId');

  static Future<Map<String, dynamic>> updateShop(int shopId, Map<String, dynamic> patch) =>
      _patch('/shops/$shopId', patch);

  // -------------------------------------------------------------- menu ---

  /// includeUnavailable=true → manager view (everything); false → what customers see.
  static Future<List<dynamic>> fetchMenu(int shopId, {bool includeUnavailable = false}) =>
      _getList('/shops/$shopId/menu${includeUnavailable ? '?includeUnavailable=1' : ''}');

  static Future<Map<String, dynamic>> addMenuItem(int shopId, Map<String, dynamic> item) =>
      _post('/shops/$shopId/menu', item);

  static Future<Map<String, dynamic>> updateMenuItem(
          int shopId, dynamic itemId, Map<String, dynamic> patch) =>
      _put('/shops/$shopId/menu/$itemId', patch);

  static Future<void> deleteMenuItem(int shopId, dynamic itemId) async =>
      _decode(await http.delete(_u('/shops/$shopId/menu/$itemId')));

  // ------------------------------------------------------------- stats ---

  static Future<Map<String, dynamic>> fetchStats(int shopId) => _get('/shops/$shopId/stats');
}
