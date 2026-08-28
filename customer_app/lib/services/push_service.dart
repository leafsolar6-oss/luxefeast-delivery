import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../services/session.dart';
import '../services/popup_notifier.dart';
import '../screens/order_tracking_screen.dart';

/// Firebase Cloud Messaging — real device notifications, delivered even when
/// the app is backgrounded or killed.
///
/// Gracefully disabled (never crashes, never blocks the app) when:
///  - Firebase isn't configured yet (placeholder google-services.json), or
///  - the user isn't logged in (device tokens are tied to accounts).
class PushService {
  static bool enabled = false;
  static String? _token;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'orders';

  static String get _baseUrl =>
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static Future<void> init() async {
    if (enabled || Session.token == null) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      // Android 13+ / iOS permission prompt.
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Notification channel — matches AndroidManifest + the server's channelId.
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
          ));

      // Foreground messages are NOT shown by the OS — and our socket-driven
      // pop-ups already alert while the app is open, so nothing to do here.
      // Background/killed: the system tray shows the notification by itself.

      // Tapping a notification (app in background) → open live tracking.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      // Tapping a notification that cold-started the app.
      messaging.getInitialMessage().then((m) {
        if (m != null) _handleTap(m);
      });

      final token = await messaging.getToken();
      if (token != null) {
        _token = token;
        await _register(token);
        messaging.onTokenRefresh.listen(_register);
        enabled = true;
        debugPrint('[push] FCM ready');
      }
    } catch (e) {
      debugPrint('[push] disabled: $e');
    }
  }

  static void _handleTap(RemoteMessage message) {
    final orderId = message.data['orderId'];
    if (orderId == null) return;
    PopupNotifier.navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => OrderTrackingScreen(orderId: orderId),
    ));
  }

  static Future<void> _register(String token) async {
    if (Session.token == null) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/auth/device-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Session.token}',
        },
        body: jsonEncode({'token': token, 'platform': 'android'}),
      );
    } catch (_) {/* offline — token refreshes will retry */}
  }

  /// Call on logout (BEFORE clearing the session).
  static Future<void> unregister() async {
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
    enabled = false;
  }
}
