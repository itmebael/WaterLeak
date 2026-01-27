class SupabaseConfig {
  static const String supabaseUrl = 'https://ituksombwexvutmxcmsv.supabase.co';
  // Read from --dart-define=SUPABASE_KEY=... with a safe fallback to the current key
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0dWtzb21id2V4dnV0bXhjbXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYzNDIzMjQsImV4cCI6MjA3MTkxODMyNH0.yLAlqs58A7wA__GsKKtZRh7T_WI-AI2UkjPl_SDlbzA',
  );
}
