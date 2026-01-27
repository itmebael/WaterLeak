import 'package:flutter/material.dart';
import 'dart:async';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class PipelineView extends StatefulWidget {
  @override
  _PipelineViewState createState() => _PipelineViewState();
}

class _PipelineViewState extends State<PipelineView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Database data
  List<Map<String, dynamic>> pipelineSegments = [];
  List<Map<String, dynamic>> devices = [];
  List<Map<String, dynamic>> leakDetections = [];
  List<Map<String, dynamic>> _deviceStatuses = [];
  final SupabaseService _supabaseService = SupabaseService();
  String? selectedPropertyId;
  bool isLoading = true;

  // Realtime subscriptions per segment
  final Map<String, StreamSubscription<List<Map<String, dynamic>>>>
      _sensorSubscriptions = {};
  final Set<String> _activeLeakSegmentIds = <String>{};

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
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
    // Try to get passed arguments first to avoid re-fetch and missing property
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        selectedPropertyId = args['propertyId'] as String?;
        final List<dynamic>? segs = args['segments'] as List<dynamic>?;
        if (segs != null && segs.isNotEmpty) {
          pipelineSegments = List<Map<String, dynamic>>.from(segs);
          // Normalize fields expected by the view
          pipelineSegments = pipelineSegments.map((segment) {
            final List<dynamic> rawCoords = (segment['coordinates'] is List)
                ? (segment['coordinates'] as List)
                : <dynamic>[];
            final List<double> coords = rawCoords
                .map((v) => (v as num?)?.toDouble() ?? 0.0)
                .toList()
                .cast<double>();

            return {
              ...segment,
              'name': segment['segment_name'] ??
                  segment['name'] ??
                  'Unknown Segment',
              'location': segment['location_description'] ??
                  segment['location'] ??
                  'Unknown Location',
              'pressure': ((segment['pressure_threshold_min'] ??
                          segment['pressure']) as num?)
                      ?.toDouble() ??
                  0.0,
              'flow':
                  ((segment['flow_threshold_min'] ?? segment['flow']) as num?)
                          ?.toDouble() ??
                      0.0,
              'hasLeak': (segment['status'] == 'maintenance') ||
                  (segment['hasLeak'] == true),
              'leakSeverity': _getLeakSeverity(segment),
              'coordinates': coords.length >= 4
                  ? coords.sublist(0, 4)
                  : <double>[],
              'description': segment['location_description'] ??
                  segment['description'] ??
                  'No description available',
              'lastInspection': segment['last_inspection_date']?.toString() ??
                  segment['lastInspection'] ??
                  'Not set',
              'nextInspection': segment['next_inspection_date']?.toString() ??
                  segment['nextInspection'] ??
                  'Not set',
              'material': segment['material'] ?? 'Unknown',
              'diameter': segment['diameter'] ?? 'Unknown',
              'age': segment['age'] ?? '${segment['age_years'] ?? 0} years',
              'segmentType': segment['segment_type'] ??
                  segment['segmentType'] ??
                  'unknown',
            };
          }).toList();

          setState(() {});
          _startRealtimeDetection();
          return;
        }
      }
      _loadPipelineData();
    });
  }

  Future<void> _loadPipelineData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // 1. Load User Property
      try {
        final properties = await _supabaseService.getProperties();
        if (properties.isNotEmpty) {
          selectedPropertyId = properties.first['id'];
        }
      } catch (e) {
        print('Error loading properties: $e');
      }

      // 2. Load Devices (for reference)
      await _loadDevices();

      // 3. Load Device Statuses & Build Segments (Primary Data Source)
      try {
        _deviceStatuses = await _supabaseService.getDeviceStatuses();
        // Dynamically build segments from device statuses
        pipelineSegments = _buildDefaultPipelineSegments();
      } catch (e) {
        print('Error loading device statuses: $e');
        _deviceStatuses = [];
        pipelineSegments = [];
      }
      
      // 4. Start Realtime Detection on the populated segments
      if (pipelineSegments.isNotEmpty) {
         await _startRealtimeDetection();
      }

      // 5. Load existing leaks
      if (selectedPropertyId != null) {
        await _loadLeakDetections();
      } else {
        leakDetections = [];
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading pipeline data: $e');
      pipelineSegments = [];
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _startRealtimeDetection() async {
    // Cancel previous subscriptions if any
    for (final sub in _sensorSubscriptions.values) {
      await sub.cancel();
    }
    _sensorSubscriptions.clear();

    for (final segment in pipelineSegments) {
      final String? segmentId = segment['id'] as String?;
      if (segmentId == null) continue;

      final subscription = _supabaseService
          .subscribeToSensorReadings(segmentId)
          .listen((readings) => _handleSensorReadings(segment, readings));

      _sensorSubscriptions[segmentId] = subscription;
    }
  }

  Future<void> _handleSensorReadings(
    Map<String, dynamic> segment,
    List<Map<String, dynamic>> readings,
  ) async {
    if (readings.isEmpty) return;

    // Use most recent reading
    final latest = readings.first;

    final double? pressurePsi = (latest['pressure_psi'] as num?)?.toDouble();
    final double? flowLpm = (latest['flow_rate_lpm'] as num?)?.toDouble();

    final double minPressure =
        (segment['pressure_threshold_min'] as num?)?.toDouble() ?? 0.0;
    final double maxFlow =
        (segment['flow_threshold_max'] as num?)?.toDouble() ?? double.infinity;

    final bool pressureBreach = pressurePsi != null &&
        pressurePsi < (minPressure <= 0 ? 10.0 : minPressure);
    final bool flowBreach = flowLpm != null && flowLpm > maxFlow;

    final bool detected = pressureBreach || flowBreach;

    // Update UI model
    final int idx =
        pipelineSegments.indexWhere((s) => s['id'] == segment['id']);
    if (idx != -1) {
      setState(() {
        pipelineSegments[idx]['hasLeak'] = detected;
        pipelineSegments[idx]['leakSeverity'] =
            detected && pressureBreach && flowBreach
                ? 'High'
                : (detected ? 'Low' : 'Low');
        pipelineSegments[idx]['status'] = detected ? 'warning' : 'normal';
      });
    }

    // Send signal to Supabase on first detection per segment to avoid duplicates
    final String segId = segment['id']?.toString() ?? '';
    if (detected &&
        !_activeLeakSegmentIds.contains(segId) &&
        selectedPropertyId != null) {
      _activeLeakSegmentIds.add(segId);
      try {
        final leakRow = await _supabaseService.createLeakDetection({
          'property_id': selectedPropertyId,
          'segment_id': segId,
          'detection_date': DateTime.now().toIso8601String(),
          'leak_type': flowBreach ? 'continuous' : 'intermittent',
          'severity': (pressureBreach && flowBreach) ? 'high' : 'low',
          'status': 'active',
          'location_description':
              segment['location_description'] ?? segment['location'],
          'flow_rate_anomaly': flowLpm,
          'pressure_drop':
              pressurePsi != null ? (minPressure - pressurePsi) : null,
          'sensor_data': latest,
          'confidence_score': 0.85,
        });

        // Create in-app notification for current user
        await _supabaseService.createNotification({
          'leak_detection_id': leakRow['id'],
          'notification_type': 'in_app',
          'title': 'Leak detected in ${segment['name'] ?? 'segment'}',
          'message': 'Automatic detection flagged a leak. Tap to view details.',
          'severity': (pressureBreach && flowBreach) ? 'high' : 'low',
          'is_sent': true,
          'sent_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Rollback active flag so we can retry on next reading
        _activeLeakSegmentIds.remove(segId);
        // Optionally log
        // print('Failed to send leak signal: $e');
      }
    }
  }

  String _getLeakSeverity(Map<String, dynamic> segment) {
    // Check if there are any active leaks for this segment
    // This would typically come from the leak_detections table
    // For now, we'll use a simple logic based on status
    switch (segment['status']) {
      case 'maintenance':
        return 'High';
      case 'warning':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  Future<void> _loadLeakDetections() async {
    try {
      if (selectedPropertyId != null) {
        leakDetections = await _supabaseService.getLeakDetections(selectedPropertyId!);
        // Filter to only active leaks
        leakDetections = leakDetections.where((leak) => 
          leak['status'] == 'active' || leak['status'] == null
        ).toList();
      } else {
        leakDetections = [];
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading leak detections: $e');
      leakDetections = [];
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildLeakCountBadge(Responsive r) {
    final activeLeakCount = leakDetections.length;
    if (activeLeakCount == 0) {
      return SizedBox.shrink(); // Don't show badge if no leaks
    }
    
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.mediumSpacing, vertical: r.smallSpacing),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning,
              color: Colors.white, size: r.smallIconSize),
          SizedBox(width: r.smallSpacing),
          Text(
            '$activeLeakCount ${activeLeakCount == 1 ? 'Leak' : 'Leaks'}',
            style: TextStyle(
              color: Colors.white,
              fontSize: r.smallFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDevices() async {
    try {
      final allDevices = await _supabaseService.getDevices();
      // Filter devices for current property if selectedPropertyId is set
      if (selectedPropertyId != null) {
        devices = allDevices.where((device) => 
          device['property_id'] == selectedPropertyId || device['property_id'] == null
        ).toList();
      } else {
        // Show all devices if no property is selected
        devices = allDevices;
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading devices: $e');
      devices = [];
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final sub in _sensorSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1e3c72),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final r = Responsive(context);
            return Column(
              children: [
                // Header
                _buildHeader(),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Pipeline Visualization
                        FadeTransition(
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
                                  // Pipeline Title
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
                                          Icons.water_drop,
                                          color: Colors.white,
                                          size: r.iconSize,
                                        ),
                                        SizedBox(width: r.smallSpacing),
                                        Flexible(
                                          child: Text(
                                            'Pipeline Monitoring',
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

                                  // Pipeline Diagram
                                  Container(
                                    height: r.h * 0.6, // Increased height for better visibility
                                    padding: EdgeInsets.all(r.mediumSpacing),
                                    child: _buildPipelineDiagram(),
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
              ],
            );
          },
        ),
      ),
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
                  'Smart Pipeline Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildLeakCountBadge(r),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPipelineDiagram() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          // Background grid
          _buildGrid(),

          // 3D Pipeline segments with joints
          ...pipelineSegments.map((segment) => _build3DPipelineSegment(segment)),

          // Pipe joints/connections
          ...pipelineSegments.map((segment) => _buildPipeJoint(segment)),

          // Enhanced leak indicators
          ...pipelineSegments
              .where((segment) => segment['hasLeak'])
              .map((segment) => _buildEnhancedLeakIndicator(segment)),

          // Water flow indicators
          ...pipelineSegments.map((segment) => _buildWaterFlowIndicator(segment)),

          // Pipeline labels
          ...pipelineSegments.map((segment) => _buildPipelineLabel(segment)),

          // Legend
          _buildLegend(),

          // Click instructions
          _buildClickInstructions(),

          // Device Status Dots (User Request)
          _buildDeviceStatusDots(),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusDots() {
    if (_deviceStatuses.isEmpty) return SizedBox.shrink();

    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.grid_view, size: 14, color: Colors.grey[700]),
                SizedBox(width: 5),
                Text('All Devices Monitor', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[800])),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _deviceStatuses.map((device) {
                final status = (device['status'] ?? 'OFFLINE').toString().toUpperCase();
                final valveStatus = (device['valve_status'] ?? 'CLOSED').toString().toUpperCase();
                final flow = (device['water_flow'] as num?)?.toDouble() ?? 0.0;
                String name = device['device_name'] ?? 'Unknown';

                // Map known devices to friendly names
                if (name.toLowerCase() == 'device 1') {
                  name = 'Kitchen';
                } else if (name.toLowerCase() == 'device 2') {
                  name = 'Bathroom';
                } else if (name.toLowerCase() == 'device 3') {
                  name = 'Garden';
                }
                
                // Determine leak status based on user requirement and legend
                // Legend: Normal (Blue), High Leak (Red), Low Leak (Orange)
                final bool isLeak = status == 'LEAK' || 
                                   (valveStatus == 'CLOSED' && flow > 0.0);
                
                Color statusColor;
                if (isLeak) {
                  // Distinguish High vs Low leak based on flow rate or explicit status
                  if (flow > 5.0 || status == 'LEAK') {
                    statusColor = Colors.red; // High Leak
                  } else {
                    statusColor = Colors.orange; // Low Leak
                  }
                } else if (status == 'OFFLINE') {
                  statusColor = Colors.grey; // Offline (matches Legend)
                } else {
                  statusColor = Colors.blue; // Normal (matches Legend)
                }
                
                return Tooltip(
                  message: '$name\nStatus: $status\nFlow: $flow\nValve: $valveStatus',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                             BoxShadow(
                               color: statusColor.withValues(alpha: 0.4), 
                               blurRadius: 4,
                               spreadRadius: 1
                             ),
                          ]
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        name.length > 8 ? '${name.substring(0, 6)}...' : name,
                        style: TextStyle(fontSize: 9, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildDefaultPipelineSegments() {
    if (_deviceStatuses.isEmpty) {
      return [];
    }

    List<Map<String, dynamic>> segments = [];
    final int count = _deviceStatuses.length;
    
    // Dynamic layout calculation to avoid hardcoded slots
    // Distribute segments vertically with consistent spacing
    final double startY = 0.15;
    final double availableHeight = 0.7; // 0.15 to 0.85

    for (int i = 0; i < count; i++) {
      final device = _deviceStatuses[i];
      String deviceName = device['device_name']?.toString() ?? 'Device ${i + 1}';
      
      // Map known devices to friendly names
      if (deviceName.toLowerCase() == 'device 1') {
        deviceName = 'Kitchen';
      } else if (deviceName.toLowerCase() == 'device 2') {
        deviceName = 'Bathroom';
      } else if (deviceName.toLowerCase() == 'device 3') {
        deviceName = 'Garden';
      }

      final valveStatus = (device['valve_status'] ?? 'CLOSED').toString().toUpperCase();
      final status = (device['status'] ?? 'OFFLINE').toString().toUpperCase();
      final flow = (device['water_flow'] as num?)?.toDouble() ?? 0.0;

      // Determine leak status
      final bool hasLeak = status == 'LEAK' || (valveStatus == 'CLOSED' && flow > 0.0);
      final bool isOffline = status == 'OFFLINE';

      // Dynamic coordinate generation
      double y;
      if (count == 1) {
        y = 0.5; // Center if only one
      } else {
        // Distribute evenly
        // If too many devices, squeeze them, otherwise use comfortable spacing
        double normalizedPos = i / (count - 1 > 0 ? count - 1 : 1);
        y = startY + (normalizedPos * availableHeight);
      }
      
      // Ensure we don't go too close to edges
      y = y.clamp(0.1, 0.9);

      // Create a horizontal pipe segment
      // Alternating start points slightly for visual variety or keep uniform?
      // Keeping uniform is cleaner for "no hardcoded data" interpretation.
      List<double> coords = [0.1, y, 0.9, y];

      segments.add({
        'id': device['id']?.toString() ?? 'dev_seg_$i',
        'name': deviceName,
        'location': deviceName,
        'coordinates': coords,
        'status': hasLeak ? 'warning' : (isOffline ? 'offline' : 'normal'),
        'hasLeak': hasLeak,
        'isOffline': isOffline,
        'leakSeverity': hasLeak ? 'High' : 'Low',
        'pressure': 0.0,
        'flow': flow,
        'device_data': device,
      });
    }

    return segments;
  }

  // _build3DPipeVisualization removed (unused)

  Widget _buildPipeJoint(Map<String, dynamic> segment) {
    final coordinates = segment['coordinates'] as List<double>;
    final hasLeak = segment['hasLeak'] as bool;

    return Positioned(
      left: coordinates[0] * 300 - 12,
      top: coordinates[1] * 200 - 12,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: hasLeak ? Colors.red : Colors.grey[600],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.link,
            color: Colors.white,
            size: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildClickInstructions() {
    return Positioned(
      left: 10,
      bottom: 10,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Tap any pipe segment to inspect',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showLeakAlert(Map<String, dynamic> segment) {
    final severity = segment['leakSeverity'] as String? ?? 'Low';
    final leakDetails = segment['leakDetails'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor:
              severity == 'High' ? Colors.red[50] : Colors.orange[50],
          title: Row(
            children: [
              Icon(
                Icons.warning,
                color: severity == 'High' ? Colors.red : Colors.orange,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'WATER LEAK DETECTED!',
                style: TextStyle(
                  color: severity == 'High' ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${segment['name']} has a ${severity.toLowerCase()} severity leak.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Location: ${leakDetails['location']}',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'Estimated Loss: ${leakDetails['estimatedLoss']}',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'Priority: ${leakDetails['priority']}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: severity == 'High' ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Here you could add functionality to immediately schedule repair
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    severity == 'High' ? Colors.red : Colors.orange,
              ),
              child: Text(
                'Schedule Repair',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPipelineLabel(Map<String, dynamic> segment) {
    final coordinates = segment['coordinates'] as List<double>? ?? <double>[0.1, 0.2, 0.4, 0.2];
    final name = segment['name'] as String? ?? 'Unknown Segment';
    final hasLeak = segment['hasLeak'] as bool;
    final isOffline = segment['isOffline'] as bool? ?? false;

    return Positioned(
      left: coordinates[0] * 300 + 5,
      top: coordinates[1] * 200 - 25,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: hasLeak
              ? Colors.red.withValues(alpha: 0.9)
              : (isOffline
                  ? Colors.grey.withValues(alpha: 0.9)
                  : Colors.blue.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      right: 10,
      top: 10,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legend',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3c72),
              ),
            ),
            SizedBox(height: 8),
            _buildLegendItem('Normal', Colors.blue, Icons.check_circle),
            _buildLegendItem('Offline', Colors.grey, Icons.power_off),
            _buildLegendItem('High Leak', Colors.red, Icons.warning),
            _buildLegendItem('Low Leak', Colors.orange, Icons.warning),
            _buildLegendItem('Flow Rate', Colors.cyan, Icons.water_drop),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return CustomPaint(
      size: Size.infinite,
      painter: GridPainter(),
    );
  }

  Widget _build3DPipelineSegment(Map<String, dynamic> segment) {
    final coordinates = segment['coordinates'] as List<double>;
    final hasLeak = segment['hasLeak'] as bool;
    final isOffline = segment['isOffline'] as bool? ?? false;
    final severity = segment['leakSeverity'] as String?;

    // Calculate normalized bounds to avoid negative dimensions
    final x1 = coordinates[0] * 300;
    final y1 = coordinates[1] * 200;
    final x2 = coordinates[2] * 300;
    final y2 = coordinates[3] * 200;

    final left = x1 < x2 ? x1 : x2;
    final top = y1 < y2 ? y1 : y2;
    final width = (x1 - x2).abs();
    final height = (y1 - y2).abs();

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _showSegmentDetails(segment),
        child: Container(
          width: width,
          height: height,
          child: CustomPaint(
            painter: Pipeline3DPainter(
              hasLeak: hasLeak,
              isOffline: isOffline,
              leakSeverity: severity,
              flow: (segment['flow'] as num?)?.toDouble() ?? 0.0,
              pressure: (segment['pressure'] as num?)?.toDouble() ?? 0.0,
            ),
          ),
        ),
      ),
    );
  }

  void _showSegmentDetails(Map<String, dynamic> segment) {
    // Show immediate leak notification if segment has a leak
    if (segment['hasLeak']) {
      _showLeakAlert(segment);
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final r = Responsive(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.cardRadius),
          ),
          child: Container(
            constraints: BoxConstraints(
                maxHeight: Responsive(context).h * 0.8),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _supabaseService.getDeviceStatusByName(segment['name']),
              builder: (context, snapshot) {
                final deviceData = snapshot.data;
                final displaySegment = Map<String, dynamic>.from(segment);
                if (deviceData != null) {
                   displaySegment['valve_status'] = deviceData['valve_status'];
                   displaySegment['status'] = deviceData['device_status'];
                }
                
                String imageUrl = 'https://images.unsplash.com/photo-1585314062340-f1a5a7c9328d?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80';
                final nameLower = displaySegment['name'].toString().toLowerCase();
                if (nameLower.contains('kitchen')) {
                  imageUrl = 'https://images.unsplash.com/photo-1556910103-1c02745a30bf?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80';
                } else if (nameLower.contains('bathroom')) {
                  imageUrl = 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80';
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                Container(
                  padding: EdgeInsets.all(r.mediumSpacing),
                  decoration: BoxDecoration(
                    color: displaySegment['hasLeak'] ? Colors.red : Color(0xFF1e3c72),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(r.cardRadius),
                      topRight: Radius.circular(r.cardRadius),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        displaySegment['hasLeak'] ? Icons.warning : Icons.info,
                        color: Colors.white,
                        size: r.iconSize,
                      ),
                      SizedBox(width: r.mediumSpacing),
                      Expanded(
                        child: Text(
                          displaySegment['name'],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: Colors.white, size: r.iconSize),
                            onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(r.mediumSpacing),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Section
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: r.mediumSpacing),

                        // Status Card
                        _buildStatusCard(displaySegment),
                        SizedBox(height: r.mediumSpacing),

                        // Device Database Status
                        if (deviceData != null) ...[
                          _buildInfoSection('Device Status (Live DB)', [
                            _buildInfoRow('Device ID', deviceData['device_name'] ?? 'Unknown'),
                            _buildInfoRow('Valve Status', deviceData['valve_status'] ?? 'Unknown'),
                            _buildInfoRow('Connection', deviceData['status'] ?? 'Unknown'),
                            _buildInfoRow('Water Flow', '${deviceData['water_flow'] ?? 0}'),
                            _buildInfoRow('Last Update', deviceData['last_update'] != null ? 
                                DateTime.parse(deviceData['last_update']).toLocal().toString().split('.')[0] : 'Never'),
                          ]),
                          SizedBox(height: r.mediumSpacing),
                        ],

                        // Basic Information
                        _buildInfoSection('Basic Information', [
                          _buildInfoRow('Location', displaySegment['location']),
                          _buildInfoRow('Description', displaySegment['description']),
                          _buildInfoRow('Material', displaySegment['material']),
                          _buildInfoRow('Diameter', displaySegment['diameter']),
                          _buildInfoRow('Age', displaySegment['age']),
                        ]),
                        SizedBox(height: r.mediumSpacing),

                        // Technical Data
                        _buildInfoSection('Technical Data', [
                          _buildInfoRow(
                              'Pressure', '${displaySegment['pressure']} PSI'),
                          _buildInfoRow(
                              'Flow Rate', '${displaySegment['flow']} L/min'),
                          _buildInfoRow(
                              'Last Inspection', displaySegment['lastInspection']),
                          _buildInfoRow(
                              'Next Inspection', displaySegment['nextInspection']),
                        ]),

                        // Leak Details (if applicable)
                        if (displaySegment['hasLeak']) ...[
                          SizedBox(height: r.mediumSpacing),
                          _buildLeakDetailsSection(displaySegment),
                        ],

                        // Recommendations
                        SizedBox(height: r.mediumSpacing),
                        _buildRecommendationsSection(displaySegment),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: EdgeInsets.all(r.mediumSpacing),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Here you could add functionality to schedule repair
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF1e3c72),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.cardRadius),
                            ),
                            minimumSize: Size(0, r.buttonHeight),
                          ),
                          child: Text(
                            segment['hasLeak']
                                ? 'Schedule Repair'
                                : 'Schedule Inspection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.bodyFontSize,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(width: r.mediumSpacing),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.cardRadius),
                            ),
                            minimumSize: Size(0, r.buttonHeight),
                          ),
                          child: Text(
                            'Close',
                            style: TextStyle(fontSize: r.bodyFontSize),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> segment) {
    final hasLeak = segment['hasLeak'] as bool;
    final isOffline = segment['isOffline'] as bool? ?? false;
    final status = segment['status'] as String? ?? 'active';

    Color statusColor;
    Color bgColor;
    IconData icon;

    if (hasLeak) {
      statusColor = Colors.red;
      bgColor = Colors.red[50]!;
      icon = Icons.warning;
    } else if (isOffline) {
      statusColor = Colors.grey;
      bgColor = Colors.grey[200]!;
      icon = Icons.power_off;
    } else {
      statusColor = Colors.green;
      bgColor = Colors.green[50]!;
      icon = Icons.check_circle;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          padding: EdgeInsets.all(r.mediumSpacing),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(
              color: statusColor,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: r.isVerySmallPhone ? 40 : 50,
                height: r.isVerySmallPhone ? 40 : 50,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
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
                      'Status: ${status.toUpperCase()}',
                      style: TextStyle(
                        fontSize: r.subtitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasLeak && segment['leakSeverity'] != null)
                      Text(
                        'Severity: ${segment['leakSeverity']}',
                        style: TextStyle(
                          fontSize: r.bodyFontSize,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildInfoSection(String title, List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: r.subtitleFontSize,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3c72),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: r.mediumSpacing),
            Container(
              padding: EdgeInsets.all(r.mediumSpacing),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(r.cardRadius),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: children,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Padding(
          padding: EdgeInsets.symmetric(vertical: r.smallSpacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: r.isVerySmallPhone ? 100 : 120,
                child: Text(
                  '$label:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                    fontSize: r.bodyFontSize,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: r.bodyFontSize,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeakDetailsSection(Map<String, dynamic> segment) {
    final leakDetails = segment['leakDetails'] as Map<String, dynamic>? ?? {};

    return _buildInfoSection('Leak Details', [
      _buildInfoRow('Detected Date', leakDetails['detectedDate']),
      _buildInfoRow('Estimated Loss', leakDetails['estimatedLoss']),
      _buildInfoRow('Location', leakDetails['location']),
      _buildInfoRow('Cause', leakDetails['cause']),
      _buildInfoRow('Priority', leakDetails['priority']),
      _buildInfoRow('Estimated Cost', leakDetails['estimatedCost']),
    ]);
  }

  Widget _buildRecommendationsSection(Map<String, dynamic> segment) {
    final recommendations = segment['recommendations'] as List<String>? ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: TextStyle(
                fontSize: r.subtitleFontSize,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3c72),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: r.mediumSpacing),
            Container(
              padding: EdgeInsets.all(r.mediumSpacing),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(r.cardRadius),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Column(
                children: recommendations.map((recommendation) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: r.smallSpacing),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                          size: r.smallIconSize,
                        ),
                        SizedBox(width: r.smallSpacing),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: r.bodyFontSize,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnhancedLeakIndicator(Map<String, dynamic> segment) {
    final coordinates = segment['coordinates'] as List<double>? ?? <double>[0.1, 0.2, 0.4, 0.2];
    final severity = segment['leakSeverity'] as String? ?? 'Low';

    return Positioned(
      left: coordinates[2] * 300 - 20,
      top: coordinates[3] * 200 - 20,
      child: GestureDetector(
        onTap: () => _showSegmentDetails(segment),
        child: Container(
          width: 40,
          height: 40,
          child: Stack(
            children: [
              // Pulsing background
              AnimatedContainer(
                duration: Duration(milliseconds: 1000),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: severity == 'High'
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              // Main indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: severity == 'High' ? Colors.red : Colors.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: severity == 'High'
                          ? Colors.red.withValues(alpha: 0.6)
                          : Colors.orange.withValues(alpha: 0.6),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              // Leak severity indicator
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: severity == 'High'
                        ? Colors.red[800]
                        : Colors.orange[800],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      severity == 'High' ? 'H' : 'L',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterFlowIndicator(Map<String, dynamic> segment) {
    final coordinates = segment['coordinates'] as List<double>? ?? <double>[0.1, 0.2, 0.4, 0.2];
    final flow = (segment['flow'] as num?)?.toDouble() ?? 0.0;
    final hasLeak = segment['hasLeak'] as bool? ?? false;
    final isOffline = segment['isOffline'] as bool? ?? false;

    if (flow <= 0) return SizedBox.shrink();

    return Positioned(
      left: coordinates[0] * 300 + 10,
      top: coordinates[1] * 200 + 10,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: hasLeak
              ? Colors.red.withValues(alpha: 0.8)
              : (isOffline
                  ? Colors.grey.withValues(alpha: 0.8)
                  : Colors.cyan.withValues(alpha: 0.8)),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            '${flow.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    // Draw vertical lines
    for (double i = 0; i <= size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    // Draw horizontal lines
    for (double i = 0; i <= size.height; i += 50) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Pipeline3DPainter extends CustomPainter {
  final bool hasLeak;
  final bool isOffline;
  final String? leakSeverity;
  final double flow;
  final double pressure;
  
  Pipeline3DPainter({
    required this.hasLeak,
    this.isOffline = false,
    this.leakSeverity,
    required this.flow,
    required this.pressure,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;
      
    // Simple 3D pipe representation
    // Main pipe body
    final pipeGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: hasLeak 
          ? [Colors.red[300]!, Colors.red[700]!, Colors.red[900]!]
          : (isOffline 
              ? [Colors.grey[400]!, Colors.grey[700]!, Colors.grey[900]!]
              : [Colors.blue[300]!, Colors.blue[700]!, Colors.blue[900]!]),
      stops: [0.0, 0.5, 1.0],
    );
    
    paint.shader = pipeGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Draw pipe as a rounded rect
    final pipeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.3, size.width, size.height * 0.4),
      Radius.circular(10),
    );
    
    canvas.drawRRect(pipeRect, paint);
    
    // Draw flow arrows if there is flow
    if (flow > 0) {
      _drawFlowArrows(canvas, size);
    }
  }
  
  void _drawFlowArrows(Canvas canvas, Size size) {
    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    final path = Path();
    final midY = size.height / 2;
    
    // Draw a few arrows along the pipe
    for (double x = 20; x < size.width; x += 40) {
      path.moveTo(x, midY - 5);
      path.lineTo(x + 10, midY);
      path.lineTo(x, midY + 5);
    }
    
    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Add the Realistic3DPipePainter class which was missing or I need to define it
class Realistic3DPipePainter extends CustomPainter {
  final bool hasLeak;
  final bool isOffline;
  final String? leakSeverity;
  final double flow;
  final double pressure;
  final String segmentType;

  Realistic3DPipePainter({
    required this.hasLeak,
    this.isOffline = false,
    this.leakSeverity,
    required this.flow,
    required this.pressure,
    required this.segmentType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Reuse the logic from Pipeline3DPainter for now but maybe more detailed
    final paint = Paint()
      ..style = PaintingStyle.fill;
      
    // Main pipe body
    final pipeGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: hasLeak 
          ? [Colors.red[300]!, Colors.red[700]!, Colors.red[900]!]
          : (isOffline 
              ? [Colors.grey[400]!, Colors.grey[700]!, Colors.grey[900]!]
              : [Colors.blue[300]!, Colors.blue[700]!, Colors.blue[900]!]),
      stops: [0.0, 0.5, 1.0],
    );
    
    paint.shader = pipeGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Draw pipe
    final pipeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.6),
      Radius.circular(5),
    );
    
    canvas.drawRRect(pipeRect, paint);
    
    // Highlights
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
      
    canvas.drawLine(
      Offset(5, size.height * 0.3),
      Offset(size.width - 5, size.height * 0.3),
      highlightPaint
    );
    
    // Flow indicators
    if (flow > 0) {
      _drawFlowArrows(canvas, size);
    }
  }
  
  void _drawFlowArrows(Canvas canvas, Size size) {
    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    final path = Path();
    final midY = size.height / 2;
    
    // Draw arrows
    for (double x = 15; x < size.width; x += 30) {
      path.moveTo(x, midY - 4);
      path.lineTo(x + 8, midY);
      path.lineTo(x, midY + 4);
    }
    
    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
