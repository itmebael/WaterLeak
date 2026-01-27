import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:waterleak/ui/shared/responsive.dart';

class SplashView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2193b0), // blue
                  Color(0xFF6dd5ed), // light blue
                  Color(0xFF1e3c72), // deep blue
                ],
              ),
            ),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r.cardRadius),
              child: Container(
                width: r.isSmallPhone ? 280 : 320,
                padding: EdgeInsets.symmetric(
                  horizontal: r.horizontalPadding(phone: 32, narrow: 24),
                  vertical: r.isSmallPhone ? 32 : 40,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(r.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: r.isSmallPhone ? 40 : 56,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.water_drop,
                          size: r.isSmallPhone ? 40 : 56,
                          color: Color(0xFF2193b0),
                        ),
                      ),
                      SizedBox(height: r.isSmallPhone ? 24 : 32),
                      Text(
                        'Waterleak',
                        style: TextStyle(
                          fontSize: r.isSmallPhone ? 28 : 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: r.isSmallPhone ? 12 : 16),
                      Text(
                        'Detect. Prevent. Save.',
                        style: TextStyle(
                          fontSize: r.isSmallPhone ? 14 : 18,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.1,
                        ),
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
}
