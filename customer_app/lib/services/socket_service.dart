import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static io.Socket? socket;

  static void connect() {
    socket = io.io('http://localhost:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    socket?.onConnect((_) => print('Socket connected'));
    socket?.onDisconnect((_) => print('Socket disconnected'));
  }

  static void joinOrder(String orderId) {
    socket?.emit('join-order', orderId);
  }

  static void listenStatusUpdated(Function(dynamic) onUpdate) {
    socket?.on('order-status-updated', (data) => onUpdate(data));
  }

  static void listenRiderAssigned(Function(dynamic) onAssign) {
    socket?.on('rider-assigned', (data) => onAssign(data));
  }

  static void disconnect() => socket?.disconnect();
}
