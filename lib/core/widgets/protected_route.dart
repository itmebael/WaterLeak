import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../../ui/views/login_view.dart';

class ProtectedRoute extends StatefulWidget {
  final Widget child;
  final String? redirectTo;
  final bool requireAdmin;

  const ProtectedRoute({
    Key? key,
    required this.child,
    this.redirectTo,
    this.requireAdmin = false,
  }) : super(key: key);

  @override
  _ProtectedRouteState createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<ProtectedRoute> {
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      // Add a small delay to ensure login process has completed
      await Future.delayed(Duration(milliseconds: 200));

      // Check if user is authenticated using our custom auth system
      final currentUser = _authService.currentUser;
      final sessionToken = _authService.sessionToken;

      print('🔍 ProtectedRoute: Checking authentication...');
      print('👤 Current user: $currentUser');
      print('🎫 Session token: $sessionToken');
      print('🔐 Is authenticated: ${_authService.isAuthenticated}');

      var authenticated = false;

      if (currentUser != null || sessionToken != null) {
        print('✅ User data or session token found, allowing access');
        authenticated = true;
      } else if (sessionToken != null && currentUser == null) {
        print(
            '🔄 Session token found but no user data, attempting validation...');
        try {
          final validationResult = await _authService.validateSession();
          print('✅ Session validation result: $validationResult');

          if (validationResult['success'] == true) {
            print('🎉 Session validation successful, showing dashboard');
            authenticated = true;
          }
        } catch (e) {
          print('❌ Session validation failed: $e');
        }
      }

      if (!authenticated) {
        print('🔄 No valid authentication found, redirecting to login...');
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => LoginView(),
              ),
            );
          }
        });
        return;
      }

      if (widget.requireAdmin) {
        final isAdmin = await _supabaseService.isCurrentUserAdmin();
        if (!isAdmin) {
          print('❌ User is not admin, redirecting to login...');
          setState(() {
            _isAuthenticated = false;
            _isLoading = false;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => LoginView(),
                ),
              );
            }
          });
          return;
        }
      }

      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ ProtectedRoute authentication check failed: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });

      // Redirect to login on error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LoginView(),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking authentication...'),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Redirecting to login...'),
            ],
          ),
        ),
      );
    }

    // User is authenticated, show the protected content
    return widget.child;
  }
}
