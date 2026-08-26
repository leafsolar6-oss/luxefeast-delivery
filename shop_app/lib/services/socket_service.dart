import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static io.Socket? socket;

  static void connect() {
    socket = io.io('http://localhost:5000', <String, dynamic>{ 'transports': ['websocket'], 'autoConnect': true });
  }

  static void emitStatusUpdate(String orderId, String status) {
    socket?.emit('update-order-status', { 'orderId': orderId, 'status': status });
  }

  static void disconnect() => socket?.disconnect();
}
