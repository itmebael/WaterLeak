class SupabaseConfig {
  static const String _legacySupabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _nextPublicSupabaseUrl = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_URL',
    defaultValue: 'https://pcddnhsvxjnwwmwchujk.supabase.co',
  );
  static const String supabaseUrl =
      _legacySupabaseUrl == '' ? _nextPublicSupabaseUrl : _legacySupabaseUrl;

  static const String _legacySupabaseKey =
      String.fromEnvironment('SUPABASE_KEY', defaultValue: '');
  static const String _nextPublicSupabaseKey = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_FUK89NzP96SBBnOsgbIeZg_yX0Conps',
  );
  static const String supabaseAnonKey =
      _legacySupabaseKey == '' ? _nextPublicSupabaseKey : _legacySupabaseKey;
}
