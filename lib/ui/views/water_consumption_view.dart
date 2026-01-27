import 'package:flutter/material.dart';
import 'package:waterleak/core/services/supabase_service.dart';
import 'package:waterleak/core/models/water_data_model.dart';
import 'package:waterleak/ui/shared/responsive.dart';

class WaterConsumptionView extends StatefulWidget {
  @override
  _WaterConsumptionViewState createState() => _WaterConsumptionViewState();
}

class _WaterConsumptionViewState extends State<WaterConsumptionView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final SupabaseService _supabaseService = SupabaseService();
  bool isLoading = true;
  String selectedTimeRange = 'Today'; // Today, Week, Month

  // Data
  List<WaterDataModel> waterData = [];
  Map<String, dynamic> summaryData = {};
  List<Map<String, dynamic>> dailyData = [];

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
    _loadWaterConsumptionData();
  }

  Future<void> _loadWaterConsumptionData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Load data based on selected time range
      List<Map<String, dynamic>> rawData = [];
      DateTime? since;

      switch (selectedTimeRange) {
        case 'Today':
          rawData = await _supabaseService.getTodayWaterData();
          since = DateTime.now().subtract(Duration(days: 1));
          break;
        case 'Week':
          rawData = await _supabaseService.getWeeklyWaterData();
          since = DateTime.now().subtract(Duration(days: 7));
          break;
        case 'Month':
          rawData = await _supabaseService.getMonthlyWaterData();
          since = DateTime.now().subtract(Duration(days: 30));
          break;
      }

      // Convert to WaterDataModel
      waterData = rawData.map((data) => WaterDataModel.fromMap(data)).toList();

      // Get summary data
      summaryData = await _supabaseService.getWaterDataSummary(since: since);

      // Get daily grouped data for charts
      dailyData = await _supabaseService.getWaterDataGroupedByDay(
        days: selectedTimeRange == 'Today'
            ? 1
            : selectedTimeRange == 'Week'
                ? 7
                : 30,
      );

      // If no data, keep empty list
      if (waterData.isEmpty) {
        waterData = [];
      }
    } catch (e) {
      print('Error loading water consumption data: $e');
      waterData = [];
    } finally {
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
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: Color(0xFF1e3c72),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(r),

            // Main Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    margin: r.screenPadding(phone: 16, narrow: 12),
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
                    child: Column(
                      children: [
                        // Title and Time Range Selector
                        _buildHeaderSection(r),

                        // Content
                        Expanded(
                          child: isLoading
                              ? _buildLoadingState(r)
                              : SingleChildScrollView(
                                  padding:
                                      r.screenPadding(phone: 16, narrow: 12),
                                  child: Column(
                                    children: [
                                      // Summary Cards
                                      _buildSummaryCards(r),
                                      SizedBox(
                                          height: r.isSmallPhone ? 20 : 24),

                                      // Charts
                                      _buildChartsSection(r),
                                      SizedBox(
                                          height: r.isSmallPhone ? 20 : 24),

                                      // Recent Data Table
                                      _buildRecentDataTable(r),
                                    ],
                                  ),
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
      ),
    );
  }

  Widget _buildHeader(Responsive r) {
    return Container(
      padding: r.screenPadding(phone: 16, narrow: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Water Consumption',
              style: TextStyle(
                color: Colors.white,
                fontSize: r.isSmallPhone ? 18 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.isSmallPhone ? 8 : 12,
              vertical: r.isSmallPhone ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(r.cardRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  color: Colors.white,
                  size: r.isSmallPhone ? 14 : 16,
                ),
                SizedBox(width: r.isSmallPhone ? 2 : 4),
                Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.isSmallPhone ? 10 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(Responsive r) {
    return Container(
      padding: r.screenPadding(phone: 16, narrow: 12),
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
            Icons.analytics,
            color: Colors.white,
            size: r.isSmallPhone ? 20 : 24,
          ),
          SizedBox(width: r.isSmallPhone ? 8 : 12),
          Expanded(
            child: Text(
              'Water Consumption Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: r.isSmallPhone ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Time Range Selector
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: selectedTimeRange,
              dropdownColor: Colors.white,
              style: TextStyle(color: Colors.white, fontSize: 12),
              underline: SizedBox(),
              items: ['Today', 'Week', 'Month'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child:
                      Text(value, style: TextStyle(color: Color(0xFF1e3c72))),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedTimeRange = newValue;
                  });
                  _loadWaterConsumptionData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Responsive r) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1e3c72)),
          ),
          SizedBox(height: r.mediumSpacing),
          Text(
            'Loading water consumption data...',
            style: TextStyle(
              color: Color(0xFF1e3c72),
              fontSize: r.bodyFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: TextStyle(
            fontSize: r.titleFontSize,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1e3c72),
          ),
        ),
        SizedBox(height: r.mediumSpacing),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: r.smallSpacing,
          mainAxisSpacing: r.smallSpacing,
          children: [
            _buildSummaryCard(
              'Total Water Used',
              '${(summaryData['totalWaterUsed'] ?? 0).toStringAsFixed(1)} L',
              Icons.water_drop,
              Colors.blue,
              r,
            ),
            _buildSummaryCard(
              'Average Flow Rate',
              '${(summaryData['averageFlowRate'] ?? 0).toStringAsFixed(2)} L/min',
              Icons.speed,
              Colors.green,
              r,
            ),
            _buildSummaryCard(
              'Max Flow Rate',
              '${(summaryData['maxFlowRate'] ?? 0).toStringAsFixed(2)} L/min',
              Icons.trending_up,
              Colors.orange,
              r,
            ),
            _buildSummaryCard(
              'Leak Detections',
              '${summaryData['leakDetections'] ?? 0}',
              Icons.warning,
              Colors.red,
              r,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Responsive r,
  ) {
    return Container(
      padding: EdgeInsets.all(r.mediumSpacing),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: r.iconSize),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  selectedTimeRange,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.smallSpacing),
          Text(
            title,
            style: TextStyle(
              fontSize: r.smallFontSize,
              color: Color(0xFF1e3c72).withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: r.smallSpacing),
          Text(
            value,
            style: TextStyle(
              fontSize: r.subtitleFontSize,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Usage Trends',
          style: TextStyle(
            fontSize: r.titleFontSize,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1e3c72),
          ),
        ),
        SizedBox(height: r.mediumSpacing),

        // Daily Usage Chart
        Container(
          padding: EdgeInsets.all(r.mediumSpacing),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Water Usage (${selectedTimeRange})',
                style: TextStyle(
                  fontSize: r.subtitleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1e3c72),
                ),
              ),
              SizedBox(height: r.mediumSpacing),
              Container(
                height: 200,
                child: _buildBarChart(r),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(Responsive r) {
    if (dailyData.isEmpty) {
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

    final maxUsage = dailyData
        .map((d) => (d['totalWaterUsed'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    final denom = maxUsage <= 0 ? 1.0 : maxUsage;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: dailyData.map((dayData) {
        final usage = (dayData['totalWaterUsed'] as num).toDouble();
        final fraction = (usage / denom).clamp(0.0, 1.0).toDouble();

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: LayoutBuilder(
              builder: (context, barConstraints) {
                final maxW = barConstraints.maxWidth;
                final w = 30.0 > maxW ? maxW : 30.0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: fraction,
                          child: Container(
                            width: w,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Color(0xFF1e3c72),
                                  Color(0xFF2193b0),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      dayData['dayName'].toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1e3c72),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${usage.toStringAsFixed(0)}L',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF1e3c72).withValues(alpha: 0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentDataTable(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Data',
          style: TextStyle(
            fontSize: r.titleFontSize,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1e3c72),
          ),
        ),
        SizedBox(height: r.mediumSpacing),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: EdgeInsets.all(r.mediumSpacing),
                decoration: BoxDecoration(
                  color: Color(0xFF1e3c72).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(r.cardRadius),
                    topRight: Radius.circular(r.cardRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Time',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3c72),
                          fontSize: r.smallFontSize,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Flow Rate',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3c72),
                          fontSize: r.smallFontSize,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Total Used',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3c72),
                          fontSize: r.smallFontSize,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3c72),
                          fontSize: r.smallFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Table Rows
              ...waterData.take(10).map((data) => _buildTableRow(data, r)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(WaterDataModel data, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.mediumSpacing),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              data.formattedCreatedAt,
              style: TextStyle(
                fontSize: r.smallFontSize,
                color: Color(0xFF1e3c72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              data.formattedFlowRate,
              style: TextStyle(
                fontSize: r.smallFontSize,
                color: Color(0xFF1e3c72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              data.formattedTotalUsed,
              style: TextStyle(
                fontSize: r.smallFontSize,
                color: Color(0xFF1e3c72),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: data.leakDetected == true
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                data.leakStatusText,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: data.leakDetected == true ? Colors.red : Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
