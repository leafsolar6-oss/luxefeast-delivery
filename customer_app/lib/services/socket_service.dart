import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../theme/app_theme.dart';
import 'popup_notifier.dart';
import '../screens/order_tracking_screen.dart';

/// Customer real-time service — LuxFeast order choreography.
/// Set the backend URL at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://api.luxefeast.ng
class SocketService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static io.Socket? socket;

  /// The order whose tracking screen is open — suppresses duplicate popups
  /// (the screen itself shows those updates live).
  static dynamic activeTrackingOrderId;

  static bool _popupsAttached = false;

  static void connect({required int customerId}) {
    socket?.disconnect(); // never leak a second live socket
    _popupsAttached = false;
    socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
    });
    socket?.onConnect((_) {
      socket?.emit('register', {'role': 'customer', 'id': customerId});
    });
  }

  static void joinOrder(dynamic orderId) => socket?.emit('join-order', orderId);
  static void leaveOrder(dynamic orderId) => socket?.emit('leave-order', orderId);

  /// Everything the customer must be alerted about, per the lifecycle:
  static void onOrderAccepted(Function(dynamic) cb) => socket?.on('order:accepted', cb);
  static void onOrderRejected(Function(dynamic) cb) => socket?.on('order:rejected', cb);
  static void onOrderPreparing(Function(dynamic) cb) => socket?.on('order:preparing', cb);
  static void onOrderReady(Function(dynamic) cb) => socket?.on('order:ready', cb);
  static void onRiderAssigned(Function(dynamic) cb) => socket?.on('rider:assigned', cb);
  static void onRiderAtShop(Function(dynamic) cb) => socket?.on('rider:at_shop', cb);
  static void onOrderPickedUp(Function(dynamic) cb) => socket?.on('order:picked_up', cb);
  static void onOrderInTransit(Function(dynamic) cb) => socket?.on('order:in_transit', cb);
  static void onRiderLocation(Function(dynamic) cb) => socket?.on('rider:location', cb);
  static void onOrderArrived(Function(dynamic) cb) => socket?.on('order:arrived', cb);
  static void onOrderDelivered(Function(dynamic) cb) => socket?.on('order:delivered', cb);
  static void onOrderCancelled(Function(dynamic) cb) => socket?.on('order:cancelled', cb);

  static void disconnect() => socket?.disconnect();

  /// Wire every order event to a pop-up banner (fires app-wide, on any
  /// screen, while the app is in the foreground).
  static void attachOrderNotifications() {
    if (_popupsAttached || socket == null) return;
    _popupsAttached = true;

    void popup(String event, String title, IconData icon, Color color,
        {bool sound = false}) {
      socket!.on(event, (data) {
        final order =
            data is Map && data['order'] is Map ? data['order'] as Map : null;
        final id = order?['id'];
        if (id != null && '$id' == '$activeTrackingOrderId') return;
        PopupNotifier.banner(
          title: title,
          message: '${data is Map ? (data['message'] ?? '') : ''}',
          icon: icon,
          color: color,
          sound: sound,
          onTap: id == null
              ? null
              : () => PopupNotifier.navigatorKey.currentState?.push(MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(
                        orderId: id,
                        initialOrder:
                            order?.cast<String, dynamic>()),
                  )),
        );
      });
    }

    popup('order:accepted', 'Order accepted 🎉', Icons.check_circle_rounded, LuxTheme.primary, sound: true);
    popup('order:rejected', 'Order rejected', Icons.cancel_rounded, LuxTheme.error);
    popup('order:preparing', 'Being prepared 👨‍🍳', Icons.restaurant_rounded, LuxTheme.primary);
    popup('order:ready', 'Ready for pickup 📦', Icons.inventory_2_rounded, LuxTheme.primaryLight);
    popup('rider:assigned', 'Rider assigned 🏍️', Icons.sports_motorsports_rounded, LuxTheme.primary, sound: true);
    popup('order:picked_up', 'Rider picked up your order', Icons.directions_bike_rounded, LuxTheme.primaryLight);
    popup('order:in_transit', 'On the way 🛵', Icons.delivery_dining_rounded, LuxTheme.primaryLight);
    popup('order:arrived', 'Rider has arrived 📍', Icons.location_on_rounded, LuxTheme.success, sound: true);
    popup('order:delivered', 'Delivered — enjoy! 🎉', Icons.emoji_events_rounded, LuxTheme.success, sound: true);
    popup('order:cancelled', 'Order cancelled', Icons.cancel_rounded, LuxTheme.error);
  }
}
