/// Configuration for the application secrets and environment variables.
/// 
/// [IMPORTANT] In a production environment, this file should be handled with care. 
/// Consider using --dart-define or a .env file for absolute security, 
/// and NEVER commit actual production keys to a public repository.
class AppConfig {
  static const String supabaseUrl = 'https://fcrchqrysuzrtaaalbyr.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_zNkMpBQ7lf79xqEIFQX2Lg_vrB4DUDN';
  
  /// Sentry DSN (Data Source Name)
  /// Replace this with your actual DSN from the Sentry dashboard.
  static const String sentryDsn = 'REPLACE_WITH_YOUR_SENTRY_DSN';
  
  /// Environment flag
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}
