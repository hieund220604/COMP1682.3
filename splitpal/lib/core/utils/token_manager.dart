import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class TokenManager {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  TokenManager({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs;

  // Save token securely
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.keyToken, value: token);
    await _prefs.setBool(AppConstants.keyIsLoggedIn, true);
  }

  // Get token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.keyToken);
  }

  // Check if token exists
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Delete token
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: AppConstants.keyToken);
    await _prefs.setBool(AppConstants.keyIsLoggedIn, false);
  }

  // Save user info
  Future<void> saveUserInfo({
    required String userId,
    required String email,
  }) async {
    await _prefs.setString(AppConstants.keyUserId, userId);
    await _prefs.setString(AppConstants.keyUserEmail, email);
  }

  // Get user ID
  String? getUserId() {
    return _prefs.getString(AppConstants.keyUserId);
  }

  // Get user email
  String? getUserEmail() {
    return _prefs.getString(AppConstants.keyUserEmail);
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return _prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
  }

  // Clear all auth data
  Future<void> clearAll() async {
    await _secureStorage.delete(key: AppConstants.keyToken);
    await _prefs.remove(AppConstants.keyUserId);
    await _prefs.remove(AppConstants.keyUserEmail);
    await _prefs.setBool(AppConstants.keyIsLoggedIn, false);
  }

  // Save theme mode
  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(AppConstants.keyThemeMode, mode);
  }

  // Get theme mode
  String? getThemeMode() {
    return _prefs.getString(AppConstants.keyThemeMode);
  }

  // Save language
  Future<void> saveLanguage(String language) async {
    await _prefs.setString(AppConstants.keyLanguage, language);
  }

  // Get language
  String? getLanguage() {
    return _prefs.getString(AppConstants.keyLanguage);
  }
}
