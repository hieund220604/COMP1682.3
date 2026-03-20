import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/di/injection_container.dart' as di;
import 'core/network/socket_client.dart';
import 'core/config/gemini_config.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_replay_service.dart';
import 'core/navigation/app_route_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/token_manager.dart';
import 'features/auth/presentation/pages/auth_page.dart';
import 'features/auth/presentation/pages/verify_2fa_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/groups/presentation/providers/group_provider.dart';
import 'features/home/presentation/pages/home_shell_page.dart';
import 'features/invoices/presentation/pages/invoice_detail_page.dart';
import 'features/invoices/presentation/pages/my_invoices_page.dart';
import 'features/invoices/presentation/providers/invoice_provider.dart';
import 'features/invoices/presentation/providers/ocr_provider.dart';
import 'features/notifications/presentation/providers/notification_provider.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/subscriptions/presentation/providers/subscription_provider.dart';
import 'features/exchange/presentation/providers/exchange_provider.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// Cache for onboarding preference to avoid repeated futures
final Map<String, bool> _showOnboardingCache = {};

/// Helper function to get home widget based on preference
Widget _getHomeWidget(AuthProvider authProvider) {
  final userId = authProvider.user?.id ?? '';
  final cacheKey = 'user_$userId';

  // Check cache first
  if (_showOnboardingCache.containsKey(cacheKey)) {
    return _showOnboardingCache[cacheKey]!
        ? const OnboardingPage()
        : const HomeShellPage();
  }

  // Load preference asynchronously
  return FutureBuilder<bool>(
    future: authProvider.getShowOnboardingOnLogin().then((value) {
      _showOnboardingCache[cacheKey] = value;
      return value;
    }),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snapshot.data! ? const OnboardingPage() : const HomeShellPage();
    },
  );
}

/// StatefulWidget to handle onboarding toggle state caching
class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome();

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late Future<bool> _showOnboardingFuture;

  @override
  void initState() {
    super.initState();
    // Cache the future to avoid infinite rebuilds
    _showOnboardingFuture = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).getShowOnboardingOnLogin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _showOnboardingFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          // Show onboarding if enabled
          return const OnboardingPage();
        } else {
          // Skip onboarding, go directly to home
          return const HomeShellPage();
        }
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  await di.init();

  final notificationReplayService = NotificationReplayService();
  try {
    await notificationReplayService.initialize();
  } catch (e) {
    print('Local notification initialization failed: $e');
  }

  FcmService? fcmService;
  try {
    await Firebase.initializeApp();
    fcmService = FcmService();
    await fcmService.initialize();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase not configured: $e');
    print(
      'Push notifications disabled. Real-time notifications via Socket.IO will still work.',
    );
  }

  final themeController = ThemeController(tokenManager: di.sl<TokenManager>());

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
          create: (_) => di.sl<AuthProvider>()..checkAuthStatus(),
        ),
        ChangeNotifierProvider(create: (_) => di.sl<GroupProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<SubscriptionProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<InvoiceProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<NotificationProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ExchangeProvider>()),
        // OCR Provider (only if Gemini API configured)
        if (GeminiConfig.isConfigured)
          ChangeNotifierProvider(create: (_) => di.sl<OcrProvider>()),
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
      if (initialUri != null) {
        _tryHandleWalletDeepLink(initialUri);
      }
    } catch (e) {
      print('Failed to read initial deep link: $e');
    }

    _deepLinkSubscription = _appLinks.uriLinkStream.listen(
      _tryHandleWalletDeepLink,
      onError: (Object error) {
        print('Failed to listen deep link stream: $error');
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

  void _tryHandleWalletDeepLink(Uri uri) {
    if (!_isWalletHomeDeepLink(uri)) {
      return;
    }

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

  void _consumePendingDeepLinkIfAny() {
    final pendingDeepLinkUri = _pendingDeepLinkUri;
    if (pendingDeepLinkUri == null) {
      return;
    }

    _tryHandleWalletDeepLink(pendingDeepLinkUri);
  }

  void _setupAuthListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    authProvider.addListener(() {
      if (authProvider.isAuthenticated) {
        di.sl<SocketClient>().connect();
        _updateFcmToken();
        _consumePendingDeepLinkIfAny();

        final userId = authProvider.user?.id;
        if (userId != null) {
          _replayUnreadNotifications(userId);
        }
      } else {
        di.sl<SocketClient>().disconnect();
        _fcmInitialized = false;
        _isUpdatingFcmToken = false;
        _isReplayingUnread = false;
        _replayedUnreadUserId = null;
      }
    });

    if (authProvider.isAuthenticated) {
      di.sl<SocketClient>().connect();
      _updateFcmToken();
      _consumePendingDeepLinkIfAny();

      final userId = authProvider.user?.id;
      if (userId != null) {
        _replayUnreadNotifications(userId);
      }
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
      print('Failed to update FCM token: $e');
      _fcmInitialized = false;
    } finally {
      _isUpdatingFcmToken = false;
    }
  }

  Future<void> _replayUnreadNotifications(String userId) async {
    if (_isReplayingUnread || _replayedUnreadUserId == userId) {
      return;
    }

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
      print('Failed to replay unread notifications: $e');
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
            // Always go to HomeShellPage when authenticated
            // Onboarding preference only applies on fresh app startup (different user)
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
