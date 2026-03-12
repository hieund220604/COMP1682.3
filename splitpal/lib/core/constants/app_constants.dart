// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'SplitPal';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String keyToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';

  // Validation
  static const int minPasswordLength = 6;
  static const int otpLength = 6;
  static const int otpExpiryMinutes = 5;

  // Pagination
  static const int defaultPageSize = 20;
  static const int defaultPage = 1;

  // Currency
  static const String defaultCurrency = 'VND';
  static const List<String> supportedCurrencies = ['VND', 'USD'];

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'dd/MM/yyyy';
  static const String displayDateTimeFormat = 'dd/MM/yyyy HH:mm';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Socket Events
  static const String socketJoinGroup = 'join_group';
  static const String socketLeaveGroup = 'leave_group';
  static const String socketSendMessage = 'send_message';
  static const String socketTyping = 'typing';
  static const String socketStopTyping = 'stop_typing';
  static const String socketNewMessage = 'new_message';
  static const String socketUserTyping = 'user_typing';
  static const String socketUserStopTyping = 'user_stop_typing';
  static const String socketError = 'error';

  // Error Messages
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorServer = 'Server error. Please try again later.';
  static const String errorUnauthorized = 'Unauthorized. Please login again.';
  static const String errorUnknown = 'An unknown error occurred.';
  static const String errorValidation = 'Invalid input. Please check your data.';

  // Success Messages
  static const String successLogin = 'Login successful';
  static const String successSignup = 'Account created successfully';
  static const String successLogout = 'Logout successful';
  static const String successUpdate = 'Update successful';
  static const String successDelete = 'Delete successful';
  static const String successCreate = 'Create successful';
}
