class AiChatSession {
  final String id;
  final String title;
  final DateTime updatedAt;

  AiChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  factory AiChatSession.fromJson(Map<String, dynamic> json) {
    return AiChatSession(
      id: json['_id'] ?? '',
      title: json['title'] ?? 'New Chat',
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }
}
