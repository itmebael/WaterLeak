import 'package:flutter/material.dart';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/ui/widgets/wave_widget.dart';
import 'package:waterleak/core/services/auth_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';
import 'dart:math' as math;

class LoginView extends StatefulWidget {
  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _formController;
  late AnimationController _waterLeakController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _formAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _waterLeakAnimation;

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isWaterLeaking = false;
  List<WaterDrop> _waterDrops = [];

  // Text controllers for form fields
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();

    // Initialize text controllers
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    _backgroundController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _formController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _waterLeakController = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _formAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutBack,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    ));

    _waterLeakAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waterLeakController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    _backgroundController.forward();
    await Future.delayed(Duration(milliseconds: 500));
    _formController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _backgroundController.dispose();
    _formController.dispose();
    _waterLeakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dashboard preview underneath (will be revealed)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1e3c72),
                    Color(0xFF2193b0),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.dashboard,
                      size: r.largeIconSize,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    SizedBox(height: r.mediumSpacing),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: r.titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: r.smallSpacing),
                    Text(
                      'Welcome to WaterLeak!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: r.bodyFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Login screen content that slides down
          AnimatedBuilder(
            animation: _waterLeakAnimation,
            builder: (context, child) {
              final slideOffset = _isWaterLeaking
                  ? _waterLeakAnimation.value * size.height
                  : 0.0;

              return Transform.translate(
                offset: Offset(0, slideOffset),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: Stack(
                    children: [
                      // Blue background gradient (same as home)
                      AnimatedBuilder(
                        animation: _backgroundAnimation,
                        builder: (context, child) {
                          return Container(
                            height: size.height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1e3c72),
                                  Color(0xFF2193b0),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Wave effect at the top
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Transform.rotate(
                          angle: 3.14159, // 180 degrees to flip the wave
                          child: WaveWidget(
                            size: Size(size.width, r.isSmallPhone ? 100 : 150),
                            yOffset: r.isSmallPhone ? 30 : 50,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),

                      // Second wave layer at top
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Transform.rotate(
                          angle: 3.14159, // 180 degrees to flip the wave
                          child: WaveWidget(
                            size: Size(size.width, r.isSmallPhone ? 80 : 100),
                            yOffset: r.isSmallPhone ? 20 : 30,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                      ),

                      // Floating particles
                      ...List.generate(
                          15, (index) => _buildFloatingParticle(index)),

                      // Back button with animation
                      Positioned(
                        top: r.isSmallPhone ? 40 : 50,
                        left: r.horizontalPadding(phone: 20, narrow: 16),
                        child: FadeTransition(
                          opacity: _formAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.cardRadius),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.arrow_back,
                                  color: Colors.white, size: r.iconSize),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),

                      // Login title with animation
                      Positioned(
                        top: r.isSmallPhone ? 80 : 120,
                        left: 0,
                        right: 0,
                        child: FadeTransition(
                          opacity: _formAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, -0.3),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: _formController,
                              curve: Curves.easeOutBack,
                            )),
                            child: Center(
                              child: Text(
                                'Welcome Back',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.isSmallPhone ? 32 : 42,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Main content card with animation (moved up)
                      Positioned(
                        left: 0,
                        right: 0,
                        // Push the form lower on screen; still shift up when keyboard is open
                        top: size.height * (keyboardOpen ? 0.22 : 0.42),
                        bottom: 0,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _formAnimation,
                            child: Container(
                              width: double.infinity,
                              margin: r.screenPadding(phone: 20, narrow: 16),
                              padding: EdgeInsets.all(r.mediumSpacing),
                              constraints: BoxConstraints(
                                maxWidth: r.isDesktop ? 640 : 520,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(r.cardRadius),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 20,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: SingleChildScrollView(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Center the form fields within the card on all screen sizes.
                                    final maxFieldWidth =
                                        r.isDesktop ? 520.0 : 440.0;
                                    final fieldWidth = constraints.maxWidth
                                        .clamp(0.0, maxFieldWidth)
                                        .toDouble();

                                    return Center(
                                      child: SizedBox(
                                        width: fieldWidth,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Email field
                                            _buildModernTextField(
                                              hintText: 'Email',
                                              prefixIcon: Icons.email_outlined,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              controller: _emailController,
                                              r: r,
                                            ),
                                            SizedBox(height: r.mediumSpacing),

                                            // Password field
                                            _buildModernTextField(
                                              hintText: 'Password',
                                              prefixIcon: Icons.lock_outline,
                                              isPassword: true,
                                              suffixIcon: _isPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              onSuffixTap: () {
                                                setState(() {
                                                  _isPasswordVisible =
                                                      !_isPasswordVisible;
                                                });
                                              },
                                              controller: _passwordController,
                                              r: r,
                                            ),
                                            SizedBox(height: r.mediumSpacing),

                                            // Forgot password link
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: GestureDetector(
                                                onTap: () {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Forgot password functionality coming soon!'),
                                                      backgroundColor:
                                                          Color(0xFF1e3c72),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(r
                                                                    .cardRadius),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  'Forgot password?',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: r.bodyFontSize,
                                                    fontWeight: FontWeight.w600,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: r.mediumSpacing),

                                            // Login button
                                            _buildModernButton(
                                              onTap: _handleLogin,
                                              text: _isLoading
                                                  ? 'Signing In...'
                                                  : 'Sign In',
                                              isLoading: _isLoading,
                                              r: r,
                                            ),
                                            SizedBox(height: r.mediumSpacing),

                                            Center(
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.pushNamed(
                                                      context, '/signup');
                                                },
                                                child: RichText(
                                                  text: TextSpan(
                                                    text:
                                                        "Don't have an account? ",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize:
                                                            r.bodyFontSize),
                                                    children: [
                                                      TextSpan(
                                                        text: 'Sign Up',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize:
                                                              r.bodyFontSize,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Water leak animation overlay
          if (_isWaterLeaking)
            AnimatedBuilder(
              animation: _waterLeakAnimation,
              builder: (context, child) {
                return Positioned.fill(
                  child: Container(
                    color: Colors.transparent,
                    child: Stack(
                      children: _waterDrops
                          .map((drop) => _buildWaterDrop(drop))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWaterDrop(WaterDrop drop) {
    return AnimatedBuilder(
      animation: _waterLeakAnimation,
      builder: (context, child) {
        final progress = _waterLeakAnimation.value;
        final dropProgress = math.max(0, (progress * 3000 - drop.delay) / 2000);
        final r = Responsive(context);
        final yPosition = dropProgress * r.h;
        final opacity =
            dropProgress < 0.8 ? 1.0 : (1.0 - (dropProgress - 0.8) * 5);

        // Only show drop if it's within screen bounds
        if (yPosition > r.h) return SizedBox.shrink();

        return Positioned(
          left: drop.x,
          top: yPosition,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: drop.size,
              height: drop.size,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingParticle(int index) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Positioned(
          left: (index * 47) % Responsive(context).w,
          top: (index * 83) % Responsive(context).h,
          child: Opacity(
            opacity: 0.2,
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernTextField({
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    TextInputType? keyboardType,
    TextEditingController? controller,
    required Responsive r,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: r.bodyFontSize,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: Color(0xFF1e3c72),
            size: r.iconSize,
          ),
          suffixIcon: suffixIcon != null && onSuffixTap != null
              ? IconButton(
                  icon: Icon(
                    suffixIcon,
                    color: Color(0xFF1e3c72),
                    size: r.iconSize,
                  ),
                  onPressed: onSuffixTap,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: r.horizontalPadding(phone: 20, narrow: 16),
            vertical: r.isSmallPhone ? 16 : 18,
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required VoidCallback onTap,
    required String text,
    bool isLoading = false,
    required Responsive r,
  }) {
    return Container(
      width: double.infinity,
      height: r.buttonHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1e3c72),
            Color(0xFF2193b0),
          ],
        ),
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1e3c72).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(r.cardRadius),
          child: Container(
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: r.isSmallPhone ? 20 : 24,
                      height: r.isSmallPhone ? 20 : 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.isSmallPhone ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter both email and password'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 🔐 HARD-CODED ADMIN LOGIN (NO SUPABASE)
      if (email == 'admin@waterleak.com' && password == 'admin123') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin login successful!'),
            backgroundColor: Colors.green,
          ),
        );

        final authService = AuthService();
        await authService.setHardcodedAdminSession(email: email);
        Navigator.of(context).pushReplacementNamed('/admin');
        return;
      }

      // 🔐 NORMAL USER LOGIN (SUPABASE)
      final authService = AuthService();
      final result = await authService.signIn(
        email: email,
        password: password,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
          ),
        );

        final isAdmin = await SupabaseService().isCurrentUserAdmin();
        Navigator.of(context)
            .pushReplacementNamed(isAdmin ? '/admin' : '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['error'] ?? 'Login failed. Please check your credentials.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class WaterDrop {
  final double x;
  final double delay;
  final double size;

  WaterDrop({
    required this.x,
    required this.delay,
    required this.size,
  });
}
