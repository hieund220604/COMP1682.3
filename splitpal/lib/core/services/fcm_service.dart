import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmService {
  static const String _androidChannelId = 'default';
  static const String _androidChannelName = 'SplitPal Notifications';
  static const String _androidChannelDescription =
      'Notification channel for SplitPal push messages';

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Function(String)? onTokenUpdate;
  final Function(RemoteMessage)? onMessageReceived;

  static bool _isInitialized = false;
  static bool _backgroundHandlerRegistered = false;
  bool _messageHandlersRegistered = false;
  bool _localNotificationsInitialized = false;

  FcmService({this.onTokenUpdate, this.onMessageReceived});

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (!_backgroundHandlerRegistered) {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );
        _backgroundHandlerRegistered = true;
      }

      await _initializeLocalNotifications();

      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          onTokenUpdate?.call(token);
        }

        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          onTokenUpdate?.call(newToken);
        });

        _setupMessageHandlers();
        _isInitialized = true;
      }
    } catch (_) {}
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _localNotificationsInitialized = true;
  }

  void _setupMessageHandlers() {
    if (_messageHandlersRegistered) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
      onMessageReceived?.call(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });

    _messageHandlersRegistered = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsInitialized) {
      await _initializeLocalNotifications();
    }

    final title = message.notification?.title;
    final body = message.notification?.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await _localNotifications.show(
      (message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString())
          .hashCode
          .abs(),
      title ?? 'SplitPal',
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle notification tap navigation here if needed
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> deleteToken() async {
    await _firebaseMessaging.deleteToken();
  }
}
