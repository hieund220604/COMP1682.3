import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../features/notifications/data/datasources/notification_local_data_source.dart';
import '../../features/notifications/data/datasources/notification_remote_data_source.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../network/dio_client.dart';
import '../network/socket_client.dart';

/// Dependency injection setup for notification feature
class NotificationInjection {
  static List<SingleChildWidget> getProviders({
    required DioClient dioClient,
    required SocketClient socketClient,
  }) {
    // Data sources
    final remoteDataSource = NotificationRemoteDataSourceImpl(dioClient);
    final localDataSource = NotificationLocalDataSourceImpl(socketClient);

    // Repository
    final repository = NotificationRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );

    // Providers
    return [
      ChangeNotifierProvider<NotificationProvider>(
        create: (_) => NotificationProvider(repository),
      ),
    ];
  }

  /// Initialize notification services
  /// Call this after user login to start real-time notifications
  static void initialize(NotificationProvider provider) {
    provider.fetchNotifications();
    provider.fetchUnreadCount();
  }
}
