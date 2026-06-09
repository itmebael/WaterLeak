import 'package:flutter/material.dart';
import 'package:waterleak/ui/widgets/wave_widget.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class HomeView extends StatefulWidget {
  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _buttonController;
  late Animation<double> _logoAnimation;
  late Animation<double> _buttonAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _buttonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutCubic,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(Duration(milliseconds: 300));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
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
          // Blue background gradient
          Container(
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
          ),

          // Animated wave effect using WaveWidget
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: WaveWidget(
              size: Size(size.width, r.isSmallPhone ? 150 : 200),
              yOffset: r.isSmallPhone ? 100 : 150,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),

          // Second wave layer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: WaveWidget(
              size: Size(size.width, r.isSmallPhone ? 120 : 150),
              yOffset: r.isSmallPhone ? 80 : 120,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),

          // Floating particles effect
          ...List.generate(20, (index) => _buildFloatingParticle(index)),

          // (removed) background logo watermarks

          // Welcome title with University Logo
          Positioned(
            top: r.isVerySmallPhone ? 60 : (r.isSmallPhone ? 80 : 120),
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  // Animated University Logo (no white background)
                  ScaleTransition(
                    scale: _logoAnimation,
                    child: Builder(
                      builder: (context) {
                        final base = r.isVerySmallPhone
                            ? 80.0
                            : (r.isSmallPhone ? 100.0 : 140.0);
                        // 2x bigger, but clamp so it stays usable on small screens
                        final logoSize =
                            (base * 2).clamp(120.0, r.w * 0.65).toDouble();

                        return Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                          width: logoSize,
                          height: logoSize,
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height:
                        r.isVerySmallPhone ? 15 : (r.isSmallPhone ? 20 : 30),
                  ),
                ],
              ),
            ),
          ),

          // Welcome message and Get Started button
          Positioned(
            left: 0,
            right: 0,
            top: size.height *
                (r.isVerySmallPhone ? 0.45 : (r.isSmallPhone ? 0.5 : 0.6)),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _buttonAnimation,
                child: Container(
                  width: double.infinity,
                  padding:
                      r.screenPadding(phone: 40, narrow: 20, veryNarrow: 16),
                  child: Column(
                    children: [
                      // Welcome message (glassmorphism style)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.horizontalPadding(
                              phone: 20, narrow: 16, veryNarrow: 12),
                          vertical: r.isVerySmallPhone
                              ? 10
                              : (r.isSmallPhone ? 12 : 15),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.cardRadius),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                          ),
                          ],
                        ),
                        child: Text(
                          'WELCOME TO WATERLEAK!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.isVerySmallPhone
                                ? 16
                                : (r.isSmallPhone ? 18 : 24),
                            fontWeight: FontWeight.bold,
                            letterSpacing: r.isVerySmallPhone ? 0.8 : 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                          height: r.isVerySmallPhone
                              ? 20
                              : (r.isSmallPhone ? 30 : 40)),

                      // Modern Get Started button (glassmorphism style)
                      _buildModernButton(
                        onTap: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        text: 'GET STARTED',
                        icon: Icons.arrow_forward,
                        r: r,
                      ),
                    ],
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
      animation: _logoController,
      builder: (context, child) {
        return Positioned(
          left: (index * 37) % Responsive(context).w,
          top: (index * 73) % Responsive(context).h,
          child: Opacity(
            opacity: 0.3,
            child: Container(
              width: 4,
              height: 4,
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

  Widget _buildModernButton({
    required VoidCallback onTap,
    required String text,
    required IconData icon,
    required Responsive r,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: double.infinity,
            height: r.buttonHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.cardRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(r.cardRadius),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.horizontalPadding(
                        phone: 30, narrow: 20, veryNarrow: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.isVerySmallPhone
                                ? 14
                                : (r.isSmallPhone ? 16 : 18),
                            fontWeight: FontWeight.bold,
                            letterSpacing: r.isVerySmallPhone ? 0.8 : 1.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(
                            r.isVerySmallPhone ? 4 : (r.isSmallPhone ? 6 : 8)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: r.isVerySmallPhone
                              ? 14
                              : (r.isSmallPhone ? 16 : 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
