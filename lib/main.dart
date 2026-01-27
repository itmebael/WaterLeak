import 'package:flutter/material.dart';
import 'package:waterleak/ui/views/home_view.dart';
import 'package:waterleak/ui/views/login_view.dart';
import 'package:waterleak/ui/views/signup_view.dart';
import 'package:waterleak/ui/views/dashboard_view.dart';
import 'package:waterleak/ui/views/user_view.dart';
import 'package:waterleak/ui/views/about_view.dart';
import 'package:waterleak/ui/views/pipeline_view.dart';
import 'package:waterleak/ui/views/switch_view.dart';
import 'package:waterleak/ui/views/history_view.dart';
import 'package:waterleak/ui/views/contact_view.dart';
import 'package:waterleak/ui/views/admin_view.dart';
import 'package:waterleak/core/services/auth_service.dart';
import 'package:waterleak/core/widgets/protected_route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Auth Service
  try {
    await AuthService().initialize();
    print('✅ AuthService initialized successfully');
  } catch (e) {
    print('❌ AuthService initialization failed: $e');
    // Continue anyway to show the error in the UI
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Water Leak Detection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeView(),
        '/login': (context) => LoginView(),
        '/signup': (context) => SignupView(),
        '/dashboard': (context) => ProtectedRoute(child: DashboardView()),
        '/user': (context) => ProtectedRoute(child: UserView()),
        '/about': (context) => ProtectedRoute(child: AboutView()),
        '/pipeline': (context) => ProtectedRoute(child: PipelineView()),
        '/switch': (context) => ProtectedRoute(child: SwitchView()),
        '/history': (context) => ProtectedRoute(child: HistoryView()),
        '/contact': (context) => ProtectedRoute(child: ContactView()),
        '/admin': (context) =>
            ProtectedRoute(child: AdminView(), requireAdmin: true),
      },
    );
  }
}
