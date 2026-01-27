 import 'package:supabase_flutter/supabase_flutter.dart';
 import 'package:shared_preferences/shared_preferences.dart';
 import 'dart:convert';
 import '../config/supabase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  late final SupabaseClient _client;
  Map<String, dynamic>? _currentUser;
  String? _sessionToken;

  Map<String, dynamic>? get currentUser => _currentUser;
  String? get sessionToken => _sessionToken;
  bool get isAuthenticated => _currentUser != null && _sessionToken != null;

  Future<void> setHardcodedAdminSession({
    required String email,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _sessionToken = 'hardcoded_admin_$now';
    _currentUser = {
      'id': 'hardcoded_admin',
      'email': email,
    };
    await _persistSession();
  }

  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
      );
      _client = Supabase.instance.client;
      print('✅ Supabase initialized successfully');
      await _loadPersistedSession();
    } catch (e) {
      print('❌ Supabase initialization failed: $e');
      rethrow;
    }
  }

  SupabaseClient get client => _client;

  // Custom Sign Up (No Email Verification)
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? username,
    String? phone,
  }) async {
    try {
      print('🔄 Attempting to register user: $email');

      // Test connection first
      await _testConnection();

      // Test if register_user function exists
      await _testRegisterFunction();

      // Test with minimal parameters first
      print('🔄 Testing with minimal parameters...');
      final testMinimal = await _client.rpc('register_user', params: {
        'user_email': 'test@example.com',
        'user_password': 'testpassword',
      });
      print('📤 Minimal test response: $testMinimal');

      // Call our custom register function
      print('🔄 Calling register_user function...');
      final response = await _client.rpc('register_user', params: {
        'user_email': email,
        'user_password': password,
        'user_full_name': '$firstName $lastName',
        'user_username': username,
        'user_phone': phone,
      });

      print('📤 Supabase response: $response');

      if (response['success'] == true) {
        // Set current user and session
        _currentUser = {
          'id': response['user_id'],
          'email': email,
          'full_name': '$firstName $lastName',
          'first_name': firstName,
          'last_name': lastName,
          'username': username,
          'phone': phone,
        };
        _sessionToken = response['session_token'];
        await _persistSession();

        print('✅ User registered successfully');
        return {
          'success': true,
          'user': _currentUser,
          'session_token': _sessionToken,
          'message': 'Registration successful'
        };
      } else {
        print('❌ Registration failed: ${response['error']}');
        return {
          'success': false,
          'error': response['error'] ?? 'Registration failed'
        };
      }
    } catch (e) {
      print('❌ Sign up error: $e');

      // Handle specific error types
      if (e.toString().contains('HandshakeException')) {
        return {
          'success': false,
          'error':
              'Network connection failed. Please check your internet connection and try again.'
        };
      } else if (e.toString().contains('SocketException')) {
        return {
          'success': false,
          'error':
              'Unable to connect to server. Please check your internet connection.'
        };
      } else {
        return {
          'success': false,
          'error': 'Registration failed: ${e.toString()}'
        };
      }
    }
  }

  // Test connection to Supabase
  Future<void> _testConnection() async {
    try {
      print('🔄 Testing Supabase connection...');
      print('📍 Supabase URL: ${SupabaseConfig.supabaseUrl}');
      print(
          '🔑 Using API Key: ${SupabaseConfig.supabaseAnonKey.substring(0, 20)}...');

      final response = await _client.from('users').select('count').limit(1);
      print('✅ Connection test successful - Response: $response');
    } catch (e) {
      print('❌ Connection test failed: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Full error details: ${e.toString()}');
      throw Exception('Cannot connect to Supabase: $e');
    }
  }

  // Test if register_user function exists
  Future<void> _testRegisterFunction() async {
    try {
      print('🔄 Testing register_user function...');
      // Try to call the function with test data
      final testResponse = await _client.rpc('register_user', params: {
        'user_email': 'test@example.com',
        'user_password': 'testpassword',
        'user_full_name': 'Test User',
        'user_username': 'testuser',
        'user_phone': null,
      });
      print('✅ register_user function exists - Test response: $testResponse');
    } catch (e) {
      if (e.toString().contains('function') &&
          e.toString().contains('does not exist')) {
        print('❌ register_user function does not exist in database!');
        throw Exception(
            'register_user function not found. Please run the SQL setup script in Supabase.');
      } else {
        print('✅ register_user function exists (test failed as expected): $e');
      }
    }
  }

  // Custom Sign In
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Call our custom login function
      final response = await _client.rpc('login_user', params: {
        'user_email': email,
        'user_password': password,
      });

      if (response['success'] == true) {
        // Set session token
        _sessionToken = response['session_token'];
        print('🔑 Session token set: $_sessionToken');

        // Create user data immediately (don't wait for validation)
        _currentUser = {
          'id': response['user_id'],
          'email': email,
        };
        print('✅ User data set immediately: $_currentUser');
        await _persistSession();

        print(
            '🎉 Login completed - User: $_currentUser, Token: $_sessionToken');
        return {
          'success': true,
          'user': _currentUser,
          'session_token': _sessionToken,
          'message': 'Login successful'
        };
      } else {
        return {'success': false, 'error': response['error'] ?? 'Login failed'};
      }
    } catch (e) {
      print('Sign in error: $e');
      return {'success': false, 'error': 'Login failed: ${e.toString()}'};
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      if (_currentUser != null && _sessionToken != null) {
        // Invalidate session in database
        await _client.rpc('logout_user', params: {
          'session_token': _sessionToken,
        });
      }
    } catch (e) {
      print('Logout error: $e');
    } finally {
      _currentUser = null;
      _sessionToken = null;
      await _clearPersistedSession();
    }
  }

  // Validate Session
  Future<Map<String, dynamic>> validateSession() async {
    try {
      if (_sessionToken == null) {
        return {'success': false, 'error': 'No session token'};
      }

      final response = await _client.rpc('validate_session', params: {
        'session_token': _sessionToken,
      });

      if (response['success'] == true) {
        // Update current user data
        _currentUser = response['user'];
        await _persistSession();
        return response;
      } else {
        // Do not auto-clear; preserve session unless user signs out
        return response;
      }
    } catch (e) {
      print('Session validation error: $e');
      // Preserve session on errors
      return {
        'success': false,
        'error': 'Session validation failed: ${e.toString()}'
      };
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response =
          await _client.from('users').select().eq('id', userId).single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['full_name'] = fullName;
      if (phone != null) updateData['phone_number'] = phone;

      if (updateData.isNotEmpty) {
        updateData['updated_at'] = DateTime.now().toIso8601String();

        final response = await _client
            .from('users')
            .update(updateData)
            .eq('id', userId)
            .select()
            .single();

        // Update current user data
        if (_currentUser != null) {
          _currentUser!.addAll(response);
        }

        return {
          'success': true,
          'user': response,
          'message': 'Profile updated successfully'
        };
      }

      return {'success': false, 'error': 'No data to update'};
    } catch (e) {
      return {'success': false, 'error': 'Update failed: ${e.toString()}'};
    }
  }

  // Check if user exists
  Future<bool> userExists(String email) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Force refresh authentication state
  Future<void> refreshAuthState() async {
    print('🔄 Refreshing authentication state...');
    print('👤 Current user before refresh: $_currentUser');
    print('🎫 Current session token before refresh: $_sessionToken');

    if (_sessionToken != null) {
      try {
        final validationResult = await validateSession();
        if (validationResult['success'] == true) {
          _currentUser = validationResult['user'];
          print('✅ Auth state refreshed successfully');
        } else {
          print('❌ Auth state refresh failed: ${validationResult['error']}');
          // Keep existing session; do not clear
        }
      } catch (e) {
        print('❌ Auth state refresh error: $e');
        // Keep existing session
      }
    }

    print('👤 Current user after refresh: $_currentUser');
    print('🎫 Current session token after refresh: $_sessionToken');
  }

  // Check if session is valid
  Future<bool> isSessionValid() async {
    if (_sessionToken == null) return false;

    try {
      final response = await _client.rpc('validate_session', params: {
        'session_token': _sessionToken,
      });
      return response['valid'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_sessionToken != null) {
        await prefs.setString('session_token', _sessionToken!);
      }
      if (_currentUser != null) {
        await prefs.setString('current_user', jsonEncode(_currentUser));
      }
    } catch (e) {
      print('⚠️ Failed to persist session: $e');
    }
  }

  Future<void> _loadPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token');
      final userJson = prefs.getString('current_user');
      if (token != null) {
        _sessionToken = token;
      }
      if (userJson != null) {
        _currentUser = jsonDecode(userJson) as Map<String, dynamic>?;
      }
      if (_sessionToken != null || _currentUser != null) {
        print('🔒 Loaded persisted session');
      }
    } catch (e) {
      print('⚠️ Failed to load persisted session: $e');
    }
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_token');
      await prefs.remove('current_user');
    } catch (e) {
      print('⚠️ Failed to clear persisted session: $e');
    }
  }
}
