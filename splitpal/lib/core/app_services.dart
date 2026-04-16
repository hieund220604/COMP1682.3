import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'network/dio_client.dart';
import 'network/socket_client.dart';
import 'utils/token_manager.dart';
import 'utils/upload_repository.dart';

/// Simple global accessor for core singletons.
/// Replaces get_it — no abstract interfaces, no auto-registration.
/// Initialized once in main() before runApp().
class AppServices {
  static late final SharedPreferences prefs;
  static late final TokenManager tokenManager;
  static late final DioClient dio;
  static late final SocketClient socket;
  static late final UploadRepository upload;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    tokenManager = TokenManager(secureStorage: secureStorage, prefs: prefs);
    dio = DioClient(tokenManager: tokenManager);
    socket = SocketClient(tokenManager: tokenManager);
    upload = UploadRepository(dioClient: dio);
  }
}
