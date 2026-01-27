import 'package:flutter/material.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class AboutView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: Color(0xFF1e3c72),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF1e3c72)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About WaterLeak',
          style: TextStyle(
            color: Color(0xFF1e3c72),
            fontSize: r.isSmallPhone ? 16 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: r.screenPadding(phone: 20, narrow: 16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: r.screenPadding(phone: 25, narrow: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.cardRadius),
                border: Border.all(
                  color: Color(0xFF1e3c72),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.water_drop,
                    size: r.isSmallPhone ? 50 : 60,
                    color: Color(0xFF1e3c72),
                  ),
                  SizedBox(height: r.isSmallPhone ? 16 : 20),
                  Text(
                    'WaterLeak',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 24 : 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3c72),
                    ),
                  ),
                  SizedBox(height: r.isSmallPhone ? 8 : 10),
                  Text(
                    'Smart Water Leak Detection',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 14 : 18,
                      color: Color(0xFF1e3c72),
                    ),
                  ),
                  SizedBox(height: r.isSmallPhone ? 16 : 20),
                  Text(
                    'WaterLeak is a revolutionary smart water leak detection system that helps you monitor and protect your home from water damage.',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 14 : 16,
                      color: Color(0xFF1e3c72),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: r.isSmallPhone ? 24 : 30),
            Container(
              width: double.infinity,
              padding: r.screenPadding(phone: 25, narrow: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.cardRadius),
                border: Border.all(
                  color: Color(0xFF1e3c72),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Features',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 16 : 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3c72),
                    ),
                  ),
                  SizedBox(height: r.isSmallPhone ? 16 : 20),
                  _buildFeatureItem(Icons.sensors, 'Smart Sensors', r),
                  _buildFeatureItem(
                      Icons.notifications_active, 'Real-time Alerts', r),
                  _buildFeatureItem(Icons.analytics, 'Analytics', r),
                  _buildFeatureItem(Icons.security, 'Secure', r),
                  _buildFeatureItem(Icons.cloud, 'Cloud Sync', r),
                ],
              ),
            ),
            SizedBox(height: r.isSmallPhone ? 24 : 30),
            Container(
              width: double.infinity,
              padding: r.screenPadding(phone: 25, narrow: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.cardRadius),
                border: Border.all(
                  color: Color(0xFF1e3c72),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '© 2024 WaterLeak. All rights reserved.',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 12 : 14,
                      color: Color(0xFF1e3c72),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: r.isSmallPhone ? 8 : 10),
                  Text(
                    'Made with ❤️ for water conservation',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 12 : 14,
                      color: Color(0xFF1e3c72),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.isSmallPhone ? 6 : 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: Color(0xFF1e3c72),
            size: r.isSmallPhone ? 20 : 24,
          ),
          SizedBox(width: r.isSmallPhone ? 12 : 15),
          Text(
            title,
            style: TextStyle(
              fontSize: r.isSmallPhone ? 14 : 16,
              color: Color(0xFF1e3c72),
            ),
          ),
        ],
      ),
    );
  }
}
