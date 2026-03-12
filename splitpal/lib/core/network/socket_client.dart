import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../utils/token_manager.dart';

class SocketClient {
  late IO.Socket _socket;
  final TokenManager _tokenManager;
  bool _isConnected = false;
  bool _isInitialized = false;

  SocketClient({required TokenManager tokenManager})
    : _tokenManager = tokenManager;

  IO.Socket get socket => _socket;
  bool get isConnected => _isConnected;

  // Connect to socket with authentication
  Future<void> connect() async {
    final token = await _tokenManager.getToken();

    if (token == null) {
      throw Exception('No authentication token found');
    }

    _socket = IO.io(
      ApiConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _isInitialized = true;

    _socket.onConnect((_) {
      _isConnected = true;
    });

    _socket.onDisconnect((_) {
      _isConnected = false;
    });

    _socket.onError((_) {});

    _socket.connect();
  }

  // Disconnect socket
  void disconnect() {
    if (_isConnected) {
      _socket.disconnect();
      _isConnected = false;
    }
  }

  // Join group
  void joinGroup(String groupId) {
    if (_isConnected) {
      _socket.emit(AppConstants.socketJoinGroup, groupId);
    }
  }

  // Leave group
  void leaveGroup(String groupId) {
    if (_isConnected) {
      _socket.emit(AppConstants.socketLeaveGroup, groupId);
    }
  }

  // Send message
  void sendMessage({
    required String groupId,
    required String content,
    required String messageType,
    String? fileUrl,
    String? fileName,
    String? replyToId,
  }) {
    if (_isConnected) {
      _socket.emit(AppConstants.socketSendMessage, {
        'groupId': groupId,
        'content': content,
        'messageType': messageType,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'replyToId': replyToId,
      });
    }
  }

  // Typing indicator
  void typing(String groupId) {
    if (_isConnected) {
      _socket.emit(AppConstants.socketTyping, groupId);
    }
  }

  // Stop typing
  void stopTyping(String groupId) {
    if (_isConnected) {
      _socket.emit(AppConstants.socketStopTyping, groupId);
    }
  }

  // Listen to new messages
  void onNewMessage(Function(dynamic) callback) {
    _socket.on(AppConstants.socketNewMessage, callback);
  }

  // Listen to user typing
  void onUserTyping(Function(dynamic) callback) {
    _socket.on(AppConstants.socketUserTyping, callback);
  }

  // Listen to user stop typing
  void onUserStopTyping(Function(dynamic) callback) {
    _socket.on(AppConstants.socketUserStopTyping, callback);
  }

  // Listen to errors
  void onSocketError(Function(dynamic) callback) {
    _socket.on(AppConstants.socketError, callback);
  }

  // Remove new message listener
  void offNewMessage() {
    if (_isInitialized) {
      _socket.off(AppConstants.socketNewMessage);
    }
  }

  // Remove socket error listener
  void offSocketError() {
    if (_isInitialized) {
      _socket.off(AppConstants.socketError);
    }
  }

  // Remove all listeners
  void dispose() {
    if (_isInitialized) {
      _socket.off(AppConstants.socketNewMessage);
      _socket.off(AppConstants.socketUserTyping);
      _socket.off(AppConstants.socketUserStopTyping);
      _socket.off(AppConstants.socketError);
    }
    disconnect();
  }
}
