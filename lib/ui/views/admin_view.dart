import 'dart:ui' show ImageFilter;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/core/services/auth_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart' show ListToCsvConverter;
import 'package:path_provider/path_provider.dart';

class AdminView extends StatefulWidget {
  @override
  _AdminViewState createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;
  late Animation<Offset> _slideAnimation;
  late TabController _tabController;

  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = true;
  String _dataPeriod = 'day';
  bool _loadingContacts = true;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _loadingAnnouncements = true;
  
  // Report filters
  DateTime? _reportStartDate;
  DateTime? _reportEndDate;
  String? _reportLeakFilter; // null = all, 'leak' = leaks only, 'no_leak' = no leaks

  // Palette (from your screenshot): deep navy -> blue -> cyan
  static const Color _navy = Color(0xFF000A63);
  static const Color _blue = Color(0xFF0B84B9);
  static const Color _cyan = Color(0xFF06B6D4);

  // Subtle container tint (same palette, low opacity so it's not eye-catchy)
  static const Color _containerBlue1 = Color(0xFF00136F); // close to navy
  static const Color _containerBlue2 = Color(0xFF0B6FA3); // close to blue

  Widget _glass({
    required Widget child,
    double radius = 22,
    EdgeInsets? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _containerBlue1.withValues(alpha: 0.14),
                _containerBlue2.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _logoWatermark({
    required Alignment alignment,
    required double size,
    required double opacity,
  }) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Opacity(
          opacity: opacity,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.white.withValues(alpha: 0.9),
              BlendMode.srcIn,
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _contentController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _tabController = TabController(length: 5, vsync: this);

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _contentAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutBack,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOutCubic,
    ));

    _startAnimations();
    _loadUsers();
    _loadContacts();
    _loadAnnouncements();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _startAnimations() async {
    _backgroundController.forward();
    await Future.delayed(Duration(milliseconds: 500));
    _contentController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _glass(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to logout?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.9),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        try {
                          await _authService.signOut();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/',
                              (route) => false,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error during logout: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue.withValues(alpha: 0.70),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _navy,
                      _blue,
                      _cyan.withValues(alpha: 0.80),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              );
            },
          ),

          // Logo watermarks (2x)
          _logoWatermark(
            alignment: const Alignment(-0.95, -0.55),
            size: 150,
            opacity: 0.07,
          ),
          _logoWatermark(
            alignment: const Alignment(0.95, 0.75),
            size: 190,
            opacity: 0.08,
          ),

          // Floating particles
          ...List.generate(20, (index) => _buildFloatingParticle(index)),

          // Modern AppBar (glass)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _contentAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _glass(
                  radius: 26,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 12,
                    right: 12,
                    bottom: 12,
                  ),
                  child: Row(
                    children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Panel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8),
                            TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              labelColor: Colors.white,
                              unselectedLabelColor:
                                  Colors.white.withValues(alpha: 0.6),
                              indicatorColor: _cyan.withValues(alpha: 0.95),
                              indicatorWeight: 3,
                              tabs: const [
                                Tab(text: 'Analytics'),
                                Tab(text: 'Announcements'),
                                Tab(text: 'Data'),
                                Tab(text: 'Users'),
                                Tab(text: 'Contacts'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _glass(
                          radius: 16,
                          child: IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                            onPressed: _showLogoutDialog,
                            padding: const EdgeInsets.all(10),
                            tooltip: 'Logout',
                          ),
                        ),
                        const SizedBox(width: 10),
                        _glass(
                          radius: 16,
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white, size: 20),
                            onPressed: () {
                              if (_tabController.index == 3) {
                                _showAddUserDialog();
                              } else if (_tabController.index == 4) {
                                _showAddContactDialog('plumber');
                              } else if (_tabController.index == 1) {
                                _showAddAnnouncementDialog();
                              }
                            },
                            padding: const EdgeInsets.all(10),
                            tooltip: 'Add',
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          Positioned(
            top: MediaQuery.of(context).padding.top + 152,
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _contentAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final r = Responsive(context);
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAnalyticsTab(r),
                        _buildAnnouncementsTab(r),
                        _buildDataTab(r),
                        _buildUsersTab(r),
                        _buildContactsTab(r),
                      ],
                    );
                  },
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
        final r = Responsive(context);
        return Positioned(
          left: (index * 47) % r.w,
          top: (index * 83) % r.h,
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

  Widget _buildSearchBar(Responsive r) {
    // Keep the search container nicely inset/centered so it doesn't look stretched
    // on small devices or too wide on large screens.
    final double maxW = r.isDesktop ? 860 : (r.isTablet ? 720 : double.infinity);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.isPhone ? 0 : 6),
          child: _glass(
            radius: r.cardRadius,
            padding: EdgeInsets.all(r.smallSpacing),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search devices...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = date is String ? DateTime.parse(date) : date as DateTime;
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _loadingUsers = true;
      });
      final users = await _supabaseService.getAllUsers();
      setState(() {
        _users = users;
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _loadingUsers = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _loadingContacts = true;
      });
      final contacts = await _supabaseService.getEmergencyContacts();
      setState(() {
        _contacts = contacts;
        _loadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _loadingContacts = false;
      });
    }
  }

  Future<void> _loadAnnouncements() async {
    try {
      setState(() {
        _loadingAnnouncements = true;
      });
      final items =
          await _supabaseService.getAnnouncements(includeInactive: true);
      setState(() {
        _announcements = items;
        _loadingAnnouncements = false;
      });
    } catch (e) {
      setState(() {
        _loadingAnnouncements = false;
      });
    }
  }


  Widget _buildAnalyticsTab(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: r.horizontalPadding(phone: 12, narrow: 10, veryNarrow: 8),
      ).add(EdgeInsets.only(top: r.mediumSpacing)),
      child: Column(
        children: [
          _buildSearchBar(r),
          SizedBox(height: r.mediumSpacing),
          FutureBuilder<Map<String, dynamic>>(
            future: _supabaseService.getWaterDataSummary(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.mediumSpacing),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(r.cardRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics Summary',
                      style: TextStyle(
                        fontSize: r.isSmallPhone ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: r.mediumSpacing),
                    Wrap(
                      spacing: r.smallSpacing,
                      runSpacing: r.smallSpacing,
                      children: [
                        _buildStatCard(r, 'Total Used', '${data['totalWaterUsed'] ?? 0} L'),
                        _buildStatCard(r, 'Avg Flow', '${data['averageFlowRate'] ?? 0} L/min'),
                        _buildStatCard(r, 'Max Flow', '${data['maxFlowRate'] ?? 0} L/min'),
                        _buildStatCard(r, 'Leaks', '${data['leakDetections'] ?? 0}'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: r.mediumSpacing),
          _buildAnalyticsChart(r),
          SizedBox(height: r.mediumSpacing),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.mediumSpacing),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.cardRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Overview',
                  style: TextStyle(
                    fontSize: r.isSmallPhone ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: r.smallSpacing),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabaseService.getWaterDataGroupedByDay(days: 7),
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? [];
                    return Column(
                      children: list
                          .map((d) => _buildDayRow(
                                r,
                                d['dayName'] ?? '',
                                d['date'] ?? '',
                                d['totalWaterUsed'] ?? 0,
                                d['maxFlowRate'] ?? 0,
                                d['leakDetections'] ?? 0,
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsChart(Responsive r) {
    return _glass(
      radius: r.cardRadius,
      padding: EdgeInsets.all(r.mediumSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 7 Days Usage',
            style: TextStyle(
              fontSize: r.isSmallPhone ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: r.smallSpacing),
          SizedBox(
            height: 220,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _supabaseService.getWaterDataGroupedByDay(days: 7),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                    ),
                  );
                }

                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      'No usage data for the last 7 days',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }

                final spots = <FlSpot>[];
                double maxY = 0;
                for (int i = 0; i < data.length; i++) {
                  final value =
                      (data[i]['totalWaterUsed'] as num?)?.toDouble() ?? 0.0;
                  spots.add(FlSpot(i.toDouble(), value));
                  if (value > maxY) {
                    maxY = value;
                  }
                }

                if (maxY == 0) {
                  maxY = 1;
                }

                return LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= data.length) {
                              return SizedBox.shrink();
                            }
                            final dayName =
                                data[index]['dayName']?.toString() ?? '';
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                dayName.length > 3
                                    ? dayName.substring(0, 3)
                                    : dayName,
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: maxY / 4,
                          getTitlesWidget: (value, meta) {
                            if (value < 0) {
                              return SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (data.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY * 1.2,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.cyanAccent,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.cyanAccent
                              .withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(Responsive r, String title, String value) {
    return SizedBox(
      width: r.isSmallPhone ? (r.w - 40) / 2 : (r.w - 80) / 3,
      child: _glass(
        radius: r.cardRadius,
        padding: EdgeInsets.all(r.mediumSpacing),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: r.isSmallPhone ? 16 : 18,
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildDayRow(Responsive r, String day, String date, dynamic used, dynamic flow, dynamic leaks) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$day $date',
              style: TextStyle(color: Colors.white),
            ),
          ),
          Text(
            '${used.toString()} L',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          SizedBox(width: 12),
          Text(
            '${flow.toString()} L/min',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          SizedBox(width: 12),
          Text(
            'Leaks: ${leaks.toString()}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab(Responsive r) {
    if (_loadingAnnouncements) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: r.horizontalPadding(phone: 12, narrow: 10, veryNarrow: 8),
      ).add(EdgeInsets.only(top: r.mediumSpacing)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.mediumSpacing),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.cardRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Announcements (${_announcements.length})',
                  style: TextStyle(
                    fontSize: r.isSmallPhone ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadAnnouncements,
                  icon: Icon(Icons.refresh, color: Colors.white, size: 18),
                  label: Text(
                    'Refresh',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.mediumSpacing),
          if (_announcements.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(r.mediumSpacing),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.cardRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Text(
                'No announcements yet.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            )
          else
            ..._announcements.map((a) => _buildAnnouncementCard(r, a)),
          SizedBox(height: r.mediumSpacing),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Responsive r, Map<String, dynamic> a) {
    final id = a['id']?.toString();
    final title = (a['title'] ?? 'Announcement').toString();
    final message = (a['message'] ?? a['body'] ?? '').toString();
    final createdAt = a['created_at'];
    final isActive = a['is_active'] == true;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: r.smallSpacing),
      child: _glass(
        radius: r.cardRadius,
        padding: EdgeInsets.all(r.mediumSpacing),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(r.smallSpacing),
            decoration: BoxDecoration(
              color: (isActive ? Colors.green : Colors.grey)
                  .withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(r.cardRadius),
            ),
            child: Icon(
              Icons.campaign,
              color: Colors.white,
              size: r.isSmallPhone ? 20 : 24,
            ),
          ),
          SizedBox(width: r.mediumSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: r.isSmallPhone ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isActive ? Colors.green : Colors.grey)
                            .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Hidden',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.isSmallPhone ? 11 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.smallSpacing),
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 12 : 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                SizedBox(height: r.smallSpacing),
                if (createdAt != null)
                  Text(
                    'Posted: ${_formatDate(createdAt)}',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 11 : 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue[300], size: 22),
            onPressed: id == null ? null : () => _showEditAnnouncementDialog(a),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red[300], size: 22),
            onPressed:
                id == null ? null : () => _showDeleteAnnouncementDialog(a),
            tooltip: 'Delete',
          ),
        ],
        ),
      ),
    );
  }

  void _showAddAnnouncementDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Add Announcement',
                style: TextStyle(color: Color(0xFF1e3c72)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Text('Visible to users', style: TextStyle(color: Colors.black87))),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setLocal(() => isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final msg = messageController.text.trim();
                    if (title.isEmpty || msg.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Title and message are required')),
                      );
                      return;
                    }
                    try {
                      await _supabaseService.createAnnouncement({
                        'title': title,
                        'message': msg,
                        'is_active': isActive,
                      });
                      await _loadAnnouncements();
                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding announcement: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1e3c72),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditAnnouncementDialog(Map<String, dynamic> a) {
    final announcementId = a['id']?.toString();
    if (announcementId == null) return;

    final titleController = TextEditingController(text: (a['title'] ?? '').toString());
    final messageController =
        TextEditingController(text: (a['message'] ?? a['body'] ?? '').toString());
    bool isActive = a['is_active'] == true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              backgroundColor: Colors.transparent,
              title: Text('Edit Announcement'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Text('Visible to users')),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setLocal(() => isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final msg = messageController.text.trim();
                    if (title.isEmpty || msg.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Title and message are required')),
                      );
                      return;
                    }
                    try {
                      await _supabaseService.updateAnnouncement(announcementId, {
                        'title': title,
                        'message': msg,
                        'is_active': isActive,
                      });
                      await _loadAnnouncements();
                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating announcement: $e')),
                        );
                      }
                    }
                  },
                  child: Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteAnnouncementDialog(Map<String, dynamic> a) {
    final announcementId = a['id']?.toString();
    if (announcementId == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          title: Text('Delete Announcement'),
          content: Text('Are you sure you want to delete this announcement?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _supabaseService.deleteAnnouncement(announcementId);
                  await _loadAnnouncements();
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting announcement: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataTab(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: r.horizontalPadding(phone: 12, narrow: 10, veryNarrow: 8),
      ).add(EdgeInsets.only(top: r.mediumSpacing)),
      child: Column(
        children: [
          // Download Report Section
          _glass(
            radius: r.cardRadius,
            padding: EdgeInsets.all(r.mediumSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Download Report',
                      style: TextStyle(
                        fontSize: r.isSmallPhone ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Download',
                      color: Colors.white,
                      icon: Icon(Icons.download, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'water') {
                          _downloadReport();
                        } else if (value == 'admin') {
                          _downloadAdminReport();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'water',
                          child: Text('Water Report (CSV)'),
                        ),
                        PopupMenuItem(
                          value: 'admin',
                          child: Text('Admin Report (CSV)'),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: r.mediumSpacing),
                // Date Range Filters
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _reportStartDate ?? DateTime.now().subtract(Duration(days: 7)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _reportStartDate = date);
                          }
                        },
                        child: _glass(
                          radius: 12,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _reportStartDate == null
                                      ? 'Start Date'
                                      : '${_reportStartDate!.day}/${_reportStartDate!.month}/${_reportStartDate!.year}',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _reportEndDate ?? DateTime.now(),
                            firstDate: _reportStartDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _reportEndDate = date);
                          }
                        },
                        child: _glass(
                          radius: 12,
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _reportEndDate == null
                                      ? 'End Date'
                                      : '${_reportEndDate!.day}/${_reportEndDate!.month}/${_reportEndDate!.year}',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.smallSpacing),
                // Leak Filter
                DropdownButtonFormField<String>(
                  value: _reportLeakFilter,
                  decoration: InputDecoration(
                    labelText: 'Leak Filter',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                  ),
                  dropdownColor: _navy,
                  style: TextStyle(color: Colors.white),
                  items: [
                    DropdownMenuItem(value: null, child: Text('All Records')),
                    DropdownMenuItem(value: 'leak', child: Text('Leaks Only')),
                    DropdownMenuItem(value: 'no_leak', child: Text('No Leaks')),
                  ],
                  onChanged: (value) {
                    setState(() => _reportLeakFilter = value);
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: r.mediumSpacing),
          Row(
            children: [
              ChoiceChip(
                label: Text('Day'),
                selected: _dataPeriod == 'day',
                onSelected: (_) => setState(() => _dataPeriod = 'day'),
              ),
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Week'),
                selected: _dataPeriod == 'week',
                onSelected: (_) => setState(() => _dataPeriod = 'week'),
              ),
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Month'),
                selected: _dataPeriod == 'month',
                onSelected: (_) => setState(() => _dataPeriod = 'month'),
               ),
               SizedBox(width: 8),
               ChoiceChip(
                 label: Text('Year'),
                 selected: _dataPeriod == 'year',
                 onSelected: (_) => setState(() => _dataPeriod = 'year'),
               ),
            ],
          ),
          SizedBox(height: r.mediumSpacing),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.mediumSpacing),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.cardRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _dataPeriod == 'day'
                  ? _supabaseService.getTodayWaterData()
                  : _dataPeriod == 'week'
                      ? _supabaseService.getWeeklyWaterData()
                      : _dataPeriod == 'month'
                          ? _supabaseService.getMonthlyWaterData()
                          : _supabaseService.getYearlyWaterData(),
              builder: (context, snapshot) {
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return Text(
                    'No data',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  );
                }
                return Column(
                  children: list.map((item) {
                    final created = item['created_at'] ?? item['timestamp'];
                    return Padding(
                      padding: EdgeInsets.only(bottom: r.smallSpacing),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              created?.toString() ?? '',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          Text(
                            '${(item['flow_rate'] ?? item['average_flow_rate'] ?? 0).toString()} L/min',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '${(item['total_used'] ?? item['total_consumption_liters'] ?? 0).toString()} L',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(Responsive r) {
    if (_loadingUsers) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: r.horizontalPadding(phone: 12, narrow: 10, veryNarrow: 8),
      ).add(EdgeInsets.only(top: r.mediumSpacing)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(r.mediumSpacing),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.cardRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Users (${_users.length})',
                  style: TextStyle(
                    fontSize: r.isSmallPhone ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton.icon(
                  onPressed: _loadUsers,
                  icon: Icon(Icons.refresh, color: Colors.white, size: 18),
                  label: Text(
                    'Refresh',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.mediumSpacing),
          ..._users.map((u) => _buildUserCard(u, r)),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, Responsive r) {
    final fullName =
        '${(user['first_name'] ?? '').toString()} ${(user['last_name'] ?? '').toString()}'
            .trim();

    return Padding(
      padding: EdgeInsets.only(bottom: r.smallSpacing),
      child: InkWell(
        onTap: () => _showUserDetailsDialog(user),
        borderRadius: BorderRadius.circular(r.cardRadius),
        child: _glass(
          radius: r.cardRadius,
          padding: EdgeInsets.all(r.mediumSpacing),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Unnamed User' : fullName,
                      style: TextStyle(
                        fontSize: r.isSmallPhone ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: r.isSmallPhone ? 2 : 4),
                    Text(
                      (user['email'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: r.isSmallPhone ? 12 : 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    if ((user['phone'] ?? '').toString().isNotEmpty)
                      Text(
                        (user['phone'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: r.isSmallPhone ? 12 : 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: Colors.white, size: 22),
                onPressed: () => _showEditUserDialog(user),
                tooltip: 'Edit User',
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red[300], size: 22),
                onPressed: () => _showDeleteUserDialog(user),
                tooltip: 'Delete User',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    final userId = user['id']?.toString();
    final fullName =
        '${(user['first_name'] ?? '').toString()} ${(user['last_name'] ?? '').toString()}'
            .trim();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName.isEmpty ? 'User Details' : fullName,
                          style: const TextStyle(
                            color: Color(0xFF1e3c72),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Color(0xFF1e3c72)),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email: ${(user['email'] ?? '').toString()}',
                    style: const TextStyle(color: Color(0xFF1e3c72)),
                  ),
                  if ((user['phone'] ?? '').toString().isNotEmpty)
                    Text(
                      'Phone: ${(user['phone'] ?? '').toString()}',
                      style: const TextStyle(color: Color(0xFF1e3c72)),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Water Usage',
                    style: TextStyle(
                      color: Color(0xFF1e3c72),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (userId == null)
                    const Text(
                      'No user id found.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    FutureBuilder<Map<String, dynamic>>(
                      future: _supabaseService.getUserWaterUsageSummary(
                        userId: userId,
                        days: 30,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: CircularProgressIndicator(
                                color: Color(0xFF1e3c72),
                              ),
                            ),
                          );
                        }

                        final data = snapshot.data ?? {};
                        final total =
                            (data['totalLiters'] as num?)?.toDouble() ?? 0.0;
                        final props =
                            (data['properties'] as List?)?.cast<Map<String, dynamic>>() ??
                                <Map<String, dynamic>>[];
                        final daily =
                            (data['daily'] as List?)?.cast<Map<String, dynamic>>() ??
                                <Map<String, dynamic>>[];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last 30 days: ${total.toStringAsFixed(2)} L',
                              style: const TextStyle(
                                color: Color(0xFF1e3c72),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Properties: ${props.length}',
                              style: const TextStyle(
                                color: Color(0xFF1e3c72),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (daily.isNotEmpty) ...[
                              const Text(
                                'Last 7 days:',
                                style: TextStyle(
                                  color: Color(0xFF1e3c72),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...daily.map((d) {
                                final date = (d['date'] ?? '').toString();
                                final liters =
                                    (d['liters'] as num?)?.toDouble() ?? 0.0;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          date,
                                          style: const TextStyle(
                                            color: Color(0xFF1e3c72),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${liters.toStringAsFixed(2)} L',
                                        style: const TextStyle(
                                          color: Color(0xFF1e3c72),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ] else
                              const Text(
                                'No consumption data found.',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddUserDialog() {
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          title: Text('Add User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.trim().isEmpty) return;
                try {
                  await _supabaseService.createUser({
                    'email': emailController.text.trim(),
                    'first_name': firstNameController.text.trim(),
                    'last_name': lastNameController.text.trim(),
                    'phone': phoneController.text.trim(),
                  });
                  await _loadUsers();
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {}
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final emailController = TextEditingController(text: user['email'] ?? '');
    final firstNameController = TextEditingController(text: user['first_name'] ?? '');
    final lastNameController = TextEditingController(text: user['last_name'] ?? '');
    final phoneController = TextEditingController(text: user['phone'] ?? '');
    final userId = user['id']?.toString();
    if (userId == null) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit User',
            style: TextStyle(color: Color(0xFF1e3c72)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
              ),
              SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _supabaseService.updateUser(userId, {
                    'email': emailController.text.trim(),
                    'first_name': firstNameController.text.trim(),
                    'last_name': lastNameController.text.trim(),
                    'phone': phoneController.text.trim(),
                  });
                  await _loadUsers();
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1e3c72),
                foregroundColor: Colors.white,
              ),
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadReport() async {
    try {
      // Validate date range
      if (_reportStartDate == null || _reportEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select start and end dates'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_reportStartDate!.isAfter(_reportEndDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Start date must be before end date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating report...'),
              ],
            ),
          ),
        ),
      );

      // Fetch water_connection_control snapshots with filters
      List<Map<String, dynamic>> waterData = [];
      try {
        waterData = await _supabaseService.getWaterConnectionControlByDateRange(
          startDate: _reportStartDate!,
          endDate: _reportEndDate!.add(Duration(days: 1)), // Include end date
          limit: 10000,
        );
      } catch (fetchError) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching data: $fetchError'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (waterData.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No data found for the selected date range'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Apply leak filter (snapshot heuristic based on flow thresholds)
      // Matches ESP32 logic: leak-like flow is between leakThreshold and startThreshold.
      const double leakThreshold = 0.2;
      const double startThreshold = 2.0;
      List<Map<String, dynamic>> filteredData = waterData;
      if (_reportLeakFilter == 'leak') {
        filteredData = waterData.where((item) {
          final flow = (item['water_flow'] as num?)?.toDouble() ?? 0.0;
          return flow > leakThreshold && flow < startThreshold;
        }).toList();
      } else if (_reportLeakFilter == 'no_leak') {
        filteredData = waterData.where((item) {
          final flow = (item['water_flow'] as num?)?.toDouble() ?? 0.0;
          return !(flow > leakThreshold && flow < startThreshold);
        }).toList();
      }

      if (filteredData.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No data matches the selected filters'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Fetch user information for user_id mapping
      final Map<String, Map<String, dynamic>> userIdToUserInfo = {};
      try {
        final userIds = filteredData
            .map((d) => d['user_id']?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();

        if (userIds.isNotEmpty) {
          final users = await _supabaseService.getAllUsers();
          final userMap = {for (var u in users) u['id']?.toString(): u};
          for (final uid in userIds) {
            final user = userMap[uid];
            if (user == null) continue;
            userIdToUserInfo[uid] = {
              'name': user['full_name'] ??
                  '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
              'email': user['email'] ?? 'N/A',
              'phone': user['phone'] ?? 'N/A',
            };
          }
        }
      } catch (e) {
        print('Error fetching user information: $e');
        // Continue without user info if fetch fails
      }

      // Generate CSV
      final csvData = <List<dynamic>>[];
      
      // Header
      csvData.add([
        'Updated Date',
        'Updated Time',
        'User Name',
        'User Email',
        'User Phone',
        'Device ID',
        'Device Name',
        'Location',
        'Valve Status',
        'Water Flow (L/min)',
        'Total Water Used (L)',
        'Pressure (PSI)',
        'Temperature (°C)',
        'Online',
        'Last Heartbeat',
        'Updated At',
        'Property ID',
      ]);

      // Data rows
      for (final item in filteredData) {
        final createdAt = item['updated_at'] ?? item['last_heartbeat'] ?? item['created_at'];
        DateTime? dateTime;
        if (createdAt != null) {
          if (createdAt is String) {
            dateTime = DateTime.tryParse(createdAt);
          } else if (createdAt is DateTime) {
            dateTime = createdAt;
          }
        }
        
        final date = dateTime != null
            ? '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}'
            : '';
        final time = dateTime != null
            ? '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}'
            : '';

        final valveStatus = (item['valve_status']?.toString().toLowerCase() == 'open')
            ? 'Open'
            : 'Closed';

        final userId = item['user_id']?.toString() ?? '';
        final userInfo = userIdToUserInfo[userId] ?? {
          'name': 'Unknown',
          'email': 'N/A',
          'phone': 'N/A',
        };

        csvData.add([
          date,
          time,
          userInfo['name'] ?? 'Unknown',
          userInfo['email'] ?? 'N/A',
          userInfo['phone'] ?? 'N/A',
          (item['device_id'] ?? '').toString(),
          (item['device_name'] ?? '').toString(),
          (item['location'] ?? '').toString(),
          valveStatus,
          ((item['water_flow'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
          ((item['total_water_used'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
          (item['pressure']?.toString() ?? ''),
          (item['temperature']?.toString() ?? ''),
          (item['is_online'] == true) ? 'Yes' : 'No',
          (item['last_heartbeat']?.toString() ?? ''),
          (item['updated_at']?.toString() ?? ''),
          (item['property_id']?.toString() ?? ''),
        ]);
      }

      // Convert to CSV string
      String csvString;
      try {
        csvString = const ListToCsvConverter().convert(csvData);
      } catch (csvError) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating CSV: $csvError'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Save file
      File? file;
      String fileName = '';
      try {
        final directory = await getApplicationDocumentsDirectory();
        fileName = 'water_report_${_reportStartDate!.year}${_reportStartDate!.month.toString().padLeft(2, '0')}${_reportStartDate!.day.toString().padLeft(2, '0')}_to_${_reportEndDate!.year}${_reportEndDate!.month.toString().padLeft(2, '0')}${_reportEndDate!.day.toString().padLeft(2, '0')}.csv';
        file = File('${directory.path}/$fileName');
        await file.writeAsString(csvString);
      } catch (fileError) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving file: $fileError'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Share file with fallback
      bool shareSuccess = false;
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Water Leak Detection Report',
          subject: 'Water Report ${_reportStartDate!.day}/${_reportStartDate!.month}/${_reportStartDate!.year} - ${_reportEndDate!.day}/${_reportEndDate!.month}/${_reportEndDate!.year}',
        );
        shareSuccess = true;
      } catch (shareError) {
        // Try alternative sharing method
        try {
          await Share.share(
            'Water Leak Detection Report\n\nFile saved to: ${file.path}',
            subject: 'Water Report ${_reportStartDate!.day}/${_reportStartDate!.month}/${_reportStartDate!.year} - ${_reportEndDate!.day}/${_reportEndDate!.month}/${_reportEndDate!.year}',
          );
          shareSuccess = true;
        } catch (shareError2) {
          // If both sharing methods fail, show file location dialog
          if (mounted) {
            _showFileLocationDialog(file.path, fileName);
          }
        }
      }

      if (mounted && shareSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report downloaded and shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Download report error: $e');
      if (mounted) {
        // Try to close loading dialog if it's still open
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // Dialog might already be closed
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _downloadAdminReport() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating admin report...'),
              ],
            ),
          ),
        ),
      );

      final users = await _supabaseService.getAllUsers();
      final contacts = await _supabaseService.getAllEmergencyContacts(limit: 10000);
      final devices = await _supabaseService.getWaterConnectionDevices();
      final leaks = await _supabaseService.getAllLeakDetections(limit: 10000);

      // Build CSV with sections
      final csvData = <List<dynamic>>[];
      final now = DateTime.now();

      csvData.add(['ADMIN REPORT']);
      csvData.add(['Generated At', now.toIso8601String()]);
      csvData.add(['Generated By', (_authService.currentUser?['email'] ?? '').toString()]);
      csvData.add([]);

      // USERS
      csvData.add(['USERS']);
      csvData.add([
        'id',
        'email',
        'first_name',
        'last_name',
        'full_name',
        'phone',
        'role',
        'created_at',
      ]);
      for (final u in users) {
        csvData.add([
          (u['id'] ?? '').toString(),
          (u['email'] ?? '').toString(),
          (u['first_name'] ?? '').toString(),
          (u['last_name'] ?? '').toString(),
          (u['full_name'] ?? '').toString(),
          (u['phone'] ?? '').toString(),
          (u['role'] ?? '').toString(),
          (u['created_at'] ?? '').toString(),
        ]);
      }
      csvData.add([]);

      // CONTACTS
      csvData.add(['CONTACTS (emergency_contacts)']);
      csvData.add([
        'id',
        'user_id',
        'name',
        'phone',
        'email',
        'contact_type',
        'is_primary',
        'address',
        'created_at',
      ]);
      for (final c in contacts) {
        csvData.add([
          (c['id'] ?? '').toString(),
          (c['user_id'] ?? '').toString(),
          (c['name'] ?? '').toString(),
          (c['phone'] ?? '').toString(),
          (c['email'] ?? '').toString(),
          (c['contact_type'] ?? '').toString(),
          (c['is_primary'] ?? '').toString(),
          (c['address'] ?? '').toString(),
          (c['created_at'] ?? '').toString(),
        ]);
      }
      csvData.add([]);

      // DEVICES
      csvData.add(['WATER DEVICES (water_connection_control)']);
      csvData.add([
        'device_id',
        'device_name',
        'location',
        'valve_status',
        'water_flow',
        'total_water_used',
        'is_online',
        'last_heartbeat',
        'updated_at',
        'user_id',
        'property_id',
      ]);
      for (final d in devices) {
        csvData.add([
          (d['device_id'] ?? '').toString(),
          (d['device_name'] ?? '').toString(),
          (d['location'] ?? '').toString(),
          (d['valve_status'] ?? '').toString(),
          (d['water_flow'] ?? '').toString(),
          (d['total_water_used'] ?? '').toString(),
          (d['is_online'] == true) ? 'Yes' : 'No',
          (d['last_heartbeat'] ?? '').toString(),
          (d['updated_at'] ?? '').toString(),
          (d['user_id'] ?? '').toString(),
          (d['property_id'] ?? '').toString(),
        ]);
      }
      csvData.add([]);

      // LEAKS
      csvData.add(['LEAK DETECTIONS (water_leak_detections)']);
      csvData.add([
        'id',
        'property_id',
        'segment_id',
        'detection_date',
        'leak_type',
        'severity',
        'status',
        'location_description',
        'estimated_water_loss_liters',
        'estimated_water_loss_rate',
        'flow_rate_anomaly',
        'resolved_date',
      ]);
      for (final l in leaks) {
        csvData.add([
          (l['id'] ?? '').toString(),
          (l['property_id'] ?? '').toString(),
          (l['segment_id'] ?? '').toString(),
          (l['detection_date'] ?? '').toString(),
          (l['leak_type'] ?? '').toString(),
          (l['severity'] ?? '').toString(),
          (l['status'] ?? '').toString(),
          (l['location_description'] ?? '').toString(),
          (l['estimated_water_loss_liters'] ?? '').toString(),
          (l['estimated_water_loss_rate'] ?? '').toString(),
          (l['flow_rate_anomaly'] ?? '').toString(),
          (l['resolved_date'] ?? '').toString(),
        ]);
      }

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'admin_report_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Share file with fallback
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Admin Report',
          subject: 'Admin Report ${now.toIso8601String()}',
        );
      } catch (_) {
        // If sharing fails (Windows), show file location
        if (mounted) _showFileLocationDialog(file.path, fileName);
      }
    } catch (e) {
      if (mounted) {
        // Try to close loading dialog if it's still open
        try {
          Navigator.of(context).pop();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating admin report: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showFileLocationDialog(String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Report Saved Successfully',
            style: TextStyle(color: Color(0xFF1e3c72)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File saved as:',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              SelectableText(
                fileName,
                style: TextStyle(
                  color: Color(0xFF1e3c72),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Location:',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              SelectableText(
                filePath,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'You can find the file in the Documents folder.',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(color: Color(0xFF1e3c72)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    final userId = user['id']?.toString();
    if (userId == null) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete User',
            style: TextStyle(color: Color(0xFF1e3c72)),
          ),
          content: Text(
            'Are you sure you want to delete this user?',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _supabaseService.deleteUser(userId);
                  await _loadUsers();
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactsTab(Responsive r) {
    if (_loadingContacts) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    final plumbers = _contacts.where((c) => (c['contact_type'] ?? '') == 'plumber').toList();
    final emergencies = _contacts.where((c) => (c['contact_type'] ?? '') == 'emergency').toList();
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: r.horizontalPadding(phone: 12, narrow: 10, veryNarrow: 8),
      ).add(EdgeInsets.only(top: r.mediumSpacing)),
      child: Column(
        children: [
          _buildContactsSection(r, 'Plumbers', plumbers, 'plumber'),
          SizedBox(height: r.mediumSpacing),
          _buildContactsSection(r, 'Emergency', emergencies, 'emergency'),
        ],
      ),
    );
  }

  Widget _buildContactsSection(Responsive r, String title, List<Map<String, dynamic>> items, String type) {
    return _glass(
      radius: r.cardRadius,
      padding: EdgeInsets.all(r.mediumSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$title (${items.length})',
                style: TextStyle(
                  fontSize: r.isSmallPhone ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton.icon(
                onPressed: _loadContacts,
                icon: Icon(Icons.refresh, color: Colors.white, size: 18),
                label: Text(
                  'Refresh',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: r.mediumSpacing),
          ...items.map((c) => _buildContactCard(r, c)),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _showAddContactDialog(type),
              icon: Icon(Icons.add),
              label: Text('Add $title'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Responsive r, Map<String, dynamic> c) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.smallSpacing),
      child: _glass(
        radius: r.cardRadius,
        padding: EdgeInsets.all(r.mediumSpacing),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['name'] ?? '',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: r.isSmallPhone ? 2 : 4),
                  if (c['phone'] != null)
                    Text(
                      c['phone'],
                      style: TextStyle(
                        fontSize: r.isSmallPhone ? 12 : 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  if (c['email'] != null)
                    Text(
                      c['email'],
                      style: TextStyle(
                        fontSize: r.isSmallPhone ? 12 : 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue[300], size: 22),
              onPressed: () => _showEditContactDialog(c),
              tooltip: 'Edit Contact',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red[300], size: 22),
              onPressed: () => _showDeleteContactDialog(c),
              tooltip: 'Delete Contact',
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(String type) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final companyController = TextEditingController();
    // Keep the original type (plumber stays as plumber, emergency stays as emergency)
    final contactType = type;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add ${type == 'plumber' ? 'Plumber' : 'Emergency'}',
            style: TextStyle(color: Color(0xFF1e3c72)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 10),
              TextField(
                controller: companyController,
                decoration: InputDecoration(
                  labelText: 'Company',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Name and Phone are required'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  await _supabaseService.createEmergencyContact({
                    'contact_type': contactType,
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'email': emailController.text.trim(),
                    'company': companyController.text.trim(),
                    'is_primary': true,
                    'is_active': true,
                  });
                  await _loadContacts();
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Contact added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('Error adding contact: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding contact: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1e3c72),
              ),
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditContactDialog(Map<String, dynamic> contact) {
    final id = contact['id']?.toString();
    if (id == null) return;
    final nameController = TextEditingController(text: contact['name'] ?? '');
    final phoneController = TextEditingController(text: contact['phone'] ?? '');
    final emailController = TextEditingController(text: contact['email'] ?? '');
    final companyController = TextEditingController(text: contact['company'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Edit Contact',
            style: TextStyle(color: Color(0xFF1e3c72)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 10),
              TextField(
                controller: companyController,
                decoration: InputDecoration(
                  labelText: 'Company',
                  labelStyle: TextStyle(color: Colors.black87),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Name and Phone are required'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  await _supabaseService.updateEmergencyContact(id, {
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'email': emailController.text.trim(),
                    'company': companyController.text.trim(),
                  });
                  await _loadContacts();
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Contact updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating contact: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1e3c72),
              ),
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteContactDialog(Map<String, dynamic> contact) {
    final id = contact['id']?.toString();
    if (id == null) return;
    final contactName = contact['name'] ?? 'this contact';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Contact',
            style: TextStyle(color: Color(0xFF1e3c72)),
          ),
          content: Text(
            'Are you sure you want to delete $contactName?',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _supabaseService.deleteEmergencyContact(id);
                  await _loadContacts();
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Contact deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting contact: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
