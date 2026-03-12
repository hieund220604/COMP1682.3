import 'package:splitpal/core/constants/api_constants.dart';
import 'package:splitpal/core/error/exceptions.dart';
import 'package:splitpal/core/network/dio_client.dart';
import '../models/chat_message.dart';

abstract class ChatRemoteDataSource {
  Future<List<ChatMessage>> getMessages(
    String groupId, {
    String? beforeId,
    int limit,
  });

  Future<ChatMessage> sendMessage({
    required String groupId,
    required String content,
    String messageType,
    String? fileUrl,
    String? fileName,
    String? replyToId,
  });
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final DioClient dioClient;

  ChatRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<ChatMessage>> getMessages(
    String groupId, {
    String? beforeId,
    int limit = 30,
  }) async {
    try {
      final response = await dioClient.get(
        ApiConstants.chatMessages(groupId),
        queryParameters: {
          if (beforeId != null) 'beforeId': beforeId,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final payload = (data is Map && data.containsKey('data'))
            ? data['data']
            : data;
        final messages = (payload?['messages'] ?? []) as List<dynamic>;
        return messages.map((m) => ChatMessage.fromMap(m)).toList();
      } else {
        throw ServerException(message: 'Failed to get messages');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String groupId,
    required String content,
    String messageType = 'TEXT',
    String? fileUrl,
    String? fileName,
    String? replyToId,
  }) async {
    try {
      final response = await dioClient.post(
        ApiConstants.chatMessages(groupId),
        data: {
          'content': content,
          'messageType': messageType,
          'fileUrl': fileUrl,
          'fileName': fileName,
          'replyToId': replyToId,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data;
        final payload = (data is Map && data.containsKey('data'))
            ? data['data']
            : data;
        return ChatMessage.fromMap(payload);
      } else {
        throw ServerException(message: 'Failed to send message');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
