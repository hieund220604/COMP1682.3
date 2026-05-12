class AiChatMessage {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime createdAt;

  AiChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: json['_id'] ?? '',
      sessionId: json['sessionId'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }
}
