import 'package:flutter/material.dart';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class DashboardView extends StatefulWidget {
  @override
  _DashboardViewState createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _contentController;
  late AnimationController _navbarController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _contentAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _navbarAnimation;

  int _selectedIndex = 0;
  final SupabaseService _supabaseService = SupabaseService();

  // Database data
  List<Map<String, dynamic>> dailyConsumption = [];
  List<Map<String, dynamic>> monthlyConsumption = [];
  List<Map<String, dynamic>> leakAlerts = [];
  Map<String, dynamic> waterSavings = {};
  List<Map<String, dynamic>> properties = [];
  String? selectedPropertyId;
  bool isLoading = true;

  // Water data (from public.water_data)
  List<Map<String, dynamic>> weeklyUsage = [];
  List<Map<String, dynamic>> todayFlow = [];
  bool abnormalLeakDetected = false;

  bool get _actionsEnabled =>
      !isLoading && _supabaseService.currentUserId != null;

  // Safe math helpers
  double _numOr0(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  double _safeDiv(num? a, num? b) {
    final aa = (a ?? 0).toDouble();
    final bb = (b ?? 0).toDouble();
    if (bb == 0) return 0.0;
    return aa / bb;
  }

  // Dashboard uses water_connection_control (current snapshot).
  // This is total cumulative usage as reported by devices.
  double _calculateTotalUsed() {
    if (weeklyUsage.isEmpty) return 0.0;
    // We store today's bar as the current total used (see _loadWaterControlSeries).
    final today = weeklyUsage.lastOrNull;
    if (today == null) return 0.0;
    return _numOr0(today['usage']);
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

    _navbarController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

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

    _navbarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _navbarController,
      curve: Curves.easeOutCubic,
    ));

    _startAnimations();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Always load leaks, even if no property is selected
      try {
        // First try to get active leaks
        var leaks = await _supabaseService.getAllLeakDetections(status: 'active');
        
        // If no active leaks found, try without status filter (get all)
        if (leaks.isEmpty) {
          print('⚠️ No active leaks found, fetching all leaks');
          leaks = await _supabaseService.getAllLeakDetections();
        }
        
        String _cap(String v) =>
            v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
        leakAlerts = leaks.map((l) {
          final String severity =
              (l['severity'] ?? 'low').toString().toLowerCase();
          final Color color = severity == 'critical'
              ? Colors.purple
              : severity == 'high'
                  ? Colors.red
                  : severity == 'medium'
                      ? Colors.orange
                      : Colors.green;
          final status = (l['status'] ?? 'active').toString().toLowerCase();
          return {
            'id': l['id'],
            'location': l['location_description'] ?? 'Unknown location',
            'description': (l['leak_type'] ?? 'leak').toString(),
            'status': _cap(status),
            'severity': _cap(severity),
            'time': DateTime.tryParse(l['detection_date'] ?? '')
                    ?.toLocal()
                    .toString() ??
                '',
            'color': color,
          };
        }).toList();
        print('✅ Loaded ${leakAlerts.length} leak alerts (${leakAlerts.where((a) => a['status'].toString().toLowerCase() == 'active').length} active)');
        if (leakAlerts.isNotEmpty) {
          print('📋 Leak alerts details:');
          for (int i = 0; i < leakAlerts.length; i++) {
            final alert = leakAlerts[i];
            print('   ${i + 1}. ${alert['location']} - Status: ${alert['status']}, Severity: ${alert['severity']}');
          }
          // Force UI update
          setState(() {});
        } else {
          print('⚠️ No leak alerts found - checking database...');
          // Try to fetch all leaks without filter
          final allLeaks = await _supabaseService.getAllLeakDetections();
          print('📊 Total leaks in database: ${allLeaks.length}');
          if (allLeaks.isNotEmpty) {
            // Map and update if we found leaks
            String _cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
            leakAlerts = allLeaks.map((l) {
              final String severity = (l['severity'] ?? 'low').toString().toLowerCase();
              final Color color = severity == 'critical'
                  ? Colors.purple
                  : severity == 'high'
                      ? Colors.red
                      : severity == 'medium'
                          ? Colors.orange
                          : Colors.green;
              final status = (l['status'] ?? 'active').toString().toLowerCase();
              return {
                'id': l['id'],
                'location': l['location_description'] ?? 'Unknown location',
                'description': (l['leak_type'] ?? 'leak').toString(),
                'status': _cap(status),
                'severity': _cap(severity),
                'time': DateTime.tryParse(l['detection_date'] ?? '')?.toLocal().toString() ?? '',
                'color': color,
              };
            }).toList();
            setState(() {});
          }
        }
      } catch (e) {
        print('❌ Error loading leak alerts: $e');
        setState(() {
          leakAlerts = [];
        });
      }

      // Ensure there is at least one property
      final ensured = await _ensureProperty();
      if (ensured) {
        await _loadPropertyData();
      } else {
        // Even without property, load water control series for charts
        await _loadWaterControlSeries();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadPropertyData() async {
    try {
      // Try to load from database first
      if (selectedPropertyId != null) {
        try {
          // Initialize database with sample data if needed
          await _supabaseService.initializeDatabase();

          // Load data in parallel to improve performance
          final futures = await Future.wait([
            _supabaseService.getDailyConsumption(selectedPropertyId!),
            _supabaseService.getMonthlyConsumption(selectedPropertyId!),
            _supabaseService.getLeakDetections(selectedPropertyId!,
                status: 'active'),
          ]);

          // Assign results
          dailyConsumption = futures[0];
          monthlyConsumption = futures[1];
          final leaks = futures[2];

          // Only update leakAlerts if we got results, otherwise keep existing ones
          if (leaks.isNotEmpty) {
            String _cap(String v) =>
                v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
            leakAlerts = leaks.map((l) {
            final String severity =
                (l['severity'] ?? 'low').toString().toLowerCase();
            final Color color = severity == 'critical'
                ? Colors.purple
                : severity == 'high'
                    ? Colors.red
                    : severity == 'medium'
                        ? Colors.orange
                        : Colors.green;
            return {
              'id': l['id'],
              'location': l['location_description'] ?? 'Unknown location',
              'description': (l['leak_type'] ?? 'leak').toString(),
              'status': _cap((l['status'] ?? 'active').toString()),
              'severity': _cap(severity),
              'time': DateTime.tryParse(l['detection_date'] ?? '')
                      ?.toLocal()
                      .toString() ??
                  '',
              'color': color,
            };
            }).toList();
            print('📋 Updated leak alerts from property: ${leakAlerts.length}');
          } else {
            print('⚠️ No leaks found for property, keeping existing ${leakAlerts.length} alerts');
          }

          // Calculate water savings
          _calculateWaterSavings();

          // Load water_connection_control for charts (current snapshot-based)
          await _loadWaterControlSeries();

          // Water data will be loaded from database

          // Ensure we have data for charts (reload if needed)
          if (weeklyUsage.isEmpty || todayFlow.isEmpty) {
            print(
                '⚠️ No water control data available, reloading device snapshot series');
            await _loadWaterControlSeries();
          }
        } catch (e) {
          print('Error loading from database: $e');
          // Initialize empty data structures (but preserve leakAlerts if they exist)
          dailyConsumption = [];
          monthlyConsumption = [];
          // Don't clear leakAlerts here - keep the ones loaded in _loadDashboardData
          if (leakAlerts.isEmpty) {
            leakAlerts = [];
          }
          weeklyUsage = [];
          todayFlow = [];
          return;
        }
      } else {
        // No property selected - fetch all leaks for alerts
        print('⚠️ No property selected, fetching all leaks');
        try {
          final leaks = await _supabaseService.getAllLeakDetections(status: 'active');
          String _cap(String v) =>
              v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
          leakAlerts = leaks.map((l) {
            final String severity =
                (l['severity'] ?? 'low').toString().toLowerCase();
            final Color color = severity == 'critical'
                ? Colors.purple
                : severity == 'high'
                    ? Colors.red
                    : severity == 'medium'
                        ? Colors.orange
                        : Colors.green;
            return {
              'id': l['id'],
              'location': l['location_description'] ?? 'Unknown location',
              'description': (l['leak_type'] ?? 'leak').toString(),
              'status': _cap((l['status'] ?? 'active').toString()),
              'severity': _cap(severity),
              'time': DateTime.tryParse(l['detection_date'] ?? '')
                      ?.toLocal()
                      .toString() ??
                  '',
              'color': color,
            };
          }).toList();
          
          // Load water_connection_control for charts
          await _loadWaterControlSeries();
        } catch (e) {
          print('Error loading all leaks: $e');
          // Only clear if we don't have any from _loadDashboardData
          if (leakAlerts.isEmpty) {
            leakAlerts = [];
          }
        }
        dailyConsumption = [];
        monthlyConsumption = [];
        weeklyUsage = [];
        todayFlow = [];
        return;
      }

      setState(() {});
    } catch (e) {
      print('Error loading property data: $e');
      // Initialize empty data structures (but preserve leakAlerts)
      dailyConsumption = [];
      monthlyConsumption = [];
      // Don't clear leakAlerts - keep the ones loaded in _loadDashboardData
      if (leakAlerts.isEmpty) {
        leakAlerts = [];
      }
      weeklyUsage = [];
      todayFlow = [];
    }
    
    // Always update UI after loading
    setState(() {
      print('🔄 UI updated: leakAlerts count = ${leakAlerts.length}');
    });
  }

  Future<void> _loadWaterControlSeries() async {
    try {
      final now = DateTime.now();
      // Prefer history-based daily totals (from water_connection_control_history)
      final grouped = await _supabaseService.getWaterDataGroupedByDay(days: 7);
      if (grouped.isNotEmpty) {
        weeklyUsage = grouped.map((g) {
          return {
            'day': (g['dayName'] ?? '').toString(),
            'usage': (g['totalWaterUsed'] as num?)?.toDouble() ?? 0.0,
            'color': Colors.blue,
          };
        }).toList();

        final todaySamples = await _supabaseService.getTodayWaterData();
        final flow = <Map<String, dynamic>>[];
        for (final r in todaySamples) {
          final t = DateTime.tryParse((r['created_at'] ?? '').toString());
          if (t == null) continue;
          flow.add({
            't': t.toLocal(),
            'value': (r['flow_rate'] as num?)?.toDouble() ?? 0.0,
          });
        }
        flow.sort((a, b) => (a['t'] as DateTime).compareTo(b['t'] as DateTime));
        todayFlow = flow.isNotEmpty ? flow : [{'t': now, 'value': 0.0}];
      } else {
        // Fallback: snapshot-based
        final devices = await _supabaseService.getWaterConnectionDevices();
        final filtered = selectedPropertyId == null
            ? devices
            : devices
                .where((d) => d['property_id']?.toString() == selectedPropertyId)
                .toList();

        final totalUsed = filtered.fold<double>(
          0.0,
          (sum, d) => sum + ((d['total_water_used'] as num?)?.toDouble() ?? 0.0),
        );
        final totalFlow = filtered.fold<double>(
          0.0,
          (sum, d) => sum + ((d['water_flow'] as num?)?.toDouble() ?? 0.0),
        );

        final List<Map<String, dynamic>> week = [];
        for (int i = 6; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          final label =
              ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.weekday % 7];
          final value = i == 0 ? totalUsed : 0.0;
          week.add({'day': label, 'usage': value, 'color': Colors.blue});
        }
        weeklyUsage = week;
        todayFlow = [
          {'t': now, 'value': totalFlow}
        ];
      }

      // Leak indicator: use active leak detections OR suspicious current flow.
      final suspiciousNow =
          (todayFlow.isNotEmpty ? (todayFlow.last['value'] as num?)?.toDouble() ?? 0.0 : 0.0) >=
              15.0;
      final activeLeak = leakAlerts.any((a) => (a['status'] ?? '').toString().toLowerCase() == 'active');
      abnormalLeakDetected = activeLeak || suspiciousNow;

      print(
          '✅ Water usage series loaded: days=${weeklyUsage.length}, flowPoints=${todayFlow.length}');
    } catch (e) {
      print('❌ Error loading water control snapshot: $e');
      weeklyUsage = [];
      todayFlow = [];
    }
  }

  Future<bool> _ensureProperty() async {
    try {
      // Check if user is authenticated using our custom auth system
      final currentUserId = _supabaseService.currentUserId;
      if (currentUserId == null) {
        // Use demo mode when not authenticated
        return false;
      }

      // Try to check if user has any properties
      try {
        final userProperties = await _supabaseService.getProperties();
        if (userProperties.isNotEmpty) {
          selectedPropertyId = userProperties.first['id'];
          properties = userProperties;
          return true;
        }
      } catch (e) {
        print('Error loading properties: $e');
        // Use demo mode when database is not available
        return false;
      }

      // No properties found: try to create a default one
      Map<String, dynamic> created;
      try {
        created = await _supabaseService.createProperty({
          'property_name': 'My Home',
          'property_type': 'residential',
          'address': 'Unknown Address',
          'city': 'Unknown City',
          'state': 'Unknown State',
          'zip_code': '0000',
        });
        selectedPropertyId = created['id'];
        properties = [created];
      } catch (e) {
        print('Error creating property: $e');
        // Use demo mode when database is not available
        return false;
      }

      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Unable to set up a property. Please try again.')),
      );
      return false;
    }
  }


  void _calculateWaterSavings() {
    try {
      if (monthlyConsumption.isEmpty) {
        waterSavings = {
          'currentMonth': 0.0,
          'previousMonth': 0.0,
          'daily': 0.0,
          'weekly': 0.0,
          'monthly': 0.0,
          'savingsAmount': 0.0,
          'savingsPercent': 0.0,
        };
        return;
      }

      final current =
          _numOr0(monthlyConsumption.first['total_consumption_liters']);
      final previous = monthlyConsumption.length > 1
          ? _numOr0(monthlyConsumption[1]['total_consumption_liters'])
          : 0.0;

      final savings = (previous - current).clamp(0.0, double.infinity);
      final percent = previous > 0 ? _safeDiv(savings, previous) * 100.0 : 0.0;

      waterSavings = {
        'currentMonth': current,
        'previousMonth': previous,
        'daily': current > 0 ? _safeDiv(current, 30) : 0.0,
        'weekly': current > 0 ? _safeDiv(current, 4) : 0.0,
        'monthly': current,
        'savingsAmount': savings,
        'savingsPercent': percent,
      };
    } catch (e) {
      print('Error calculating water savings: $e');
      waterSavings = {
        'currentMonth': 0.0,
        'previousMonth': 0.0,
        'daily': 0.0,
        'weekly': 0.0,
        'monthly': 0.0,
        'savingsAmount': 0.0,
        'savingsPercent': 0.0,
      };
    }
  }

  void _startAnimations() async {
    _backgroundController.forward();
    await Future.delayed(Duration(milliseconds: 500));
    _contentController.forward();
    await Future.delayed(Duration(milliseconds: 200));
    _navbarController.forward();
  }

  // _openSwitch removed (unused)

  Future<void> _openHistory() async {
    if (selectedPropertyId == null) {
      final ok = await _ensureProperty();
      if (!ok) return;
    }
    try {
      var leaks = await _supabaseService.getLeakDetections(selectedPropertyId!);
      // If leaks aren't linked to a property_id (common in sample/ESP32 data),
      // fall back to global leaks so History matches the dashboard alert count.
      if (leaks.isEmpty) {
        leaks = await _supabaseService.getAllLeakDetections();
      }
      await Navigator.pushNamed(context, '/history', arguments: {
        'propertyId': selectedPropertyId,
        'leaks': leaks,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load history: ${e.toString()}')),
      );
    }
  }

  Future<void> _openContact() async {
    try {
      // Show the same contacts managed in Admin (global list)
      final contacts = await _supabaseService.getAllEmergencyContacts(limit: 10000);
      await Navigator.pushNamed(context, '/contact', arguments: {
        'contacts': contacts,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load contacts: ${e.toString()}')),
      );
    }
  }

  Future<void> _openValveControl() async {
    try {
      await Navigator.pushNamed(context, '/switch');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Unable to open valve control: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _contentController.dispose();
    _navbarController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Dashboard - already here
        break;
      case 1:
        Navigator.pushNamed(context, '/user');
        break;
      case 2:
        Navigator.pushNamed(context, '/about');
        break;
      case 3:
        _showLogoutDialog();
        break;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Logout',
            style: TextStyle(
              color: Color(0xFF1e3c72),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
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
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1e3c72),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLeakAlerts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final r = Responsive(context);
        return Container(
          height: r.h * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(r.cardRadius),
              topRight: Radius.circular(r.cardRadius),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: r.smallSpacing),
                width: r.isSmallPhone ? 30 : 40,
                height: r.isSmallPhone ? 3 : 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: r.mediumSpacing),

              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.mediumSpacing),
                child: Row(
                  children: [
                    Icon(Icons.notifications,
                        color: Color(0xFF1e3c72), size: r.iconSize),
                    SizedBox(width: r.smallSpacing),
                    Expanded(
                      child: Text(
                        'Leak Detection Alerts',
                        style: TextStyle(
                          fontSize: r.titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3c72),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.mediumSpacing,
                          vertical: r.smallSpacing),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(r.cardRadius),
                      ),
                      child: Text(
                        '${leakAlerts.where((alert) => (alert['status']?.toString().toLowerCase() ?? '') == 'active').length} Active',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: r.smallFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.mediumSpacing),

              // Alerts list
              Expanded(
                child: leakAlerts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(r.mediumSpacing),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: r.smallSpacing),
                              Text(
                                'No leak alerts',
                                style: TextStyle(
                                  fontSize: r.bodyFontSize,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: r.smallSpacing),
                              Text(
                                'All systems operating normally',
                                style: TextStyle(
                                  fontSize: r.smallFontSize,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          print('🔔 Building ListView with ${leakAlerts.length} alerts');
                          if (leakAlerts.isEmpty) {
                            print('⚠️ WARNING: leakAlerts is empty in Builder!');
                          }
                          return ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: r.mediumSpacing),
                            itemCount: leakAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = leakAlerts[index];
                              print('🔔 Rendering leak alert ${index + 1}/${leakAlerts.length}: ${alert['location']} (status: ${alert['status']})');
                              return _buildLeakAlertItem(alert, r);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAnnouncements() {
    Future<List<Map<String, dynamic>>> future =
        _supabaseService.getAnnouncements();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final r = Responsive(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: r.h * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(r.cardRadius),
                  topRight: Radius.circular(r.cardRadius),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: r.smallSpacing),
                    width: r.isSmallPhone ? 30 : 40,
                    height: r.isSmallPhone ? 3 : 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: r.mediumSpacing),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.mediumSpacing),
                    child: Row(
                      children: [
                        Icon(Icons.campaign,
                            color: Color(0xFF1e3c72), size: r.iconSize),
                        SizedBox(width: r.smallSpacing),
                        Expanded(
                          child: Text(
                            'Announcements',
                            style: TextStyle(
                              fontSize: r.titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e3c72),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setModalState(() {
                            future = _supabaseService.getAnnouncements();
                          }),
                          icon: Icon(Icons.refresh,
                              color: Color(0xFF1e3c72), size: r.iconSize),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.mediumSpacing),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1e3c72)),
                            ),
                          );
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return Center(
                            child: Text(
                              'No announcements right now.',
                              style: TextStyle(
                                color: Color(0xFF1e3c72)
                                    .withValues(alpha: 0.7),
                                fontSize: r.bodyFontSize,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.mediumSpacing),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: r.smallSpacing),
                          itemBuilder: (context, index) =>
                              _buildAnnouncementItem(items[index], r),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncementItem(Map<String, dynamic> a, Responsive r) {
    final title = (a['title'] ?? 'Announcement').toString();
    final message = (a['message'] ?? a['body'] ?? '').toString();
    final createdAt = a['created_at'];
    final dateText = _formatAnnouncementDate(createdAt);

    return Container(
      padding: EdgeInsets.all(r.mediumSpacing),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(
          color: Color(0xFF1e3c72).withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(r.smallSpacing),
            decoration: BoxDecoration(
              color: Color(0xFF1e3c72).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(r.cardRadius),
            ),
            child: Icon(
              Icons.campaign,
              color: Color(0xFF1e3c72),
              size: r.smallIconSize,
            ),
          ),
          SizedBox(width: r.mediumSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: r.subtitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1e3c72),
                  ),
                ),
                if (message.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: r.bodyFontSize,
                      color: Color(0xFF1e3c72).withValues(alpha: 0.75),
                    ),
                  ),
                ],
                if (dateText.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Text(
                    dateText,
                    style: TextStyle(
                      fontSize: r.smallFontSize,
                      color: Color(0xFF1e3c72).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAnnouncementDate(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _buildLeakAlertItem(Map<String, dynamic> alert, Responsive r) {
    return InkWell(
      onTap: () => _showLeakDetails(alert['id']),
      borderRadius: BorderRadius.circular(r.cardRadius),
      child: Container(
        margin: EdgeInsets.only(bottom: r.mediumSpacing),
        padding: EdgeInsets.all(r.mediumSpacing),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(
            color: alert['color'].withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(r.smallSpacing),
                decoration: BoxDecoration(
                  color: alert['color'].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(r.cardRadius),
                ),
                child: Icon(
                  Icons.warning,
                  color: alert['color'],
                  size: r.smallIconSize,
                ),
              ),
              SizedBox(width: r.mediumSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert['location'],
                      style: TextStyle(
                        fontSize: r.subtitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1e3c72),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      alert['description'],
                      style: TextStyle(
                        fontSize: r.bodyFontSize,
                        color: Color(0xFF1e3c72).withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.mediumSpacing, vertical: r.smallSpacing),
                decoration: BoxDecoration(
                  color: alert['status'] == 'Active'
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(r.cardRadius),
                ),
                child: Text(
                  alert['status'],
                  style: TextStyle(
                    color:
                        alert['status'] == 'Active' ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: r.smallFontSize,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.mediumSpacing),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.smallSpacing, vertical: r.smallSpacing),
                decoration: BoxDecoration(
                  color: alert['color'].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(r.cardRadius),
                ),
                child: Text(
                  alert['severity'],
                  style: TextStyle(
                    color: alert['color'],
                    fontWeight: FontWeight.bold,
                    fontSize: r.smallFontSize,
                  ),
                ),
              ),
              Spacer(),
              Text(
                alert['time'],
                style: TextStyle(
                  color: Color(0xFF1e3c72).withValues(alpha: 0.6),
                  fontSize: r.smallFontSize,
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _showLeakDetails(String? leakId) async {
    if (leakId == null || leakId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leak ID not available')),
      );
      return;
    }

    try {
      final leak = await _supabaseService.getLeakDetectionById(leakId);
      if (leak == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leak details not found')),
        );
        return;
      }

      final r = Responsive(context);
      final statusLower = (leak['status'] ?? '').toString().toLowerCase();
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.cardRadius),
            ),
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: r.iconSize),
                SizedBox(width: r.smallSpacing),
                Expanded(
                  child: Text(
                    'Leak Detection Details',
                    style: TextStyle(
                      fontSize: r.titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3c72),
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Location', leak['location_description'] ?? 'Not specified', r),
                  _buildDetailRow('Leak Type', leak['leak_type'] ?? 'Unknown', r),
                  _buildDetailRow('Severity', leak['severity'] ?? 'Unknown', r),
                  _buildDetailRow('Status', leak['status'] ?? 'Unknown', r),
                  _buildDetailRow('Detection Date', _formatDate(leak['detection_date']), r),
                  if (leak['estimated_water_loss_liters'] != null)
                    _buildDetailRow('Water Loss', '${(leak['estimated_water_loss_liters'] as num).toStringAsFixed(2)} L', r),
                  if (leak['estimated_water_loss_rate'] != null)
                    _buildDetailRow('Loss Rate', '${(leak['estimated_water_loss_rate'] as num).toStringAsFixed(2)} L/min', r),
                  if (leak['pressure_drop'] != null)
                    _buildDetailRow('Pressure Drop', '${(leak['pressure_drop'] as num).toStringAsFixed(2)} PSI', r),
                  if (leak['flow_rate_anomaly'] != null)
                    _buildDetailRow('Flow Anomaly', '${(leak['flow_rate_anomaly'] as num).toStringAsFixed(2)} L/min', r),
                  if (leak['confidence_score'] != null)
                    _buildDetailRow('Confidence', '${((leak['confidence_score'] as num) * 100).toStringAsFixed(1)}%', r),
                  if (leak['resolved_date'] != null)
                    _buildDetailRow('Resolved Date', _formatDate(leak['resolved_date']), r),
                  if (leak['resolution_notes'] != null && leak['resolution_notes'].toString().isNotEmpty)
                    _buildDetailRow('Resolution Notes', leak['resolution_notes'], r),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: TextStyle(color: Color(0xFF1e3c72))),
              ),
              if (statusLower == 'active')
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _promptResolveLeak(leakId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: Text('Fix Leak', style: TextStyle(color: Colors.white)),
                ),
              if (statusLower == 'active')
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openHistory();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1e3c72),
                  ),
                  child: Text('View History', style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading leak details: $e')),
      );
    }
  }

  Future<void> _promptResolveLeak(String leakId) async {
    final r = Responsive(context);
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.cardRadius),
          ),
          title: Text(
            'Fix Leak',
            style: TextStyle(
              fontSize: r.titleFontSize,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e3c72),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add resolution notes (optional):',
                style: TextStyle(
                  fontSize: r.bodyFontSize,
                  color: Color(0xFF1e3c72).withValues(alpha: 0.75),
                ),
              ),
              SizedBox(height: r.smallSpacing),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., Tightened pipe fitting, replaced valve, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.cardRadius),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  Text('Cancel', style: TextStyle(color: Color(0xFF1e3c72))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Mark Resolved',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabaseService.resolveLeakDetection(
        leakId,
        resolutionNotes: controller.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Leak marked as resolved')),
      );
      // Refresh leaks + UI
      await _loadDashboardData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to resolve leak: $e')),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, Responsive r) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.smallSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: r.bodyFontSize,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3c72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: r.bodyFontSize,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not specified';
    final dt = DateTime.tryParse(date.toString());
    if (dt == null) return date.toString();
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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
                      Color(0xFF1e3c72),
                      Color(0xFF2193b0),
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating particles
          ...List.generate(20, (index) => _buildFloatingParticle(index)),

          // Modern AppBar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _contentAnimation,
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8, bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Waterleak Dashboard',
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
                              'Welcome back!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications,
                                color: Colors.white, size: 20),
                            onPressed: _showLeakAlerts,
                            padding: EdgeInsets.all(8),
                          ),
                          if (leakAlerts
                              .where((alert) => alert['status'] == 'Active')
                              .isNotEmpty)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            bottom: 90, // Space for navbar
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _contentAnimation,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final r = Responsive(context);
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.horizontalPadding(
                            phone: 12, narrow: 10, veryNarrow: 8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Welcome card
                          _buildWelcomeCard(),
                          SizedBox(height: r.smallSpacing),

                          // Smart Detection Features (after welcome)
                          _buildQuickActions(),
                          SizedBox(height: r.smallSpacing),

                          // Water Consumption Charts
                          _buildWaterConsumptionCharts(),
                          SizedBox(height: r.smallSpacing),

                          // High Total Used Water Section
                          _buildHighTotalUsedSection(r),
                          SizedBox(height: r.mediumSpacing),

                          // Water Savings Section
                          _buildWaterSavingsSection(),
                          SizedBox(height: r.mediumSpacing),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Animated Bottom Navigation Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _navbarAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, 1.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _navbarController,
                  curve: Curves.easeOutCubic,
                )),
                child: Container(
                  height: 65,
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                      _buildNavItem(Icons.person, 'Profile', 1),
                      _buildNavItem(Icons.info, 'About', 2),
                      _buildNavItem(Icons.logout, 'Logout', 3),
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

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return GestureDetector(
          onTap: () => _onNavItemTapped(index),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
                horizontal: r.isSmallPhone ? 8 : 12,
                vertical: r.isSmallPhone ? 4 : 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(r.cardRadius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                  size: r.isSmallPhone ? 18 : 20,
                ),
                SizedBox(height: r.isSmallPhone ? 2 : 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: r.isSmallPhone ? 8 : 9,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
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

  Widget _buildWelcomeCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.smallSpacing),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: Color(0xFF1e3c72).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(r.smallSpacing),
                decoration: BoxDecoration(
                  color: Color(0xFF1e3c72).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: r.isSmallPhone ? 32 : 40,
                  color: Color(0xFF1e3c72),
                ),
              ),
              SizedBox(height: r.smallSpacing),
              Text(
                'Welcome to Waterleak!',
                style: TextStyle(
                  fontSize: r.titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3c72),
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: r.smallSpacing),
              Text(
                'Your smart water management system is ready.',
                style: TextStyle(
                  fontSize: r.bodyFontSize,
                  color: Color(0xFF1e3c72).withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: r.mediumSpacing),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.mediumSpacing, vertical: r.smallSpacing),
                decoration: BoxDecoration(
                  color: abnormalLeakDetected
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: abnormalLeakDetected
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      abnormalLeakDetected ? Icons.warning : Icons.security,
                      color: abnormalLeakDetected ? Colors.red : Colors.green,
                      size: r.smallIconSize,
                    ),
                    SizedBox(width: r.smallSpacing),
                    Flexible(
                      child: Text(
                        abnormalLeakDetected
                            ? 'Leak Detected'
                            : 'Smart Detection Active',
                        style: TextStyle(
                          color:
                              abnormalLeakDetected ? Colors.red : Colors.green,
                          fontSize: r.smallFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // _buildStatCard removed (unused)

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.smallSpacing),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: Color(0xFF1e3c72).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Detection Features',
                style: TextStyle(
                  fontSize: r.titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3c72),
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: r.mediumSpacing),
              if (!_actionsEnabled) ...[
                Row(
                  children: [
                    SizedBox(
                      width: r.smallIconSize,
                      height: r.smallIconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF1e3c72)),
                      ),
                    ),
                    SizedBox(width: r.smallSpacing),
                    Flexible(
                      child: Text(
                        isLoading
                            ? 'Loading your properties...'
                            : 'Setting up smart detection...',
                        style: TextStyle(
                          fontSize: r.bodyFontSize,
                          color: Color(0xFF1e3c72).withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.mediumSpacing),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool narrow = constraints.maxWidth < 600;
                  final spacing = r.isSmallPhone ? 4.0 : 6.0;
                  final buttons = <Widget>[
                    _buildActionButton('Announcements', Icons.campaign,
                        () => _showAnnouncements()),
                    _buildActionButton('Valve Control', Icons.settings,
                        _actionsEnabled ? () => _openValveControl() : null),
                    _buildActionButton('History', Icons.history,
                        _actionsEnabled ? () => _openHistory() : null),
                    _buildActionButton('Contact', Icons.contact_support,
                        _actionsEnabled ? () => _openContact() : null),
                  ];
                  if (narrow) {
                    // Calculate button width accounting for spacing between items
                    final buttonWidth = (constraints.maxWidth - spacing) / 2;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: buttons
                          .map((b) => SizedBox(
                                width: buttonWidth,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: buttonWidth,
                                    minWidth: 0,
                                  ),
                                  child: b,
                                ),
                              ))
                          .toList(),
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buttons[0]),
                          SizedBox(width: r.smallSpacing),
                          Expanded(child: buttons[1]),
                        ],
                      ),
                      SizedBox(height: r.smallSpacing),
                      Row(
                        children: [
                          Expanded(child: buttons[2]),
                          SizedBox(width: r.smallSpacing),
                          Expanded(child: buttons[3]),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // _buildPercentageCard removed (unused)
  Widget _buildActionButton(String title, IconData icon,
      [VoidCallback? onTap]) {
    final bool disabled = onTap == null;
    return Builder(
      builder: (context) {
        final r = Responsive(context);
        Widget buttonContent = Container(
          constraints: BoxConstraints(
            minWidth: 0,
            minHeight: r.isSmallPhone ? 60 : 70,
          ),
          height: r.isSmallPhone ? 60 : 70,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: Color(0xFF1e3c72).withValues(alpha: disabled ? 0.2 : 0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.isSmallPhone ? 8 : 12,
              vertical: r.isSmallPhone ? 6 : 8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Color(0xFF1e3c72),
                  size: r.isSmallPhone ? 20 : 24,
                ),
                SizedBox(height: r.isSmallPhone ? 2 : 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Color(0xFF1e3c72),
                    fontSize: r.isSmallPhone ? 10 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );

        if (disabled) {
          return Opacity(
            opacity: 0.5,
            child: buttonContent,
          );
        }

        return GestureDetector(
          onTap: onTap,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(r.cardRadius),
              splashColor: Color(0xFF1e3c72).withValues(alpha: 0.1),
              highlightColor: Color(0xFF1e3c72).withValues(alpha: 0.05),
              child: buttonContent,
            ),
          ),
        );
      },
    );
  }

  // _buildQuickStatsCards removed (unused)

  Widget _buildWaterConsumptionCharts() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.smallSpacing),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: Color(0xFF1e3c72).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Water Consumption Charts',
                style: TextStyle(
                  fontSize: r.titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3c72),
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: r.mediumSpacing),

              

              // Today's flow (line chart)
              Text(
                "Today's Flow (L/min)",
                style: TextStyle(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1e3c72),
                ),
              ),
              SizedBox(height: r.mediumSpacing),
              Container(
                height: r.chartHeight(phoneFactor: 0.18, wideFactor: 0.22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(r.cardRadius),
                ),
                child: CustomPaint(
                  painter: _FlowLineChartPainter(todayFlow),
                  child: Container(),
                ),
              ),
              SizedBox(height: r.mediumSpacing),
              // Current Total Use Display
              Container(
                padding: EdgeInsets.all(r.mediumSpacing),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1e3c72).withValues(alpha: 0.1),
                      Color(0xFF2193b0).withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(r.cardRadius),
                  border: Border.all(
                    color: Color(0xFF1e3c72).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Water Used',
                          style: TextStyle(
                            fontSize: r.bodyFontSize,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1e3c72),
                          ),
                        ),
                        SizedBox(height: r.smallSpacing),
                        Text(
                          '${_calculateTotalUsed().toStringAsFixed(2)} L',
                          style: TextStyle(
                            fontSize: r.titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1e3c72),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.water_drop,
                      size: r.largeIconSize,
                      color: Color(0xFF1e3c72),
                    ),
                  ],
                ),
              ),
              if (abnormalLeakDetected) ...[
                SizedBox(height: r.mediumSpacing),
                Container(
                  padding: EdgeInsets.all(r.mediumSpacing),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.cardRadius),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: r.iconSize),
                      SizedBox(width: r.smallSpacing),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🚨 Smart Leak Detection Alert',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: r.bodyFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: r.smallSpacing),
                            Text(
                              'Abnormal water flow pattern detected. Possible leak in progress.',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: r.smallFontSize,
                              ),
                            ),
                            SizedBox(height: r.smallSpacing),
                            Text(
                              'Recommendation: Check all water fixtures and pipes immediately.',
                              style: TextStyle(
                                color: Colors.red.shade600,
                                fontSize: r.isVerySmallPhone ? 10 : 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighTotalUsedSection(Responsive r) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.smallSpacing),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(
          color: Color(0xFF1e3c72).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'High Water Usage Analysis',
            style: TextStyle(
              fontSize: r.titleFontSize,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e3c72),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: r.mediumSpacing),

          // High usage bar chart
          Container(
            height: r.isVeryShortScreen ? 200 : r.isShortScreen ? 220 : 240,
            child: _buildHighUsageBarChart(r),
          ),
          SizedBox(height: r.mediumSpacing),

          // High usage statistics
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                flex: 1,
                child: _buildHighUsageStat(
                  'Peak Usage',
                  '${_getPeakUsage().toStringAsFixed(6)} L',
                  Colors.red,
                  r,
                ),
              ),
              SizedBox(width: r.smallSpacing),
              Expanded(
                flex: 1,
                child: _buildHighUsageStat(
                  'Average Usage',
                  '${_getAverageUsage().toStringAsFixed(6)} L',
                  Colors.orange,
                  r,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighUsageBarChart(Responsive r) {
    // Get the last 7 days of data for the bar chart
    final chartData = weeklyUsage.take(7).toList();

    if (chartData.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: r.bodyFontSize,
          ),
        ),
      );
    }

    final maxUsage = chartData
        .map((d) => (d['usage'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    // Responsive sizing
    final chartPadding = r.isVerySmallPhone 
        ? r.smallSpacing * 0.5 
        : r.isNarrow 
            ? r.smallSpacing 
            : r.mediumSpacing;
    final barWidth = r.isVerySmallPhone 
        ? 20.0 
        : r.isNarrow 
            ? 22.0 
            : r.isPhone 
                ? 25.0 
                : 30.0;
    final dayFontSize = r.isVerySmallPhone ? 8.0 : r.isNarrow ? 9.0 : 10.0;
    final valueFontSize = r.isVerySmallPhone ? 7.0 : r.isNarrow ? 7.5 : 8.0;
    // Reserve space for labels: day label (10px) + spacing (6px) + value label (8px) + spacing (2px) = ~26px
    final labelSpace = 26.0;
    final chartHeight = (r.isVeryShortScreen ? 140.0 : 160.0) - labelSpace;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: chartPadding,
        vertical: chartPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - (chartPadding * 2);
          final minBarWidth = barWidth;
          final totalBarsWidth = chartData.length * minBarWidth;
          final spacing = chartData.length > 1 
              ? (availableWidth - totalBarsWidth) / (chartData.length - 1)
              : 0.0;
          
          // If bars don't fit, make it scrollable
          final needsScroll = spacing < 4 || r.isVerySmallPhone;
          
          if (needsScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: chartData.map((data) {
                  final usage = (data['usage'] as num).toDouble();
                  // Clamp height to ensure it fits within available space
                  final calculatedHeight = maxUsage > 0 ? (usage / maxUsage) * chartHeight : 0.0;
                  final height = calculatedHeight.clamp(0.0, chartHeight);

                  // Color based on usage level
                  Color barColor;
                  if (usage > maxUsage * 0.8) {
                    barColor = Colors.red;
                  } else if (usage > maxUsage * 0.6) {
                    barColor = Colors.orange;
                  } else if (usage > maxUsage * 0.4) {
                    barColor = Colors.yellow;
                  } else {
                    barColor = Colors.green;
                  }

                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Bar container with constrained height
                          Flexible(
                            flex: 1,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: chartHeight,
                                minHeight: 0,
                              ),
                              child: Container(
                                width: minBarWidth,
                                height: height,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      barColor,
                                      barColor.withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 4),
                          // Labels with fixed height to prevent overflow
                          SizedBox(
                            height: dayFontSize + 2,
                            child: Text(
                              data['day'],
                              style: TextStyle(
                                fontSize: dayFontSize,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1e3c72),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 2),
                          SizedBox(
                            height: valueFontSize + 2,
                            child: Text(
                              "${usage.toStringAsFixed(2)}L",
                              style: TextStyle(
                                fontSize: valueFontSize,
                                color: Color(0xFF1e3c72).withValues(alpha: 0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }

          // If bars fit, use flexible layout
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: chartData.map((data) {
              final usage = (data['usage'] as num).toDouble();
              // Clamp height to ensure it fits within available space
              final calculatedHeight = maxUsage > 0 ? (usage / maxUsage) * chartHeight : 0.0;
              final height = calculatedHeight.clamp(0.0, chartHeight);

              // Color based on usage level
              Color barColor;
              if (usage > maxUsage * 0.8) {
                barColor = Colors.red;
              } else if (usage > maxUsage * 0.6) {
                barColor = Colors.orange;
              } else if (usage > maxUsage * 0.4) {
                barColor = Colors.yellow;
              } else {
                barColor = Colors.green;
              }

              return Flexible(
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Bar container with constrained height
                      Flexible(
                        flex: 1,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: chartHeight,
                            minHeight: 0,
                          ),
                          child: Container(
                            width: minBarWidth,
                            height: height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  barColor,
                                  barColor.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      // Labels with fixed height to prevent overflow
                      SizedBox(
                        height: dayFontSize + 2,
                        child: Text(
                          data['day'],
                          style: TextStyle(
                            fontSize: dayFontSize,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1e3c72),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 2),
                      SizedBox(
                        height: valueFontSize + 2,
                        child: Text(
                          "${usage.toStringAsFixed(2)}L",
                          style: TextStyle(
                            fontSize: valueFontSize,
                            color: Color(0xFF1e3c72).withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildHighUsageStat(
      String title, String value, Color color, Responsive r) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.smallSpacing,
        vertical: r.smallSpacing,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            color == Colors.red ? Icons.trending_up : Icons.analytics,
            color: color,
            size: r.iconSize * 0.9,
          ),
          SizedBox(height: r.smallSpacing * 0.5),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: r.subtitleFontSize * 0.9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: r.smallFontSize * 0.9,
                color: Color(0xFF1e3c72).withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  double _getPeakUsage() {
    if (weeklyUsage.isEmpty) return 0.0;
    return weeklyUsage
        .map((d) => (d['usage'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
  }

  double _getAverageUsage() {
    if (weeklyUsage.isEmpty) return 0.0;
    final total = weeklyUsage
        .map((d) => (d['usage'] as num).toDouble())
        .reduce((a, b) => a + b);
    return total / weeklyUsage.length;
  }

  Widget _buildWaterSavingsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.mediumSpacing),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: Color(0xFF1e3c72).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _supabaseService.getCurrentUserWaterSavingsComparison(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              final loading = snapshot.connectionState == ConnectionState.waiting;
              final error = snapshot.error;

              if (error != null) {
                print('❌ Water savings error: $error');
              }

              if (loading) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(r.smallSpacing),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1e3c72)),
                    ),
                  ),
                );
              }

              final lastMonth =
                  (data['lastMonthLiters'] as num?)?.toDouble() ?? 0.0;
              final thisMonth =
                  (data['thisMonthLiters'] as num?)?.toDouble() ?? 0.0;
              final savedLiters = (data['savedLiters'] as num?)?.toDouble() ?? 0.0;
              final savedPercent =
                  (data['savedPercent'] as num?)?.toDouble() ?? 0.0;
              final success = data['success'] == true;

              print('💧 Water Savings Data: success=$success, lastMonth=$lastMonth, thisMonth=$thisMonth, saved=$savedLiters, error=${data['error']}');
              
              if (!success && data['error'] != null) {
                print('⚠️ Water savings failed: ${data['error']}');
              }

              print('💧 Water Savings Data: lastMonth=$lastMonth, thisMonth=$thisMonth, saved=$savedLiters');

              final isSaving = savedLiters > 0.0;
              final deltaAbs = savedLiters.abs();
              final deltaPctAbs = savedPercent.abs();

              final statusColor = isSaving ? Colors.green : Colors.orange;
              final statusLabel = isSaving ? 'Saving' : 'Increased';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Water Savings',
                        style: TextStyle(
                          fontSize: r.titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3c72),
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.smallSpacing,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: r.isSmallPhone ? 12 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.smallSpacing),
                  Text(
                    isSaving
                        ? 'You saved ${deltaAbs.toStringAsFixed(2)} L (${deltaPctAbs.toStringAsFixed(1)}%) compared to last month.'
                        : 'You used ${deltaAbs.toStringAsFixed(2)} L (${deltaPctAbs.toStringAsFixed(1)}%) more than last month.',
                    style: TextStyle(
                      color: Color(0xFF1e3c72).withValues(alpha: 0.85),
                      fontSize: r.isSmallPhone ? 12 : 14,
                    ),
                  ),
                  SizedBox(height: r.mediumSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSavingsMetric(
                          r: r,
                          label: 'Last Month',
                          value: '${lastMonth.toStringAsFixed(2)} L',
                          icon: Icons.calendar_month,
                        ),
                      ),
                      SizedBox(width: r.smallSpacing),
                      Expanded(
                        child: _buildSavingsMetric(
                          r: r,
                          label: 'This Month',
                          value: '${thisMonth.toStringAsFixed(2)} L',
                          icon: Icons.today,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSavingsMetric({
    required Responsive r,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(r.smallSpacing),
      decoration: BoxDecoration(
        color: Color(0xFF1e3c72).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(
          color: Color(0xFF1e3c72).withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(r.smallSpacing),
            decoration: BoxDecoration(
              color: Color(0xFF1e3c72).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.cardRadius),
            ),
            child: Icon(
              icon,
              color: Color(0xFF1e3c72),
              size: r.isSmallPhone ? 18 : 20,
            ),
          ),
          SizedBox(width: r.smallSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: r.isSmallPhone ? 11 : 12,
                    color: Color(0xFF1e3c72).withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: r.isSmallPhone ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1e3c72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> series; // [{t: DateTime, value: double}]

  _FlowLineChartPainter(this.series);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Axes padding
    const double leftPad = 30;
    const double bottomPad = 20;
    final chartWidth = size.width - leftPad - 10;
    final chartHeight = size.height - bottomPad - 10;

    // Border
    final border = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
        Rect.fromLTWH(leftPad, 10, chartWidth, chartHeight), border);

    if (series.isEmpty) return;

    final times = series.map((p) => p['t'] as DateTime).toList();
    final values = series.map((p) => (p['value'] as num).toDouble()).toList();
    final minT = times.first.millisecondsSinceEpoch;
    final maxT = times.last.millisecondsSinceEpoch;
    // minV not used; base line at zero implicitly
    final maxV = values.fold<double>(0.0, (m, v) => v > m ? v : m);
    final denomT = (maxT - minT) == 0 ? 1 : (maxT - minT).toDouble();
    final denomV = maxV <= 0 ? 1.0 : maxV;

    // Grid
    final grid = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke;
    for (int i = 0; i <= 4; i++) {
      final y = 10 + chartHeight * (i / 4);
      canvas.drawLine(
          Offset(leftPad, y), Offset(leftPad + chartWidth, y), grid);
    }

    // Line
    final path = Path();
    for (int i = 0; i < series.length; i++) {
      final t = (times[i].millisecondsSinceEpoch - minT) / denomT;
      final v = values[i] / denomV;
      final x = leftPad + chartWidth * t;
      final y = 10 + chartHeight * (1 - v);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final line = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, line);

    // Threshold line for abnormal detection - removed
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
