import 'package:flutter/material.dart';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({Key? key}) : super(key: key);

  @override
  _HistoryViewState createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'High',
    'Medium',
    'Low',
    'Resolved',
    'Repair Needed'
  ];

  // Database data
  List<Map<String, dynamic>> waterDataHistory = [];
  final SupabaseService _supabaseService = SupabaseService();
  String? selectedPropertyId;
  bool isLoading = true;
  bool _initializedFromArgs = false;

  // Water data statistics
  double totalWaterUsed = 0.0;
  int totalLeakDetections = 0;
  double maxFlowRate = 0.0;
  double averageFlowRate = 0.0;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromArgs) return;
    _initializedFromArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final pid = args['propertyId']?.toString();
      if (pid != null && pid.isNotEmpty) selectedPropertyId = pid;

      final leaksArg = args['leaks'];
      if (leaksArg is List) {
        // Dashboard passes leak rows from water_leak_detections already.
        final leaks = leaksArg
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        waterDataHistory = _mapLeakDetectionsToHistory(leaks);
        _calculateStatistics();
        setState(() {
          isLoading = false;
        });
        return;
      }
    }

    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    try {
      setState(() {
        isLoading = true;
      });

      try {
        List<Map<String, dynamic>> leaks;
        if (selectedPropertyId == null) {
          // Fetch all leaks when no property is selected
          leaks = await _supabaseService.getAllLeakDetections();
            } else {
          leaks = await _supabaseService.getLeakDetections(selectedPropertyId!);
          // If the property-filtered query returns nothing (e.g. leak rows have NULL property_id),
          // fall back to global leaks so History still shows the dashboard records.
          if (leaks.isEmpty) {
            leaks = await _supabaseService.getAllLeakDetections();
          }
        }
        waterDataHistory = _mapLeakDetectionsToHistory(leaks);
          _calculateStatistics();
      } catch (e) {
        print('Error loading leak detections: $e');
        waterDataHistory = [];
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading history data: $e');
      waterDataHistory = [];
      setState(() {
        isLoading = false;
      });
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
            borderRadius: BorderRadius.circular(12),
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
                  hintText: 'e.g., Repaired pipe / replaced gasket',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
      await _loadHistoryData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to resolve leak: $e')),
      );
    }
  }

  void _calculateStatistics() {
    totalWaterUsed = waterDataHistory.fold(
        0.0, (sum, item) => sum + (item['totalUsed'] as double));
    totalLeakDetections =
        waterDataHistory.where((item) => item['leakDetected'] == true).length;

    if (waterDataHistory.isNotEmpty) {
      final flowRates =
          waterDataHistory.map((item) => item['flowRate'] as double).toList();
      maxFlowRate = flowRates.reduce((a, b) => a > b ? a : b);
      averageFlowRate = flowRates.reduce((a, b) => a + b) / flowRates.length;
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.purple;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow[700]!;
      default:
        return Colors.blueGrey;
    }
  }

  String _cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

  List<Map<String, dynamic>> _mapLeakDetectionsToHistory(
      List<Map<String, dynamic>> leaks) {
    return leaks.map((l) {
      final detectedAt =
          DateTime.tryParse((l['detection_date'] ?? l['created_at'] ?? '').toString()) ??
              DateTime.now();

      final resolvedAt = DateTime.tryParse((l['resolved_date'] ?? '').toString());
      final statusRaw = (l['status'] ?? 'active').toString();
      final isFalsePositive = l['is_false_positive'] == true;

      final severity = (l['severity'] ?? 'low').toString();
      final sevCap = _cap(severity.toLowerCase());

      final leakDetected =
          !isFalsePositive && statusRaw.toLowerCase() != 'resolved';

      final flowRate = (l['flow_rate_anomaly'] as num?)?.toDouble() ??
          (l['estimated_water_loss_rate'] as num?)?.toDouble() ??
          0.0;

      final totalUsed = (l['estimated_water_loss_liters'] as num?)?.toDouble() ?? 0.0;

      String statusText;
      if (isFalsePositive) {
        statusText = 'False Positive';
      } else {
        statusText = _cap(statusRaw.toLowerCase());
      }

      String duration;
      if (resolvedAt != null) {
        final diff = resolvedAt.difference(detectedAt);
        final mins = diff.inMinutes;
        if (mins < 60) {
          duration = '${mins} min';
        } else {
          duration = '${diff.inHours} hr';
        }
      } else {
        duration = 'Ongoing';
      }

      final location = (l['location_description'] ??
              (l['leak_type'] ?? 'Leak').toString())
          .toString();

      final notes = (l['resolution_notes'] ?? '').toString();

      return {
        'id': l['id'],
        'location': location.isEmpty ? 'Unknown location' : location,
        'severity': sevCap,
        'status': statusText,
        'date': detectedAt.toLocal().toIso8601String().split('T')[0],
        'time':
            '${detectedAt.toLocal().hour.toString().padLeft(2, '0')}:${detectedAt.toLocal().minute.toString().padLeft(2, '0')}',
        'duration': duration,
        'description': (l['leak_type'] ?? 'Leak').toString(),
        'actionTaken': notes.isNotEmpty ? notes : (leakDetected ? 'Investigate leak' : 'Resolved'),
        'cost': totalUsed,
        'flowRate': flowRate,
        'totalUsed': totalUsed,
        'leakDetected': leakDetected,
        'valveStatus': 'UNKNOWN',
        'color': _severityColor(sevCap),
      };
    }).toList();
  }


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredHistory = _getFilteredHistory();

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

                // Filter Section
                _buildFilterSection(),

                // Statistics
                _buildStatistics(filteredHistory),
                

                // History List
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        margin: EdgeInsets.all(r.mediumSpacing),
                        constraints: BoxConstraints(
                          maxWidth: r.isDesktop ? 1000 : 800,
                        ),
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
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: r.mediumSpacing),
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
                                      Icons.history,
                                      color: Colors.white,
                                      size: r.iconSize,
                                    ),
                                    SizedBox(width: r.mediumSpacing),
                                    Expanded(
                                      child: Text(
                                        'Leak History',
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
 
                              // History List (non-nested scroll)
                              if (filteredHistory.isEmpty)
                                _buildEmptyState()
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.all(r.mediumSpacing),
                                  itemCount: filteredHistory.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredHistory[index];
                                    return _buildHistoryCard(item);
                                  },
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
                  'Leak History',
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
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(r.cardRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning,
                        color: Colors.white, size: r.smallIconSize),
                    SizedBox(width: r.smallSpacing),
                    Text(
                      '${waterDataHistory.length} Records',
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

  Widget _buildFilterSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          margin: EdgeInsets.symmetric(horizontal: r.mediumSpacing),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Container(
                  margin: EdgeInsets.only(right: r.smallSpacing),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: TextStyle(fontSize: r.smallFontSize),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    selectedColor: Color(0xFF1e3c72),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: r.smallFontSize,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatistics(List<Map<String, dynamic>> filteredHistory) {
    final totalWaterUsed = filteredHistory.fold<double>(
      0.0,
      (sum, item) => sum + (item['totalUsed'] as double),
    );

    final leakDetections =
        filteredHistory.where((item) => item['leakDetected'] == true).length;
    final normalUsage =
        filteredHistory.where((item) => item['leakDetected'] == false).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);

        // Common stat cards
        final cards = <Widget>[
          _buildStatCard(
                  'Total Water Used',
                  '${totalWaterUsed.toStringAsFixed(6)} L',
                  Icons.water_drop,
                  Colors.blue,
                ),
          _buildStatCard(
                  'Leak Detections',
                  '$leakDetections',
                  Icons.warning,
                  Colors.red,
                ),
          _buildStatCard(
                  'Normal Usage',
                  '$normalUsage',
                  Icons.check_circle,
                  Colors.green,
                ),
        ];

        // On narrow screens stack stats vertically, on wider screens use a row.
        final bool isNarrow = constraints.maxWidth < 600;

        if (isNarrow) {
          return Container(
            margin: EdgeInsets.all(r.mediumSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) SizedBox(height: r.smallSpacing),
                  cards[i],
                ],
              ],
            ),
          );
        }

        return Container(
          margin: EdgeInsets.all(r.mediumSpacing),
          child: Row(
            children: [
              Expanded(child: cards[0]),
              SizedBox(width: r.smallSpacing),
              Expanded(child: cards[1]),
              SizedBox(width: r.smallSpacing),
              Expanded(child: cards[2]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = Responsive(context);
        return Container(
          padding: EdgeInsets.all(r.mediumSpacing),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: r.iconSize),
              SizedBox(height: r.smallSpacing),
              Text(
                value,
                style: TextStyle(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: r.smallFontSize,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No leak history found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final severity = item['severity'] as String? ?? 'Normal';
    final status = item['status'] as String? ?? 'Unknown';
    final color = item['color'] as Color;
    final leakId = (item['id'] ?? '').toString();
    final statusLower = status.toLowerCase();

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getSeverityIcon(severity),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          item['location'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['date']} at ${item['time']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(severity),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    severity,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == 'Resolved' ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Description', item['description']),
                SizedBox(height: 8),
                _buildDetailRow('Flow Rate',
                    '${item['flowRate'].toStringAsFixed(6)} L/min'),
                SizedBox(height: 8),
                _buildDetailRow(
                    'Total Used', '${item['totalUsed'].toStringAsFixed(6)} L'),
                SizedBox(height: 8),
                _buildDetailRow('Valve Status',
                    item['valveStatus'].toString().toUpperCase()),
                SizedBox(height: 8),
                _buildDetailRow('Action Taken', item['actionTaken']),
                SizedBox(height: 12),
                if (item['leakDetected'] == true)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      '⚠️ LEAK DETECTED: ${item['totalUsed'].toStringAsFixed(6)} L water lost',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (statusLower != 'resolved' && leakId.isNotEmpty) ...[
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _promptResolveLeak(leakId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text(
                        'Fix Leak (Mark Resolved)',
                        style: TextStyle(color: Colors.white),
                      ),
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'High':
        return Icons.warning;
      case 'Medium':
        return Icons.info;
      case 'Low':
        return Icons.help;
      default:
        return Icons.warning;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getFilteredHistory() {
    if (_selectedFilter == 'All') {
      return waterDataHistory;
    }

    return waterDataHistory.where((item) {
      if (_selectedFilter == 'Resolved') {
        return (item['status']?.toString().toLowerCase() ?? '') == 'resolved';
      } else if (_selectedFilter == 'Repair Needed') {
        // Anything not resolved is "needs repair/attention"
        return (item['status']?.toString().toLowerCase() ?? '') != 'resolved';
      } else {
        return item['severity'] == _selectedFilter;
      }
    }).toList();
  }
}
