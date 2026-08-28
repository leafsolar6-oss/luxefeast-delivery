import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted login session (JWT + user profile).
class Session {
  static Map<String, dynamic>? user;
  static String? token;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('lf_token');
    final u = p.getString('lf_user');
    user = u != null ? jsonDecode(u) as Map<String, dynamic> : null;
  }

  static Future<void> save(String t, Map<String, dynamic> u) async {
    final p = await SharedPreferences.getInstance();
    token = t;
    user = u;
    await p.setString('lf_token', t);
    await p.setString('lf_user', jsonEncode(u));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    token = null;
    user = null;
    await p.remove('lf_token');
    await p.remove('lf_user');
  }

  static bool get isLoggedIn => token != null && user != null;

  static int get userId => int.tryParse('${user?['id']}') ?? 0;

  /// shops.id / riders.id for shop & rider accounts.
  static int get entityId => int.tryParse('${user?['entityId']}') ?? 0;

  static String get name => user?['name'] ?? '';
}
