import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for the application secrets and environment variables.
class AppConfig {
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  
  /// Sentry DSN (Data Source Name)
  static String get sentryDsn => dotenv.get('SENTRY_DSN', fallback: '');
  
  /// Website URL for update checks
  static String get websiteUrl => dotenv.get('APP_WEBSITE_URL', fallback: 'http://localhost:3000');

  /// Environment flag
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  /// Initialize environment variables
  static Future<void> init() async {
    await dotenv.load(fileName: ".env");
  }
}
