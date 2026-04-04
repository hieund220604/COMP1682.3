import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:splitpal/core/network/socket_client.dart';
import 'package:splitpal/core/utils/token_manager.dart';

import '../../data/datasources/chat_remote_data_source.dart';
import '../../data/models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRemoteDataSource remoteDataSource;
  final SocketClient socketClient;
  final TokenManager tokenManager;

  ChatProvider({
    required this.remoteDataSource,
    required this.socketClient,
    required this.tokenManager,
  });

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

  Future<Map<String, dynamic>> extractInvoiceSuggestion(String text) async {
    if (text.trim().isEmpty) {
      throw Exception('Message is empty');
    }
    return await remoteDataSource.extractInvoiceSuggestion(
      text: text.trim(),
      groupId: _groupId,
    );
  }

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
      final items = await remoteDataSource.getMessages(_groupId!, limit: 30);
      _mergeMessages(items);
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
      final items = await remoteDataSource.getMessages(
        _groupId!,
        beforeId: beforeId,
        limit: 20,
      );
      if (items.isEmpty) {
        _hasMore = false;
      }
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
      // Ensure we are in the room before sending
      await _ensureSocketConnected();
      socketClient.joinGroup(_groupId!);

      final message = await remoteDataSource.sendMessage(
        groupId: _groupId!,
        content: content.trim(),
        messageType: 'TEXT',
      );
      _mergeMessages([message]);
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
    if (!socketClient.isConnected) {
      await socketClient.connect();
    }
  }

  void _attachSocketListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    socketClient.onNewMessage((data) {
      if (_groupId == null) return;
      try {
        if (data is Map && data['groupId']?.toString() == _groupId) {
          final message = ChatMessage.fromMap(data as Map<String, dynamic>);
          _mergeMessages([message]);
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
    if (_groupId != null) {
      socketClient.leaveGroup(_groupId!);
    }
    socketClient.offNewMessage();
    socketClient.offSocketError();
    _listenersAttached = false;
    super.dispose();
  }
}
