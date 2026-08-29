import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';
import '../services/popup_notifier.dart';

/// Firebase Cloud Messaging — real device notifications, delivered even when
/// the app is backgrounded or killed.
///
/// v4.1: registration is now RETRIED automatically and every outcome is
/// announced with a visible banner — no more silent failures.
class PushService {
  static bool enabled = false;
  static String? _token;
  static bool _registeredOk = false;
  static bool _announced = false;
  static int _getTokenAttempts = 0;
  static Timer? _retryTimer;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'orders';

  // MUST be const — non-const String.fromEnvironment ignores --dart-define
  // in AOT builds and falls back to the emulator default (the bug that
  // silently killed push registration on real phones).
  static const String _baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static void _announce(String title, String message, {bool error = false}) {
    if (_announced && !error) return; // success banner only once per session
    // (announced flag is set once the banner actually renders)
    _announceRetry(title, message, error: error, attempt: 0);
  }

  static void _announceRetry(String title, String message,
      {required bool error, required int attempt}) {
    if (PopupNotifier.navigatorKey.currentContext == null && attempt < 8) {
      Timer(const Duration(milliseconds: 600),
          () => _announceRetry(title, message, error: error, attempt: attempt + 1));
      return;
    }
    PopupNotifier.banner(
      title: title,
      message: message,
      icon: error ? Icons.warning_rounded : Icons.notifications_active_rounded,
      color: error ? const Color(0xFFE5484D) : const Color(0xFF008050),
      duration: const Duration(seconds: 4),
    );
    _announced = true;
  }

  static Future<void> init() async {
    if (enabled || Session.token == null) return;
    try {
      await Firebase.initializeApp()
          .timeout(const Duration(seconds: 12));
      final messaging = FirebaseMessaging.instance;

      await messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 10))
          .catchError((_) {});

      await _notifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            'Orders',
            description: 'Order status updates',
            importance: Importance.max,
            playSound: true,
            showBadge: true,
          ));

      // Attach the refresh listener BEFORE the first getToken — devices that
      // aren't ready yet will deliver the token here.
      messaging.onTokenRefresh.listen((t) {
        _token = t;
        _register(t);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      messaging.getInitialMessage().then((m) {
        if (m != null) _handleTap(m);
      });

      final token = await messaging.getToken()
          .timeout(const Duration(seconds: 15));
      if (token == null) {
        // Device not ready yet (Play Services still booting) — retry shortly.
        _getTokenAttempts++;
        if (_getTokenAttempts <= 4) {
          Timer(const Duration(seconds: 25), init);
        } else {
          _announce('Push not available', 'Device did not provide a token',
              error: true);
        }
        return;
      }

      _token = token;
      _registeredOk = await _register(token);
      enabled = true;

      if (_registeredOk) {
        _announce('🔔 Notifications on',
            'Delivery offers will reach you even when the app is closed.');
      } else {
        _announce('Push registered offline',
            'The device token couldn\'t reach the server yet — retrying.',
            error: true);
        _scheduleRegisterRetry();
      }
      debugPrint('[push] ready, registered=$_registeredOk');
    } catch (e) {
      debugPrint('[push] disabled: $e');
      _announce('Push error', e.toString().replaceAll('Exception: ', ''),
          error: true);
    }
  }

  /// Retry the server registration until it sticks (network blips etc.).
  static void _scheduleRegisterRetry() {
    _retryTimer?.cancel();
    var tries = 0;
    _retryTimer = Timer.periodic(const Duration(seconds: 90), (t) async {
      if (_token == null || Session.token == null || _registeredOk) {
        t.cancel();
        return;
      }
      tries++;
      _registeredOk = await _register(_token!);
      if (_registeredOk || tries > 5) t.cancel();
    });
  }

  /// Tapping a notification opens the app straight to the dashboard, where
  /// live data is waiting — nothing extra to route.
  static void _handleTap(RemoteMessage message) {
    debugPrint('[push] opened from notification');
  }

  static Future<bool> _register(String token) async {
    if (Session.token == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/auth/device-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.token}',
        },
        body: jsonEncode({'token': token, 'platform': 'android'}),
      );
      debugPrint('[push] register → HTTP ${res.statusCode}');
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('[push] register failed: $e');
      return false;
    }
  }

  /// Call on logout (BEFORE clearing the session).
  static Future<void> unregister() async {
    _retryTimer?.cancel();
    final token = _token;
    if (token != null && Session.token != null) {
      try {
        final req = http.Request(
            'DELETE', Uri.parse('$_baseUrl/api/auth/device-token'))
          ..headers['Content-Type'] = 'application/json'
          ..headers['Authorization'] = 'Bearer ${Session.token}'
          ..body = jsonEncode({'token': token});
        await req.send();
      } catch (_) {}
    }
    _token = null;
    _registeredOk = false;
    enabled = false;
    _announced = false;
  }
}
