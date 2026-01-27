import 'package:flutter/material.dart';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class SwitchView extends StatefulWidget {
  @override
  _SwitchViewState createState() => _SwitchViewState();
}

class _SwitchViewState extends State<SwitchView> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _kitchenSwitch = false;
  bool _bathroomSwitch = false;
  bool _gardenSwitch = false;

  // Database data
  Map<String, dynamic> waterFlowData = {};
  final SupabaseService _supabaseService = SupabaseService();
  String? selectedPropertyId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    _loadSwitchData();
    
    // Refresh kitchen status periodically to sync with ESP32
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    // Refresh every 5 seconds to get latest status from ESP32
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        _refreshKitchenStatus();
        _startPeriodicRefresh(); // Schedule next refresh
      }
    });
  }

  Future<void> _refreshKitchenStatus() async {
    try {
      final kitchenDevice = await _supabaseService.getKitchenDeviceStatus();
      if (kitchenDevice != null) {
        final isOpen = (kitchenDevice['valve_status']?.toString().toLowerCase() == 'open');
        final flow = (kitchenDevice['water_flow'] as num?)?.toDouble() ?? 0.0;
        
        if (_kitchenSwitch != isOpen || waterFlowData['kitchenFlow'] != flow) {
          setState(() {
            _kitchenSwitch = isOpen;
            waterFlowData['kitchenFlow'] = flow;
            waterFlowData['totalFlow'] = flow + 
                                         (waterFlowData['bathroomFlow'] ?? 0.0) + 
                                         (waterFlowData['gardenFlow'] ?? 0.0);
          });
        }
      }
    } catch (e) {
      print('Error refreshing kitchen status: $e');
    }
  }

  Future<void> _loadSwitchData() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      // Load devices from water_connection_control (current-state table)
      final devices = await _supabaseService.getWaterConnectionDevices();

      Map<String, dynamic> findByLocation(String loc) {
        return devices.firstWhere(
          (d) =>
              (d['location']?.toString() ?? '').toLowerCase() ==
              loc.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
      }

      final kitchenDevice = devices.firstWhere(
        (d) => (d['device_id']?.toString() ?? '') == 'ESP_KITCHEN_001',
        orElse: () => findByLocation('Kitchen'),
      );
      final bathroomDevice = findByLocation('Bathroom');
      final gardenDevice = findByLocation('Garden');
      
      _kitchenSwitch =
          (kitchenDevice['valve_status']?.toString().toLowerCase() == 'open');
      final kFlow = (kitchenDevice['water_flow'] as num?)?.toDouble() ?? 0.0;
      waterFlowData['kitchenFlow'] = kFlow;
      
      _bathroomSwitch =
          (bathroomDevice['valve_status']?.toString().toLowerCase() == 'open');
      _gardenSwitch =
          (gardenDevice['valve_status']?.toString().toLowerCase() == 'open');

      final bFlow = (bathroomDevice['water_flow'] as num?)?.toDouble() ?? 0.0;
      final gFlow = (gardenDevice['water_flow'] as num?)?.toDouble() ?? 0.0;
      
      waterFlowData['bathroomFlow'] = bFlow;
      waterFlowData['gardenFlow'] = gFlow;
      waterFlowData['totalFlow'] = (waterFlowData['kitchenFlow'] ?? 0.0) + bFlow + gFlow;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading switch data: $e');
      waterFlowData = {};
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Scaffold(
          backgroundColor: Color(0xFF1e3c72),
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Main Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        margin: EdgeInsets.all(r.mediumSpacing),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(r.cardRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Title
                            Container(
                              padding: EdgeInsets.all(r.mediumSpacing),
                              decoration: BoxDecoration(
                                color: Color(0xFF1e3c72),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(r.cardRadius),
                                  topRight: Radius.circular(r.cardRadius),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.power_settings_new,
                                    color: Colors.white,
                                    size: r.iconSize,
                                  ),
                                  SizedBox(width: r.mediumSpacing),
                                  Expanded(
                                    child: Text(
                                      'Water Connection Control',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: r.titleFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Flow Summary
                            _buildFlowSummary(),

                            // Switch Controls
                            Expanded(child: _buildSwitchControls()),
                          ],
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
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          padding: EdgeInsets.all(r.mediumSpacing),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back,
                    color: Colors.white, size: r.iconSize),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Smart Water Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.mediumSpacing, vertical: r.smallSpacing),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(r.cardRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.white, size: r.smallIconSize),
                    SizedBox(width: r.smallSpacing),
                    Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.smallFontSize,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFlowSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          margin: EdgeInsets.all(r.mediumSpacing),
          padding: EdgeInsets.all(r.mediumSpacing),
          constraints: BoxConstraints(
            maxWidth: r.isDesktop ? 900 : 700,
          ),
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
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Water Flow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.bodyFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(waterFlowData['totalFlow'] as num?)?.toDouble() ?? 0.0} L/min',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.subtitleFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.mediumSpacing),
              Row(
                children: [
                  Expanded(
                    child: _buildFlowIndicator(
                        'Kitchen', (waterFlowData['kitchenFlow'] as num?)?.toDouble() ?? 0.0, Colors.green),
                  ),
                  SizedBox(width: r.smallSpacing),
                  Expanded(
                    child: _buildFlowIndicator('Bathroom',
                        (waterFlowData['bathroomFlow'] as num?)?.toDouble() ?? 0.0, Colors.orange),
                  ),
                  SizedBox(width: r.smallSpacing),
                  Expanded(
                    child: _buildFlowIndicator('Garden',
                        (waterFlowData['gardenFlow'] as num?)?.toDouble() ?? 0.0, Colors.purple),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlowIndicator(String label, double flow, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          padding: EdgeInsets.all(r.smallSpacing),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(r.cardRadius),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.smallFontSize,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: r.smallSpacing),
              Text(
                '${flow.toStringAsFixed(1)}',
                style: TextStyle(
                  color: color,
                  fontSize: r.bodyFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwitchControls() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          padding: EdgeInsets.all(r.mediumSpacing),
          constraints: BoxConstraints(
            maxWidth: r.isDesktop ? 900 : 700,
          ),
          child: ListView(
            children: [
              _buildSwitchCard(
                'Kitchen',
                'Kitchen sink and dishwasher water supply',
                _kitchenSwitch,
                Icons.kitchen,
                Colors.green,
                (value) {
                  setState(() {
                    _kitchenSwitch = value;
                  });
                  _updateDeviceStatusForLocation('Kitchen', value);
                  _showSwitchDialog('Kitchen', value);
                },
              ),
              SizedBox(height: r.mediumSpacing),
              _buildSwitchCard(
                'Bathroom',
                'Bathroom sink, shower, and toilet water supply',
                _bathroomSwitch,
                Icons.bathroom,
                Colors.orange,
                (value) {
                  setState(() {
                    _bathroomSwitch = value;
                  });
                  _updateDeviceStatusForLocation('Bathroom', value);
                  _showSwitchDialog('Bathroom', value);
                },
              ),
              SizedBox(height: r.mediumSpacing),
              _buildSwitchCard(
                'Garden',
                'Garden hose and sprinkler system',
                _gardenSwitch,
                Icons.local_florist,
                Colors.purple,
                (value) {
                  setState(() {
                    _gardenSwitch = value;
                  });
                  _updateDeviceStatusForLocation('Garden', value);
                  _showSwitchDialog('Garden', value);
                },
              ),
              SizedBox(height: r.mediumSpacing),

              // Emergency Shutoff
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.mediumSpacing),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red[400]!,
                      Colors.red[600]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(r.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.emergency,
                      color: Colors.white,
                      size: r.largeIconSize,
                    ),
                    SizedBox(height: r.smallSpacing),
                    Text(
                      'Emergency Shutoff',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.subtitleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: r.smallSpacing),
                    Text(
                      'Instantly turn off all water supply',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: r.smallFontSize,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: r.mediumSpacing),
                    ElevatedButton(
                      onPressed: () => _emergencyShutoff(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.cardRadius),
                        ),
                        minimumSize: Size(0, r.buttonHeight),
                      ),
                      child: Text(
                        'EMERGENCY STOP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: r.bodyFontSize,
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

  Widget _buildSwitchCard(
    String title,
    String description,
    bool isOn,
    IconData icon,
    Color color,
    Function(bool) onChanged,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          padding: EdgeInsets.all(r.mediumSpacing),
          decoration: BoxDecoration(
            color: isOn ? color.withValues(alpha: 0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: isOn ? color : Colors.grey[300]!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: r.isVerySmallPhone ? 40 : 50,
                height: r.isVerySmallPhone ? 40 : 50,
                decoration: BoxDecoration(
                  color: isOn ? color : Colors.grey[400],
                  borderRadius: BorderRadius.circular(r.cardRadius),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: r.iconSize,
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
                        fontSize: r.bodyFontSize,
                        fontWeight: FontWeight.bold,
                        color: isOn ? color : Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: r.smallSpacing),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: r.smallFontSize,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOn,
                onChanged: onChanged,
                activeColor: color,
                activeTrackColor: color.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[300],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSwitchDialog(String location, bool isOn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isOn ? Icons.check_circle : Icons.cancel,
              color: isOn ? Colors.green : Colors.red,
            ),
            SizedBox(width: 8),
            Text(isOn ? 'Turned On' : 'Turned Off'),
          ],
        ),
        content: Text(
          '${location} water supply has been ${isOn ? 'activated' : 'deactivated'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _emergencyShutoff() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Shutoff'),
          ],
        ),
        content: Text(
          'Are you sure you want to turn off ALL water supply? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _emergencyShutoffValve();
              Navigator.pop(context);
              _showEmergencyDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('EMERGENCY STOP'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('EMERGENCY STOP'),
          ],
        ),
        content: Text(
          'ALL WATER SUPPLY HAS BEEN SHUT OFF!\n\nContact emergency services if needed.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Valve Control Methods
  Future<void> _toggleMainValve(bool isOpen) async {
    try {
      setState(() {
        if (!isOpen) {
          _kitchenSwitch = false;
          _bathroomSwitch = false;
          _gardenSwitch = false;
          waterFlowData['kitchenFlow'] = 0.0;
          waterFlowData['bathroomFlow'] = 0.0;
          waterFlowData['gardenFlow'] = 0.0;
          waterFlowData['totalFlow'] = 0.0;
        }
      });
      if (!isOpen) {
        await _supabaseService.setAllValvesClosed();
      }
      await _updateFlowData();
    } catch (e) {
      print('❌ Error toggling main valve: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update valve control: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateFlowData() async {
    try {
      final devices = await _supabaseService.getWaterConnectionDevices();

      Map<String, dynamic> findByLocation(String loc) {
        return devices.firstWhere(
          (d) =>
              (d['location']?.toString() ?? '').toLowerCase() ==
              loc.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
      }

      final kitchenDevice = devices.firstWhere(
        (d) => (d['device_id']?.toString() ?? '') == 'ESP_KITCHEN_001',
        orElse: () => findByLocation('Kitchen'),
      );

      final kFlow = (kitchenDevice['water_flow'] as num?)?.toDouble() ?? 0.0;
      final bFlow =
          (findByLocation('Bathroom')['water_flow'] as num?)?.toDouble() ?? 0.0;
      final gFlow =
          (findByLocation('Garden')['water_flow'] as num?)?.toDouble() ?? 0.0;
      
      Map<String, dynamic> flowData = {};
      flowData['kitchenFlow'] = kFlow;
      flowData['bathroomFlow'] = bFlow;
      flowData['gardenFlow'] = gFlow;
      flowData['totalFlow'] = kFlow + bFlow + gFlow;
      
      setState(() {
        waterFlowData = flowData;
      });
      
      print('✅ Flow data updated: Kitchen=$kFlow, Bathroom=$bFlow, Garden=$gFlow, Total=${flowData['totalFlow']}');
    } catch (e) {
      print('Error updating flow data: $e');
    }
  }

  Future<void> _emergencyShutoffValve() async {
    try {
      await _toggleMainValve(false);
      setState(() {
        _kitchenSwitch = false;
        _bathroomSwitch = false;
        _gardenSwitch = false;
      });

      print('🚨 Emergency shutoff completed');
    } catch (e) {
      print('❌ Error during emergency shutoff: $e');
    }
  }

  Future<void> _updateDeviceStatusForLocation(String location, bool isOn) async {
    // Kitchen: Use ESP32 system
    if (location.toLowerCase() == 'kitchen') {
      try {
        // Send command to ESP32
        await _supabaseService.sendValveCommand(
          deviceId: 'ESP_KITCHEN_001',
          commandType: isOn ? 'open_valve' : 'close_valve',
        );
        
        // Also update status directly for immediate UI feedback
        // (ESP32 will sync this later, but we update now for responsiveness)
        // Use current flow from ESP32, or 0.0 if closing
        final currentFlow = waterFlowData['kitchenFlow'] ?? 0.0;
        await _supabaseService.updateKitchenDeviceStatus(
          valveStatus: isOn ? 'open' : 'closed',
          waterFlow: isOn ? currentFlow : 0.0, // Keep actual flow if opening, 0 if closing
        );
        
        print('✅ Sent kitchen command to ESP32: ${isOn ? "OPEN" : "CLOSED"}');
        
        // Don't set fake flow - wait for ESP32 to report actual flow
        // Flow will be updated when ESP32 sends sensor readings
        // Just update the toggle state
        setState(() {});
        
        // Refresh kitchen status to get actual flow from ESP32
        await _refreshKitchenStatus();
        await _updateFlowData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to control kitchen valve: $e'),
            backgroundColor: Colors.red,
          ),
        );
        print('❌ Failed to control kitchen valve: $e');
      }
      return;
    }
    
    // Other locations: Use legacy system
    try {
      await _supabaseService.upsertWaterConnectionControlForLocation(
        location: location,
        isOpen: isOn,
        // We don't guess a fake flow. If the valve is OFF, force 0.00.
        waterFlow: isOn ? (waterFlowData['${location.toLowerCase()}Flow'] as num?)?.toDouble() ?? 0.0 : 0.0,
      );
      print('✅ Updated $location in water_connection_control: ${isOn ? "open" : "closed"}');
      await _updateFlowData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update $location: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('❌ Failed to update $location: $e');
    }
  }
}
