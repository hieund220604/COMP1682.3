import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/socket_client.dart';
import '../../core/utils/token_manager.dart';

// Inline ChatMessage model (only used by this provider)
class ChatUser {
  final String id;
  final String? displayName;
  final String? avatarUrl;

  ChatUser({required this.id, this.displayName, this.avatarUrl});

  factory ChatUser.fromMap(Map<String, dynamic> map) => ChatUser(
        id: (map['_id'] ?? map['id'] ?? '').toString(),
        displayName: map['displayName'] as String?,
        avatarUrl: map['avatarUrl'] as String?,
      );
}

class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String? content;
  final String messageType;
  final String? fileUrl;
  final String? fileName;
  final String? replyToId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ChatUser? sender;
  final ChatMessage? replyTo;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.fileUrl,
    this.fileName,
    this.replyToId,
    required this.createdAt,
    this.updatedAt,
    this.sender,
    this.replyTo,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final rawSenderId = map['senderId'];
    String senderId = '';
    if (rawSenderId is Map) {
      senderId = (rawSenderId['_id'] ??
              rawSenderId['id'] ??
              rawSenderId['userId'] ??
              rawSenderId.toString())
          .toString();
    } else if (rawSenderId != null) {
      senderId = rawSenderId.toString();
    }

    return ChatMessage(
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      groupId: (map['groupId'] ?? '').toString(),
      senderId: senderId.isNotEmpty
          ? senderId
          : (map['sender']?['id'] ??
                  map['sender']?['_id'] ??
                  map['sender']?['userId'] ??
                  '')
              .toString(),
      content: map['content'] as String?,
      messageType: (map['messageType'] ?? 'TEXT').toString(),
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      replyToId: map['replyToId'] != null
          ? map['replyToId'].toString()
          : map['replyTo'] != null
              ? (map['replyTo']['id'] ?? map['replyTo']['_id']).toString()
              : null,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDate(map['updatedAt']) : null,
      sender: map['sender'] != null && map['sender'] is Map
          ? ChatUser.fromMap(map['sender'] as Map<String, dynamic>)
          : null,
      replyTo: map['replyTo'] != null && map['replyTo'] is Map
          ? ChatMessage.fromMap(map['replyTo'] as Map<String, dynamic>)
          : null,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

/// Fat Provider — calls DioClient + SocketClient directly for chat.
class ChatProvider extends ChangeNotifier {
  final DioClient _dio;
  final SocketClient socketClient;
  final TokenManager tokenManager;

  ChatProvider({
    required DioClient dio,
    required this.socketClient,
    required this.tokenManager,
  }) : _dio = dio;

  final List<ChatMessage> _messages = [];
  final Set<String> _messageIds = {};
  String? _groupId;
  String? _currentUserId;
  bool _isLoading = false;
  bool _isSending = false;
  bool _hasMore = true;
  String? _error;
  bool _listenersAttached = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get groupId => _groupId;
  String? get currentUserId => _currentUserId;

  Future<void> init(String groupId, {String? currentUserId}) async {
    if (_groupId == groupId && _listenersAttached && _messages.isNotEmpty) {
      return;
    }
    _groupId = groupId;
    _currentUserId = currentUserId ?? tokenManager.getUserId();
    _messages.clear();
    _messageIds.clear();
    _hasMore = true;
    _error = null;

    try {
      await _ensureSocketConnected();
      socketClient.joinGroup(groupId);
      _attachSocketListeners();
    } catch (e) {
      _error = e.toString();
    }

    await loadInitialMessages();
  }

  Future<void> loadInitialMessages() async {
    if (_groupId == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _dio.get(
        ApiConstants.chatMessages(_groupId!),
        queryParameters: {'limit': 30},
      );
      final data = resp.data;
      final payload =
          (data is Map && data.containsKey('data')) ? data['data'] : data;
      final msgs = (payload?['messages'] ?? []) as List<dynamic>;
      _mergeMessages(msgs.map((m) => ChatMessage.fromMap(m)).toList());
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_groupId == null || !_hasMore || _isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final beforeId = _messages.isNotEmpty ? _messages.first.id : null;
      final resp = await _dio.get(
        ApiConstants.chatMessages(_groupId!),
        queryParameters: {
          if (beforeId != null) 'beforeId': beforeId,
          'limit': 20,
        },
      );
      final data = resp.data;
      final payload =
          (data is Map && data.containsKey('data')) ? data['data'] : data;
      final msgs = (payload?['messages'] ?? []) as List<dynamic>;
      final items = msgs.map((m) => ChatMessage.fromMap(m)).toList();
      if (items.isEmpty) _hasMore = false;
      _mergeMessages(items);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (_groupId == null || content.trim().isEmpty) return;
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      await _ensureSocketConnected();
      socketClient.joinGroup(_groupId!);

      final resp = await _dio.post(
        ApiConstants.chatMessages(_groupId!),
        data: {'content': content.trim(), 'messageType': 'TEXT'},
      );
      final data = resp.data;
      final payload =
          (data is Map && data.containsKey('data')) ? data['data'] : data;
      _mergeMessages([ChatMessage.fromMap(payload)]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void _mergeMessages(List<ChatMessage> items) {
    for (final msg in items) {
      if (_messageIds.contains(msg.id)) continue;
      _messageIds.add(msg.id);
      _messages.add(msg);
    }
    _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _ensureSocketConnected() async {
    if (!socketClient.isConnected) await socketClient.connect();
  }

  void _attachSocketListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    socketClient.onNewMessage((data) {
      if (_groupId == null) return;
      try {
        if (data is Map && data['groupId']?.toString() == _groupId) {
          _mergeMessages(
              [ChatMessage.fromMap(data as Map<String, dynamic>)]);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Failed to parse incoming message: $e');
      }
    });

    socketClient.onSocketError((data) {
      _error = data is Map ? data['message']?.toString() : data.toString();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    if (_groupId != null) socketClient.leaveGroup(_groupId!);
    socketClient.offNewMessage();
    socketClient.offSocketError();
    _listenersAttached = false;
    super.dispose();
  }
}
