import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/notification.dart';

class NotificationReplayService {
  static const String _channelId = 'splitpal_replay_channel';
  static const String _channelName = 'SplitPal Missed Notifications';
  static const String _channelDescription =
      'Replayed unread notifications when user logs in';
  static const int _maxStoredIds = 200;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    // Android 13+ needs runtime notification permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> replayUnreadNotifications({
    required String userId,
    required List<AppNotification> notifications,
    int maxCount = 5,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final unread = notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final storageKey = 'replayed_notification_ids_$userId';
    final replayedIds = prefs.getStringList(storageKey) ?? <String>[];
    final replayedSet = replayedIds.toSet();

    int shown = 0;
    for (final item in unread) {
      if (shown >= maxCount) break;
      if (replayedSet.contains(item.id)) continue;

      await _plugin.show(
        _toIntId(item.id),
        item.title,
        item.message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: item.id,
      );

      replayedSet.add(item.id);
      replayedIds.add(item.id);
      shown++;
    }

    if (replayedIds.length > _maxStoredIds) {
      replayedIds.removeRange(0, replayedIds.length - _maxStoredIds);
    }

    await prefs.setStringList(storageKey, replayedIds);
  }

  int _toIntId(String value) {
    return value.hashCode & 0x7fffffff;
  }
}
