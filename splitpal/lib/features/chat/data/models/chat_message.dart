class ChatUser {
  final String id;
  final String? displayName;
  final String? avatarUrl;

  ChatUser({
    required this.id,
    this.displayName,
    this.avatarUrl,
  });

  factory ChatUser.fromMap(Map<String, dynamic> map) {
    return ChatUser(
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      displayName: map['displayName'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
    );
  }
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

    final created = map['createdAt'];
    final updated = map['updatedAt'];

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
      createdAt: _parseDate(created),
      updatedAt: updated != null ? _parseDate(updated) : null,
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
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
