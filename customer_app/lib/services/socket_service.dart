import 'package:socket_io_client/socket_io_client.dart' as io;

/// Customer real-time service — LuxFeast order choreography.
/// Set the backend URL at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://api.luxefeast.ng
class SocketService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static io.Socket? socket;

  static void connect({required int customerId}) {
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
}
