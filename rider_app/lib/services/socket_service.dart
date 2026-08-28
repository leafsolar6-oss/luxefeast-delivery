import 'package:socket_io_client/socket_io_client.dart' as io;

/// Rider real-time service — LuxFeast order choreography.
/// Set the backend URL at build time:
///   flutter build apk --dart-define=API_BASE_URL=https://api.luxefeast.ng
class SocketService {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static io.Socket? socket;

  static void connect({required int riderId}) {
    socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
    });
    socket?.onConnect((_) {
      socket?.emit('register', {'role': 'rider', 'id': riderId});
    });
  }

  /// Dispatch: new deliveries offered to all available riders.
  static void onDeliveryOffer(Function(dynamic) cb) => socket?.on('delivery:offer', cb);

  /// Another rider claimed it — remove from the offer list.
  static void onDeliveryTaken(Function(dynamic) cb) => socket?.on('delivery:taken', cb);

  /// This rider won the claim (also mirrored to customer & shop).
  static void onAssignedConfirmed(Function(dynamic) cb) => socket?.on('rider:assigned', cb);

  /// Kitchen finished — go pick it up.
  static void onOrderReady(Function(dynamic) cb) => socket?.on('order:ready', cb);

  /// Delivery completed — payout notification.
  static void onOrderDelivered(Function(dynamic) cb) => socket?.on('order:delivered', cb);

  /// Order cancelled while assigned.
  static void onOrderCancelled(Function(dynamic) cb) => socket?.on('order:cancelled', cb);

  /// Stream live GPS so the customer's tracking map moves.
  static void sendLocation({required dynamic orderId, required int riderId, required double lat, required double lng}) {
    socket?.emit('rider:location', {'orderId': orderId, 'riderId': riderId, 'lat': lat, 'lng': lng});
  }

  static void disconnect() => socket?.disconnect();
}
