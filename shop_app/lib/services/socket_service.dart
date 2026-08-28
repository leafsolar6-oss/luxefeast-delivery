import 'package:socket_io_client/socket_io_client.dart' as io;

/// Shop real-time service — LuxFeast order choreography.
/// Set the backend URL at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://api.luxefeast.ng
class SocketService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static io.Socket? socket;

  static void connect({required int shopId}) {
    socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
    });
    socket?.onConnect((_) {
      socket?.emit('register', {'role': 'shop', 'id': shopId});
    });
  }

  /// Everything the shop must be alerted about:
  static void onNewOrder(Function(dynamic) cb) => socket?.on('order:placed', cb);
  static void onRiderAssigned(Function(dynamic) cb) => socket?.on('rider:assigned', cb);
  static void onRiderAtShop(Function(dynamic) cb) => socket?.on('rider:at_shop', cb);
  static void onOrderPickedUp(Function(dynamic) cb) => socket?.on('order:picked_up', cb);
  static void onOrderDelivered(Function(dynamic) cb) => socket?.on('order:delivered', cb);
  static void onOrderCancelled(Function(dynamic) cb) => socket?.on('order:cancelled', cb);

  static void disconnect() => socket?.disconnect();
}
