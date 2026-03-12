import 'dart:async';
import '../../../../core/network/socket_client.dart';
import '../models/notification_model.dart';

abstract class NotificationLocalDataSource {
  /// Listen to real-time notification events from Socket.IO
  Stream<NotificationModel> watchNotifications();

  /// Connect to socket
  Future<void> connect();

  /// Disconnect from socket
  void disconnect();
}

class NotificationLocalDataSourceImpl implements NotificationLocalDataSource {
  final SocketClient socketClient;
  final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();

  NotificationLocalDataSourceImpl(this.socketClient);

  @override
  Future<void> connect() async {
    if (!socketClient.isConnected) {
      await socketClient.connect();
    }

    // Listen for new notifications from Socket.IO
    socketClient.socket.on('new_notification', (data) {
      try {
        if (data is Map<String, dynamic>) {
          final notification = NotificationModel.fromJson(data);
          _notificationController.add(notification);
        }
      } catch (e) {
        print('Error parsing notification: $e');
      }
    });
  }

  @override
  Stream<NotificationModel> watchNotifications() {
    return _notificationController.stream;
  }

  @override
  void disconnect() {
    socketClient.socket.off('new_notification');
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
