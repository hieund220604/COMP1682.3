import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/notification_entity.dart';

abstract class NotificationRepository {
  /// Get user notifications
  Future<Either<Failure, List<NotificationEntity>>> getNotifications({
    bool? unreadOnly,
    int? limit,
  });

  /// Get unread notification count
  Future<Either<Failure, int>> getUnreadCount();

  /// Mark notification as read
  Future<Either<Failure, void>> markAsRead(String notificationId);

  /// Mark all notifications as read
  Future<Either<Failure, void>> markAllAsRead();

  /// Delete a notification
  Future<Either<Failure, void>> deleteNotification(String notificationId);

  /// Delete all read notifications
  Future<Either<Failure, int>> deleteAllRead();

  /// Update FCM token
  Future<Either<Failure, void>> updateFcmToken(String token);

  /// Delete FCM token
  Future<Either<Failure, void>> deleteFcmToken();

  /// Listen to real-time notification updates (Stream)
  Stream<NotificationEntity> watchNotifications();
}
