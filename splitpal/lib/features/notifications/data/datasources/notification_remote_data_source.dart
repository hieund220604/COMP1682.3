import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/notification_model.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications({
    bool? unreadOnly,
    int? limit,
  });

  Future<int> getUnreadCount();

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();

  Future<void> deleteNotification(String notificationId);

  Future<int> deleteAllRead();

  Future<void> updateFcmToken(String token);

  Future<void> deleteFcmToken();
}

class NotificationRemoteDataSourceImpl
    implements NotificationRemoteDataSource {
  final DioClient dioClient;

  NotificationRemoteDataSourceImpl(this.dioClient);

  @override
  Future<List<NotificationModel>> getNotifications({
    bool? unreadOnly,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (unreadOnly != null) queryParams['unreadOnly'] = unreadOnly;
      if (limit != null) queryParams['limit'] = limit;

      final response = await dioClient.get(
        '/notifications',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List<dynamic> notificationsList;

        if (data is Map && data.containsKey('data')) {
          notificationsList = data['data'] as List;
        } else if (data is List) {
          notificationsList = data;
        } else {
          return [];
        }

        return notificationsList
            .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ServerException(message: 'Failed to fetch notifications');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await dioClient.get('/notifications/unread-count');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('data')) {
          return (data['data']['count'] as num).toInt();
        }
        return 0;
      } else {
        throw ServerException(message: 'Failed to fetch unread count');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await dioClient.patch(
        '/notifications/$notificationId/read',
      );

      if (response.statusCode != 200) {
        throw ServerException(message: 'Failed to mark notification as read');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      final response = await dioClient.patch('/notifications/read-all');

      if (response.statusCode != 200) {
        throw ServerException(message: 'Failed to mark all as read');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await dioClient.delete('/notifications/$notificationId');

      if (response.statusCode != 200) {
        throw ServerException(message: 'Failed to delete notification');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<int> deleteAllRead() async {
    try {
      final response = await dioClient.delete('/notifications/read');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('data')) {
          return (data['data']['deletedCount'] as num).toInt();
        }
        return 0;
      } else {
        throw ServerException(message: 'Failed to delete read notifications');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updateFcmToken(String token) async {
    try {
      final response = await dioClient.put(
        '/accounts/fcm-token',
        data: {'fcmToken': token},
      );

      if (response.statusCode != 200) {
        throw ServerException(message: 'Failed to update FCM token');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteFcmToken() async {
    try {
      final response = await dioClient.delete('/accounts/fcm-token');

      if (response.statusCode != 200) {
        throw ServerException(message: 'Failed to delete FCM token');
      }
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
