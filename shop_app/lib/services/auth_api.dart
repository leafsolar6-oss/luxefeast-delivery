import 'dart:convert';
import 'package:http/http.dart' as http;

/// Auth endpoints — register, verify (email + SMS OTP), login, me.
class AuthApi {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static Uri _u(String p) => Uri.parse('$baseUrl/api/auth$p');

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(_u(path),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 && decoded['needsVerification'] != true) {
      throw Exception(decoded['message'] ?? 'Request failed');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    String? shopName,
  }) =>
      _post('/register', {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
        if (shopName != null) 'shopName': shopName,
      });

  static Future<Map<String, dynamic>> login(String identifier, String password) =>
      _post('/login', {'identifier': identifier, 'password': password});

  static Future<Map<String, dynamic>> verify(dynamic userId, String channel, String code) =>
      _post('/verify', {'userId': userId, 'channel': channel, 'code': code});

  static Future<Map<String, dynamic>> resend(dynamic userId, String channel) =>
      _post('/resend', {'userId': userId, 'channel': channel});

  static Future<Map<String, dynamic>?> me(String token) async {
    try {
      final res = await http.get(_u('/me'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['user'] as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
