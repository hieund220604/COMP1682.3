import 'package:dio/dio.dart';
import 'package:splitpal/models/ai_chat_session.dart';
import 'package:splitpal/models/ai_chat_message.dart';

class AiChatApi {
  final Dio _dio;

  AiChatApi(this._dio);

  Future<List<AiChatSession>> getSessions() async {
    final resp = await _dio.get('/ai-chat/sessions');
    final data = resp.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final list = data['data'] as List;
      return list.map((e) => AiChatSession.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<AiChatMessage>> getSessionHistory(String sessionId) async {
    final resp = await _dio.get('/ai-chat/sessions/$sessionId');
    final data = resp.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final list = data['data'] as List;
      return list.map((e) => AiChatMessage.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> sendMessage(String message, {String? sessionId}) async {
    final resp = await _dio.post('/ai-chat/message', data: {
      'message': message,
      if (sessionId != null) 'sessionId': sessionId,
    });
    final data = resp.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return {};
  }
}
