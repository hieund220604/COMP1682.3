import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/dio_client.dart';
import '../../models/notification.dart';

enum NotificationStatus { initial, loading, loaded, error }

/// Fat Provider — calls DioClient directly for notifications.
class NotificationProvider with ChangeNotifier {
  final DioClient _dio;

  NotificationProvider({required DioClient dio}) : _dio = dio;

  // ─── State ──────────────────────────────────────────────
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  NotificationStatus _status = NotificationStatus.initial;
  String? _errorMessage;
  bool? _pushNotificationsEnabled;
  bool _preferencesLoading = false;
  bool _preferencesUpdating = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  NotificationStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == NotificationStatus.loading;
  bool? get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool get isPreferencesLoading => _preferencesLoading;
  bool get isPreferencesUpdating => _preferencesUpdating;

  // ─── Fetch Notifications ────────────────────────────────
  Future<void> fetchNotifications({bool? unreadOnly, int? limit}) async {
    _status = NotificationStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{};
      if (unreadOnly != null) queryParams['unreadOnly'] = unreadOnly;
      if (limit != null) queryParams['limit'] = limit;

      final resp = await _dio.get('/notifications', queryParameters: queryParams);
      final data = resp.data;
      final List<dynamic> list;
      if (data is Map && data.containsKey('data')) {
        list = data['data'] as List;
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }

      _notifications = list
          .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
          .toList();
      _status = NotificationStatus.loaded;
    } catch (e) {
      _status = NotificationStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<List<AppNotification>> getUnreadForReplay({int limit = 20}) async {
    try {
      final resp = await _dio.get('/notifications', queryParameters: {
        'unreadOnly': true,
        'limit': limit,
      });
      final data = resp.data;
      final list = (data is Map && data.containsKey('data'))
          ? data['data'] as List
          : (data is List ? data : []);
      return list
          .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
          .where((n) => !n.read)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Unread Count ───────────────────────────────────────
  Future<void> fetchUnreadCount() async {
    try {
      final resp = await _dio.get('/notifications/unread-count');
      final data = resp.data;
      if (data is Map && data.containsKey('data')) {
        _unreadCount = (data['data']['count'] as num).toInt();
        notifyListeners();
      }
    } catch (_) {}
  }

  // ─── Mark As Read ───────────────────────────────────────
  Future<void> markAsRead(String notificationId) async {
    try {
      await _dio.patch('/notifications/$notificationId/read');
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1 && !_notifications[idx].read) {
        _notifications[idx] = _notifications[idx].copyWith(read: true);
        _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _dio.patch('/notifications/read-all');
      _notifications = _notifications
          .map((n) => n.copyWith(read: true))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  // ─── Delete ─────────────────────────────────────────────
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _dio.delete('/notifications/$notificationId');
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        if (!_notifications[idx].read) {
          _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
        }
        _notifications.removeAt(idx);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<int> deleteAllRead() async {
    try {
      final resp = await _dio.delete('/notifications/read');
      final data = resp.data;
      int count = 0;
      if (data is Map && data.containsKey('data')) {
        count = (data['data']['deletedCount'] as num).toInt();
      }
      _notifications.removeWhere((n) => n.read);
      notifyListeners();
      return count;
    } catch (_) {
      return 0;
    }
  }

  // ─── FCM Token ──────────────────────────────────────────
  Future<bool> updateFcmToken(String token) async {
    try {
      await _dio.put('/accounts/fcm-token', data: {'fcmToken': token});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteFcmToken() async {
    try {
      await _dio.delete('/accounts/fcm-token');
    } catch (_) {}
  }

  // ─── Notification Preferences ───────────────────────────
  Future<void> loadNotificationPreferences() async {
    _preferencesLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resp = await _dio.get('/accounts/notification-preferences');
      final data = resp.data;
      if (data is Map && data.containsKey('data')) {
        final prefs = data['data'] as Map<String, dynamic>;
        _pushNotificationsEnabled =
            (prefs['pushNotificationsEnabled'] as bool?) ?? true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _pushNotificationsEnabled ??= true;
    }

    _preferencesLoading = false;
    notifyListeners();
  }

  Future<bool> updateNotificationPreference(bool enabled) async {
    _preferencesUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _dio.patch(
        '/accounts/notification-preferences',
        data: {'pushNotificationsEnabled': enabled},
      );
      _pushNotificationsEnabled = enabled;
      _preferencesUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _preferencesUpdating = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Real-time (called externally from socket) ──────────
  void addNotificationFromSocket(AppNotification notification) {
    _notifications.insert(0, notification);
    _unreadCount++;
    notifyListeners();
  }
}
