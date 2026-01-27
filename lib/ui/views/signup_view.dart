import 'package:flutter/material.dart';
import 'package:waterleak/ui/widgets/wave_widget.dart';
import 'package:waterleak/core/services/auth_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class SignupView extends StatefulWidget {
  @override
  _SignupViewState createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _formController;
  late AnimationController _buttonController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _formAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Form controllers
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  @override
  void initState() {
    super.initState();

    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _backgroundController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _formController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: Duration(milliseconds: 800),
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

    _startAnimations();
  }

  void _startAnimations() async {
    _backgroundController.forward();
    await Future.delayed(Duration(milliseconds: 500));
    _formController.forward();
    await Future.delayed(Duration(milliseconds: 300));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _backgroundController.dispose();
    _formController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
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
          ...List.generate(15, (index) => _buildFloatingParticle(index)),

          // Back button with animation
          Positioned(
            top: r.isSmallPhone ? 40 : 50,
            left: r.horizontalPadding(phone: 20, narrow: 16),
            child: FadeTransition(
              opacity: _formAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: Colors.white, size: r.isSmallPhone ? 24 : 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Create Account title with animation
          Positioned(
            top: r.isSmallPhone ? 80 : 100,
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
                    'Create Account',
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
            top: size.height * (r.isSmallPhone ? 0.2 : 0.25),
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _formAnimation,
                child: Container(
                  width: double.infinity,
                  margin: r.screenPadding(phone: 20, narrow: 16),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.horizontalPadding(phone: 20, narrow: 16),
                    vertical: r.verticalPadding(phone: 20, narrow: 16),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: r.isDesktop ? 640 : 520,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.cardRadius),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username field
                        _buildModernTextField(
                          hintText: 'Username',
                          prefixIcon: Icons.person_outline,
                          controller: _usernameController,
                          r: r,
                        ),
                        SizedBox(height: r.isSmallPhone ? 16 : 20),

                        // Email field
                        _buildModernTextField(
                          hintText: 'Email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                          r: r,
                        ),
                        SizedBox(height: r.isSmallPhone ? 16 : 20),

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
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                          controller: _passwordController,
                          r: r,
                        ),
                        SizedBox(height: r.isSmallPhone ? 16 : 20),

                        // Confirm Password field
                        _buildModernTextField(
                          hintText: 'Confirm Password',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          useConfirmPasswordVisibility: true, // Use confirm password visibility
                          suffixIcon: _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          onSuffixTap: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                          controller: _confirmPasswordController,
                          r: r,
                        ),
                        SizedBox(height: r.isSmallPhone ? 24 : 30),

                        // Register button
                        _buildModernButton(
                          onTap: _handleSignup,
                          text: _isLoading
                              ? 'Creating Account...'
                              : 'Create Account',
                          isLoading: _isLoading,
                          r: r,
                        ),
                        SizedBox(height: r.isSmallPhone ? 20 : 25),

                        // Login prompt
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/login');
                            },
                            child: RichText(
                              text: TextSpan(
                                text: "Already have an account? ",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: r.isSmallPhone ? 14 : 16),
                                children: [
                                  TextSpan(
                                    text: 'Sign In',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: r.isSmallPhone ? 14 : 16,
                                      decoration: TextDecoration.underline,
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
                ),
              ),
            ),
          ),
        ],
      ),
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
    bool useConfirmPasswordVisibility = false, // New parameter to distinguish fields
    IconData? suffixIcon,
    VoidCallback? onSuffixTap,
    TextInputType? keyboardType,
    TextEditingController? controller,
    required Responsive r,
  }) {
    // Determine which visibility flag to use
    bool shouldObscure = false;
    if (isPassword) {
      if (useConfirmPasswordVisibility) {
        shouldObscure = !_isConfirmPasswordVisible;
      } else {
        shouldObscure = !_isPasswordVisible;
      }
    }
    
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
        obscureText: shouldObscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle:
              TextStyle(color: Colors.grey[600], fontSize: r.bodyFontSize),
          prefixIcon: Icon(prefixIcon,
              color: Color(0xFF1e3c72), size: r.isSmallPhone ? 20 : 22),
          suffixIcon: suffixIcon != null && onSuffixTap != null
              ? IconButton(
                  icon: Icon(suffixIcon,
                      color: Color(0xFF1e3c72), size: r.isSmallPhone ? 20 : 22),
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

  void _handleSignup() async {
    setState(() => _isLoading = true);
    try {
      final firstName = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final confirm = _confirmPasswordController.text.trim();

      if ([firstName, email, password, confirm].any((v) => v.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please fill all fields'),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (password != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Passwords do not match'),
              backgroundColor: Colors.red),
        );
        return;
      }

      // Show detailed error information
      print('🔄 Starting registration process...');
      print('📧 Email: $email');
      print('👤 Name: $firstName');

      final result = await AuthService().signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: '',
        username: firstName, // Use the username field from the form
        phone: null,
      );

      print('📤 Registration result: $result');

      if (result['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to dashboard
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Sign up failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Sign up failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
