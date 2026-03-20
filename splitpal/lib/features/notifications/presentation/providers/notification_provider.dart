import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';

enum NotificationStatus { initial, loading, loaded, error }

class NotificationProvider with ChangeNotifier {
  final NotificationRepository repository;

  NotificationProvider(this.repository) {
    _subscribeToNotifications();
  }

  List<NotificationEntity> _notifications = [];
  int _unreadCount = 0;
  NotificationStatus _status = NotificationStatus.initial;
  String? _errorMessage;
  StreamSubscription<NotificationEntity>? _notificationSubscription;
  bool? _pushNotificationsEnabled;
  bool _preferencesLoading = false;
  bool _preferencesUpdating = false;

  List<NotificationEntity> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  NotificationStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == NotificationStatus.loading;
  bool? get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get isPreferencesLoading => _preferencesLoading;
  bool get isPreferencesUpdating => _preferencesUpdating;

  void _subscribeToNotifications() {
    _notificationSubscription = repository.watchNotifications().listen(
      (notification) {
        _notifications.insert(0, notification);
        _unreadCount++;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  Future<void> fetchNotifications({bool? unreadOnly, int? limit}) async {
    _status = NotificationStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.getNotifications(
      unreadOnly: unreadOnly,
      limit: limit,
    );

    result.fold(
      (failure) {
        _status = NotificationStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (notifications) {
        _notifications = notifications;
        _status = NotificationStatus.loaded;
        notifyListeners();
      },
    );
  }

  Future<List<NotificationEntity>> getUnreadForReplay({int limit = 20}) async {
    final result = await repository.getNotifications(
      unreadOnly: true,
      limit: limit,
    );

    return result.fold(
      (failure) => <NotificationEntity>[],
      (notifications) => notifications.where((n) => !n.read).toList(),
    );
  }

  Future<void> fetchUnreadCount() async {
    final result = await repository.getUnreadCount();

    result.fold(
      (failure) {},
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final result = await repository.markAsRead(notificationId);

    result.fold(
      (failure) {},
      (_) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && !_notifications[index].read) {
          _notifications[index] = _notifications[index].copyWith(read: true);
          _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
          notifyListeners();
        }
      },
    );
  }

  Future<void> markAllAsRead() async {
    final result = await repository.markAllAsRead();

    result.fold(
      (failure) {},
      (_) {
        _notifications = _notifications
            .map((notification) => notification.copyWith(read: true))
            .toList();
        _unreadCount = 0;
        notifyListeners();
      },
    );
  }

  Future<void> deleteNotification(String notificationId) async {
    final result = await repository.deleteNotification(notificationId);

    result.fold(
      (failure) {},
      (_) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          if (!_notifications[index].read) {
            _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
          }
          _notifications.removeAt(index);
          notifyListeners();
        }
      },
    );
  }

  Future<int> deleteAllRead() async {
    final result = await repository.deleteAllRead();

    return result.fold(
      (failure) => 0,
      (deletedCount) {
        _notifications.removeWhere((notification) => notification.read);
        notifyListeners();
        return deletedCount;
      },
    );
  }

  Future<bool> updateFcmToken(String token) async {
    final result = await repository.updateFcmToken(token);

    return result.fold(
      (failure) => false,
      (_) => true,
    );
  }

  Future<void> deleteFcmToken() async {
    final result = await repository.deleteFcmToken();

    result.fold(
      (failure) {},
      (_) {},
    );
  }

  Future<void> loadNotificationPreferences() async {
    _preferencesLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.getNotificationPreferences();
    _preferencesLoading = false;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _pushNotificationsEnabled ??= true;
        notifyListeners();
      },
      (enabled) {
        _pushNotificationsEnabled = enabled;
        notifyListeners();
      },
    );
  }

  Future<bool> updateNotificationPreference(bool enabled) async {
    _preferencesUpdating = true;
    _errorMessage = null;
    notifyListeners();

    final result = await repository.updateNotificationPreferences(enabled);
    _preferencesUpdating = false;

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _pushNotificationsEnabled = enabled;
        notifyListeners();
        return true;
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
