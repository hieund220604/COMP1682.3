import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Gemini API Configuration
/// Loads API key from environment variables (.env file)
class GeminiConfig {
  static String get apiKey {
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static bool get isConfigured {
    final key = apiKey;
    return key.isNotEmpty && key != 'YOUR_GEMINI_API_KEY_HERE';
  }
}
