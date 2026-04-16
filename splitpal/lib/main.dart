import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/app_services.dart';
import 'core/navigation/app_route_observer.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_replay_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

// New Fat Providers
import 'features/auth/auth_provider.dart';
import 'features/groups/group_provider.dart';
import 'features/invoices/invoice_provider.dart';
import 'features/subscriptions/subscription_provider.dart';
import 'features/notifications/notification_provider.dart';
import 'features/exchange/exchange_provider.dart';
import 'features/receipts/receipt_provider.dart';

// AI Provider (server-backed AI features)
import 'package:splitpal/features/ai/ai_provider.dart';

// Pages
import 'package:splitpal/features/auth/presentation/pages/auth_page.dart';
import 'features/auth/presentation/pages/verify_2fa_page.dart';
import 'features/home/presentation/pages/home_shell_page.dart';
import 'features/invoices/presentation/pages/invoice_detail_page.dart';
import 'features/invoices/presentation/pages/my_invoices_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/receipts/presentation/pages/receipt_calendar_page.dart';
import 'features/groups/presentation/pages/join_group_page.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Initialize core singletons
  await AppServices.init();

  // Notification replay
  final notificationReplayService = NotificationReplayService();
  try {
    await notificationReplayService.initialize();
  } catch (e) {
    debugPrint('Local notification initialization failed: $e');
  }

  // Firebase / FCM (optional)
  FcmService? fcmService;
  try {
    await Firebase.initializeApp();
    fcmService = FcmService();
    await fcmService.initialize();
  } catch (e) {
    debugPrint('Firebase not configured: $e');
  }

  final themeController = ThemeController(tokenManager: AppServices.tokenManager);

  runApp(
    MyApp(
      fcmService: fcmService,
      notificationReplayService: notificationReplayService,
      themeController: themeController,
    ),
  );
}

class MyApp extends StatefulWidget {
  final FcmService? fcmService;
  final NotificationReplayService notificationReplayService;
  final ThemeController themeController;

  const MyApp({
    super.key,
    this.fcmService,
    required this.notificationReplayService,
    required this.themeController,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.themeController),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            dio: AppServices.dio,
            tokenManager: AppServices.tokenManager,
            prefs: AppServices.prefs,
          )..checkAuthStatus(),
        ),
        ChangeNotifierProvider(
          create: (_) => GroupProvider(dio: AppServices.dio),
        ),
        ChangeNotifierProvider(
          create: (_) => InvoiceProvider(dio: AppServices.dio),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(dio: AppServices.dio),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(dio: AppServices.dio),
        ),
        ChangeNotifierProvider(
          create: (_) => ExchangeProvider(dio: AppServices.dio),
        ),
        ChangeNotifierProvider(
          create: (_) => ReceiptProvider(
            dio: AppServices.dio,
            uploadRepository: AppServices.upload,
          ),
        ),
        // AI Provider (server-backed OCR + invoice extraction)
        ChangeNotifierProvider(
          create: (_) => AiProvider(
            dio: AppServices.dio,
          ),
        ),
      ],
      child: _AppInitializer(
        fcmService: widget.fcmService,
        notificationReplayService: widget.notificationReplayService,
      ),
    );
  }
}

class _AppInitializer extends StatefulWidget {
  final FcmService? fcmService;
  final NotificationReplayService notificationReplayService;

  const _AppInitializer({
    this.fcmService,
    required this.notificationReplayService,
  });

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer> {
  static const String _walletDeepLinkScheme = 'splitpal';
  static const String _walletDeepLinkHost = 'wallet';
  static const String _joinDeepLinkHost = 'join';

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _deepLinkSubscription;
  Uri? _pendingDeepLinkUri;
  bool _fcmInitialized = false;
  bool _isUpdatingFcmToken = false;
  bool _isReplayingUnread = false;
  String? _replayedUnreadUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAuthListener();
      _initializeDeepLinks();
    });
  }

  Future<void> _initializeDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _tryHandleDeepLink(initialUri);
    } catch (e) {
      debugPrint('Failed to read initial deep link: $e');
    }

    _deepLinkSubscription = _appLinks.uriLinkStream.listen(
      _tryHandleDeepLink,
      onError: (Object error) {
        debugPrint('Failed to listen deep link stream: $error');
      },
    );
  }

  bool _isWalletHomeDeepLink(Uri uri) {
    final normalizedPath = uri.path.trim().toLowerCase();
    final isHomePath =
        normalizedPath.isEmpty ||
        normalizedPath == '/' ||
        normalizedPath == '/home';

    return uri.scheme.toLowerCase() == _walletDeepLinkScheme &&
        uri.host.toLowerCase() == _walletDeepLinkHost &&
        isHomePath;
  }

  void _tryHandleDeepLink(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != _walletDeepLinkScheme) return;

    final host = uri.host.toLowerCase();
    
    if (host == _walletDeepLinkHost) {
      _tryHandleWalletDeepLink(uri);
    } else if (host == _joinDeepLinkHost) {
      _tryHandleJoinDeepLink(uri);
    }
  }

  void _tryHandleWalletDeepLink(Uri uri) {
    if (!_isWalletHomeDeepLink(uri)) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      _pendingDeepLinkUri = uri;
      return;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _pendingDeepLinkUri = uri;
      return;
    }

    _pendingDeepLinkUri = null;
    navigator.pushNamedAndRemoveUntil(
      HomeShellPage.routeName,
      (route) => false,
    );
  }

  void _tryHandleJoinDeepLink(Uri uri) {
    final code = uri.queryParameters['code'];
    if (code == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      _pendingDeepLinkUri = uri;
      return;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _pendingDeepLinkUri = uri;
      return;
    }

    _pendingDeepLinkUri = null;
    navigator.push(
      MaterialPageRoute(
        builder: (context) => JoinGroupPage(initialCode: code.toUpperCase()),
      ),
    );
  }

  void _consumePendingDeepLinkIfAny() {
    final pendingDeepLinkUri = _pendingDeepLinkUri;
    if (pendingDeepLinkUri == null) return;
    _tryHandleDeepLink(pendingDeepLinkUri);
  }

  void _setupAuthListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    authProvider.addListener(() {
      if (authProvider.isAuthenticated) {
        AppServices.socket.connect();
        _updateFcmToken();
        _consumePendingDeepLinkIfAny();

        final userId = authProvider.user?.id;
        if (userId != null) _replayUnreadNotifications(userId);
      } else {
        AppServices.socket.disconnect();
        _fcmInitialized = false;
        _isUpdatingFcmToken = false;
        _isReplayingUnread = false;
        _replayedUnreadUserId = null;
      }
    });

    if (authProvider.isAuthenticated) {
      AppServices.socket.connect();
      _updateFcmToken();
      _consumePendingDeepLinkIfAny();

      final userId = authProvider.user?.id;
      if (userId != null) _replayUnreadNotifications(userId);
    }
  }

  Future<void> _updateFcmToken() async {
    if (_fcmInitialized || _isUpdatingFcmToken || widget.fcmService == null) {
      return;
    }

    _isUpdatingFcmToken = true;
    try {
      final token = await widget.fcmService!.getToken();
      if (token != null && token.isNotEmpty && mounted) {
        final notificationProvider = Provider.of<NotificationProvider>(
          context,
          listen: false,
        );
        final updated = await notificationProvider.updateFcmToken(token);
        _fcmInitialized = updated;
      } else {
        _fcmInitialized = false;
      }
    } catch (e) {
      debugPrint('Failed to update FCM token: $e');
      _fcmInitialized = false;
    } finally {
      _isUpdatingFcmToken = false;
    }
  }

  Future<void> _replayUnreadNotifications(String userId) async {
    if (_isReplayingUnread || _replayedUnreadUserId == userId) return;

    _isReplayingUnread = true;
    try {
      final notificationProvider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );

      final unread = await notificationProvider.getUnreadForReplay(limit: 20);

      await widget.notificationReplayService.replayUnreadNotifications(
        userId: userId,
        notifications: unread,
      );

      _replayedUnreadUserId = userId;
    } catch (e) {
      debugPrint('Failed to replay unread notifications: $e');
    } finally {
      _isReplayingUnread = false;
    }
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp(
      title: 'SplitPal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.themeMode,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver],
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.state == AuthState.initial ||
              authProvider.state == AuthState.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (authProvider.isAuthenticated) {
            if (authProvider.shouldShowOnboarding()) {
              return const OnboardingPage();
            }
            return const HomeShellPage();
          }

          if (authProvider.state == AuthState.requires2FA) {
            return const Verify2FAPage();
          }

          return const AuthPage();
        },
      ),
      routes: {
        OnboardingPage.routeName: (_) => const OnboardingPage(),
        HomeShellPage.routeName: (_) => const HomeShellPage(),
        MyInvoicesPage.routeName: (_) => const MyInvoicesPage(),
        ReceiptCalendarPage.routeName: (_) => const ReceiptCalendarPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == InvoiceDetailPage.routeName) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => InvoiceDetailPage(
              invoiceId: args['invoiceId'] as String,
              groupId: args['groupId'] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}
