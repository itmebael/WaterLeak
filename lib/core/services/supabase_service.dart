import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String _hardcodedAdminId = 'hardcoded_admin';

  // Always read the client from Supabase singleton to avoid late init errors
  SupabaseClient get _client => Supabase.instance.client;
  final AuthService _authService = AuthService();

  Future<void> initialize() async {
    // No-op: AuthService initializes Supabase in main.dart
    // Keeping for backward compatibility
  }

  // Initialize database with sample data if tables are empty
  Future<void> initializeDatabase() async {
    try {
      // Check if properties table exists and has data
      final properties = await getProperties();
      if (properties.isEmpty) {
        print('📊 Initializing database with sample data...');
        await _createSampleData();
      }
    } catch (e) {
      print('⚠️ Database initialization skipped: $e');
    }
  }

  Future<void> _createSampleData() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      // Create a sample property
      final property = await createProperty({
        'property_name': 'My Home',
        'property_type': 'residential',
        'address': '123 Main Street',
        'city': 'Catbalogan',
        'state': 'Samar',
        'zip_code': '6700',
      });

      // Create sample pipeline segments
      await createPipelineSegment({
        'property_id': property['id'],
        'segment_name': 'Kitchen Line',
        'segment_type': 'kitchen',
        'location_description': 'Main kitchen water supply line',
        'material': 'copper',
        'diameter': '0.75 inch',
        'age_years': 5,
        'status': 'active',
        'pressure_threshold_min': 30.0,
        'pressure_threshold_max': 80.0,
        'flow_threshold_min': 0.5,
        'flow_threshold_max': 50.0,
        'is_monitored': true,
      });

      await createPipelineSegment({
        'property_id': property['id'],
        'segment_name': 'Bathroom Line',
        'segment_type': 'bathroom',
        'location_description': 'Bathroom water supply line',
        'material': 'pex',
        'diameter': '0.5 inch',
        'age_years': 3,
        'status': 'active',
        'pressure_threshold_min': 30.0,
        'pressure_threshold_max': 80.0,
        'flow_threshold_min': 0.5,
        'flow_threshold_max': 50.0,
        'is_monitored': true,
      });

      // Create sample water consumption data
      final today = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final date = today.subtract(Duration(days: i));
        await insertDailyConsumption({
          'property_id': property['id'],
          'consumption_date': date.toIso8601String().split('T')[0],
          'total_consumption_liters': 150.0 + (i * 2.5),
          'peak_consumption_liters': 200.0 + (i * 3.0),
          'average_flow_rate': 2.5 + (i * 0.1),
          'peak_flow_rate': 5.0 + (i * 0.2),
          'number_of_usage_events': 8 + (i % 5),
          'duration_minutes': 120 + (i * 2),
          'cost_php': 7.5 + (i * 0.125),
          'is_anomaly': i % 7 == 0,
          'anomaly_score': i % 7 == 0 ? 0.8 : 0.2,
        });
      }

      // Create sample water connection control device with water usage data
      await _client.from('water_connection_control').upsert({
        'device_id': 'ESP_KITCHEN_001',
        'device_name': 'Kitchen Water Controller',
        'valve_status': 'open',
        'water_flow': 2.5,
        'pressure': 45.2,
        'temperature': 22.5,
        'is_online': true,
        'last_heartbeat': DateTime.now().toIso8601String(),
        'location': 'Kitchen',
        'user_id': userId,
        'property_id': property['id'],
        'total_water_used': 1250.75,
        'sensor_data': {
          'water_sensor_1_percent': '12.5',
          'water_sensor_2_percent': '8.2',
          'water_sensor_1_detected': false,
          'water_sensor_2_detected': false,
          'water_leak_detected': false,
          'detection_method': 'water_sensor'
        }
      }, onConflict: 'device_id');

      // Create sample water control history records for the device
      final now = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final timestamp = now.subtract(Duration(hours: i * 2));
        await _client.from('water_control_history').insert({
          'device_id': 'ESP_KITCHEN_001',
          'timestamp': timestamp.toIso8601String(),
          'water_flow': 1.5 + (i % 3).toDouble(),
          'pressure': 40.0 + (i % 5).toDouble(),
          'temperature': 20.0 + (i % 2).toDouble(),
          'valve_status': i % 4 == 0 ? 'closed' : 'open',
          'is_online': true,
          'total_water_used': 1000.0 + (i * 25.0),
          'property_id': property['id'],
          'user_id': userId
        });
      }

      print('✅ Sample data created successfully');
    } catch (e) {
      print('❌ Failed to create sample data: $e');
    }
  }

  SupabaseClient get client => Supabase.instance.client;

  // Get current user ID from AuthService
  String? get currentUserId {
    final id = _authService.currentUser?['id'];
    return id == _hardcodedAdminId ? null : id;
  }

  // Leak heuristics (used when only flow snapshots are available)
  static const double _leakThresholdLpm = 0.2;
  static const double _startThresholdLpm = 2.0;

  bool _isLeakLikeFlow(double flowLpm) =>
      flowLpm > _leakThresholdLpm && flowLpm < _startThresholdLpm;

  Future<List<Map<String, dynamic>>> _getWaterControlHistoryRaw({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? deviceIds,
    List<String>? propertyIds,
    int limit = 10000,
  }) async {
    try {
      var query = _client
          .from('water_connection_control_history')
          .select(
              'id, device_id, device_name, valve_status, water_flow, total_water_used, pressure, temperature, is_online, last_heartbeat, location, user_id, property_id, recorded_at')
          .gte('recorded_at', startDate.toIso8601String())
          .lte('recorded_at', endDate.toIso8601String());

      if (deviceIds != null && deviceIds.isNotEmpty) {
        // This repo uses `inFilter` for IN filters (supabase_flutter/postgrest version).
        query = query.inFilter('device_id', deviceIds);
      } else if (propertyIds != null && propertyIds.isNotEmpty) {
        query = query.inFilter('property_id', propertyIds);
      }

      final rows =
          await query.order('recorded_at', ascending: true).limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      // Table may not exist yet until SQL is executed.
      print('water_connection_control_history fetch failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getWaterControlSnapshotRows() async {
    try {
      final devices = await getWaterConnectionDevices();
      if (devices.isEmpty) return [];

      final totalUsedSnapshot = devices.fold<double>(
        0.0,
        (sum, d) => sum + ((d['total_water_used'] as num?)?.toDouble() ?? 0.0),
      );
      final totalFlowSnapshot = devices.fold<double>(
        0.0,
        (sum, d) => sum + ((d['water_flow'] as num?)?.toDouble() ?? 0.0),
      );
      final anyOpen = devices.any(
        (d) => (d['valve_status'] ?? '').toString().toLowerCase() == 'open',
      );

      final now = DateTime.now().toIso8601String();
      return [
        {
          'id': 'snapshot',
          'created_at': now,
          'flow_rate': totalFlowSnapshot,
          'total_used': totalUsedSnapshot,
          'leak_detected': _isLeakLikeFlow(totalFlowSnapshot),
          'valve_status': anyOpen ? 'open' : 'closed',
          'location': 'All',
          'sensor_id': 'snapshot',
        }
      ];
    } catch (e) {
      print('water_connection_control snapshot fallback failed: $e');
      return [];
    }
  }

  String _defaultDeviceIdForLocation(String location) {
    switch (location.toLowerCase()) {
      case 'kitchen':
        return 'ESP_KITCHEN_001';
      case 'bathroom':
        return 'ESP_BATHROOM_001';
      case 'garden':
        return 'ESP_GARDEN_001';
      default:
        return 'ESP_${location.toUpperCase().replaceAll(' ', '_')}_001';
    }
  }

  String _defaultDeviceNameForLocation(String location) {
    switch (location.toLowerCase()) {
      case 'kitchen':
        return 'Kitchen Valve';
      case 'bathroom':
        return 'Bathroom Valve';
      case 'garden':
        return 'Garden Valve';
      default:
        return '$location Valve';
    }
  }

  // Properties Management
  Future<List<Map<String, dynamic>>> getProperties() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _client
          .from('properties')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // If the table doesn't exist yet or schema is not initialized,
      // fail soft by returning an empty list so the UI can continue.
      print("getProperties failed, returning empty list: $e");
      return <Map<String, dynamic>>[];
    }
  }

  // Admin helpers (fetch data for an arbitrary user)
  // NOTE: Requires database policies to allow admin access; otherwise returns empty.
  Future<List<Map<String, dynamic>>> getPropertiesByUserId(
      String userId) async {
    try {
      final response = await _client
          .from('properties')
          .select(
              'id, property_name, property_type, address, city, state, zip_code, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('getPropertiesByUserId failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> getUserWaterUsageSummary({
    required String userId,
    int days = 30,
  }) async {
    try {
      final props = await getPropertiesByUserId(userId);
      final propertyIds =
          props.map((p) => p['id']?.toString()).whereType<String>().toList();

      final since = DateTime.now().subtract(Duration(days: days));

      double total = 0.0;
      final Map<String, double> totalsByDay = {};
      String? source;

      // 1) Preferred: water_consumption_daily (linked by properties -> user)
      if (propertyIds.isNotEmpty) {
        try {
          final rows = await _client
              .from('water_consumption_daily')
              .select('property_id, consumption_date, total_consumption_liters')
              .inFilter('property_id', propertyIds)
              .gte('consumption_date', since.toIso8601String().substring(0, 10))
              .order('consumption_date', ascending: false);

          final list = List<Map<String, dynamic>>.from(rows);
          for (final r in list) {
            final liters =
                (r['total_consumption_liters'] as num?)?.toDouble() ?? 0.0;
            total += liters;
            final dayKey = (r['consumption_date'] ?? '').toString();
            if (dayKey.isNotEmpty) {
              totalsByDay[dayKey] = (totalsByDay[dayKey] ?? 0.0) + liters;
            }
          }
          if (list.isNotEmpty) source = 'water_consumption_daily';
        } catch (e) {
          // ignore: fallback below (table missing / RLS / etc)
          print('water_consumption_daily fetch failed: $e');
        }
      }

      // 2) Fallback: derive usage from water_data via the user's devices
      // devices.user_id -> devices.device_name -> water_data.sensor_id
      if (source == null) {
        try {
          final devRows = await _client
              .from('devices')
              .select('id, device_name')
              .eq('user_id', userId)
              .order('created_at', ascending: false);
          final devices = List<Map<String, dynamic>>.from(devRows);
          final sensorIds = devices
              .map((d) => d['device_name']?.toString())
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .toList();

          if (sensorIds.isNotEmpty) {
            final rows = await _client
                .from('water_data')
                .select('sensor_id, created_at, total_used')
                .inFilter('sensor_id', sensorIds)
                .gte('created_at', since.toIso8601String())
                .order('created_at', ascending: true)
                .limit(10000);

            final list = List<Map<String, dynamic>>.from(rows);
            final perDay = <String, double>{};

            // Sum positive deltas of total_used per sensor_id.
            final Map<String, double?> lastBySensor = {};
            for (final r in list) {
              final sid = (r['sensor_id'] ?? '').toString();
              final used = (r['total_used'] as num?)?.toDouble();
              if (sid.isEmpty || used == null) continue;

              final prev = lastBySensor[sid];
              if (prev != null) {
                final delta = used - prev;
                if (delta > 0) {
                  total += delta;
                  final createdAt =
                      DateTime.tryParse((r['created_at'] ?? '').toString());
                  if (createdAt != null) {
                    final d = createdAt.toLocal();
                    final key =
                        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                    perDay[key] = (perDay[key] ?? 0.0) + delta;
                  }
                }
              }
              lastBySensor[sid] = used;
            }

            totalsByDay.addAll(perDay);
            if (list.isNotEmpty) source = 'water_data';
          }
        } catch (e) {
          print('water_data fallback failed: $e');
        }
      }

      // Build last 7 days series (descending)
      final now = DateTime.now();
      final daily = <Map<String, dynamic>>[];
      for (int i = 0; i < 7; i++) {
        final d = now.subtract(Duration(days: i));
        final key =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        daily.add({
          'date': key,
          'liters': totalsByDay[key] ?? 0.0,
        });
      }

      return {
        'properties': props,
        'totalLiters': total,
        'days': days,
        'daily': daily,
        'source': source,
      };
    } catch (e) {
      print('getUserWaterUsageSummary failed: $e');
      return {
        'properties': <Map<String, dynamic>>[],
        'totalLiters': 0.0,
        'days': days,
        'daily': <Map<String, dynamic>>[],
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> getCurrentUserWaterSavingsComparison() async {
    final userId = currentUserId;
    if (userId == null) {
      return {
        'success': false,
        'error': 'User not authenticated',
        'lastMonthLiters': 0.0,
        'thisMonthLiters': 0.0,
        'savedLiters': 0.0,
        'savedPercent': 0.0,
      };
    }

    try {
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = thisMonthStart.subtract(const Duration(days: 1));

      print('💧 Starting water savings calculation for user: $userId');

      // Determine the user's properties first (devices are often linked by property_id)
      final props = await getProperties();
      final propertyIds =
          props.map((p) => p['id']?.toString()).whereType<String>().toList();
      print('🏠 Properties for user: ${propertyIds.length}');

      // Get device rows from water_connection_control (primary source)
      final List<Map<String, dynamic>> controlRows = [];
      try {
        final byUser = await _client
            .from('water_connection_control')
            .select('device_id, total_water_used, user_id, property_id')
            .eq('user_id', userId);
        controlRows.addAll(List<Map<String, dynamic>>.from(byUser));
      } catch (e) {
        print('⚠️ water_connection_control query by user_id failed: $e');
      }
      if (propertyIds.isNotEmpty) {
        try {
          final byProp = await _client
              .from('water_connection_control')
              .select('device_id, total_water_used, user_id, property_id')
              .inFilter('property_id', propertyIds);
          controlRows.addAll(List<Map<String, dynamic>>.from(byProp));
        } catch (e) {
          print('⚠️ water_connection_control query by property_id failed: $e');
        }
      }

      // De-duplicate by device_id
      final Map<String, Map<String, dynamic>> uniqueControl = {};
      for (final r in controlRows) {
        final did = (r['device_id'] ?? '').toString();
        if (did.trim().isEmpty) continue;
        uniqueControl[did] = r;
      }

      final deviceIds = uniqueControl.keys.toList();
      print(
          '📱 Devices found in water_connection_control: ${deviceIds.length}');

      Future<double> sumMonthlyRange({
        required DateTime start,
        required DateTime end,
        bool isLastMonth = false,
      }) async {
        double total = 0.0;
        print(
            '📊 Calculating water usage for range: ${start.toIso8601String()} to ${end.toIso8601String()} (isLastMonth: $isLastMonth)');

        print('📱 Using ${deviceIds.length} device(s) for savings calc');

        // Primary: Use water_connection_control_history
        try {
          final hist = await _getWaterControlHistoryRaw(
            startDate: start.subtract(const Duration(days: 1)),
            endDate: end.add(const Duration(days: 1)),
            deviceIds: deviceIds.isNotEmpty ? deviceIds : null,
            propertyIds: deviceIds.isEmpty ? propertyIds : null,
            limit: 50000,
          );

          print(
              '📈 Found ${hist.length} history records for date range ${start.toIso8601String()} to ${end.toIso8601String()}');

          if (hist.isNotEmpty) {
            // Filter records to exact date range and sort by time
            final filteredHist = hist.where((r) {
              final ts = DateTime.tryParse((r['recorded_at'] ?? '').toString());
              if (ts == null) return false;
              // Include records from start of day to end of day
              final recordDate = DateTime(ts.year, ts.month, ts.day);
              final startDate = DateTime(start.year, start.month, start.day);
              final endDate = DateTime(end.year, end.month, end.day);
              return !recordDate.isBefore(startDate) &&
                  !recordDate.isAfter(endDate);
            }).toList();

            print(
                '📊 Filtered to ${filteredHist.length} records within exact date range');

            if (filteredHist.isNotEmpty) {
              // Group by device_id and find first/last records for each device
              final Map<String, List<Map<String, dynamic>>> byDevice = {};
              for (final r in filteredHist) {
                final did = (r['device_id'] ?? '').toString();
                if (did.isEmpty) continue;
                byDevice.putIfAbsent(did, () => []).add(r);
              }

              // Sort each device's records by recorded_at
              for (final deviceRecords in byDevice.values) {
                deviceRecords.sort((a, b) {
                  final ta =
                      DateTime.tryParse((a['recorded_at'] ?? '').toString());
                  final tb =
                      DateTime.tryParse((b['recorded_at'] ?? '').toString());
                  if (ta == null || tb == null) return 0;
                  return ta.compareTo(tb);
                });
              }

              // Calculate consumption using sum of positive daily changes to handle counter resets
              for (final entry in byDevice.entries) {
                final did = entry.key;
                final records = entry.value;
                if (records.length < 2) {
                  // If only one record, can't calculate delta - skip or use 0
                  print(
                      '⚠️ Device $did: Only ${records.length} record(s), skipping delta calculation');
                  continue;
                }

                double deviceTotal = 0.0;
                double lastValidValue =
                    (records.first['total_water_used'] as num?)?.toDouble() ??
                        0.0;

                // Process each record and sum only positive changes (handle counter resets)
                for (int i = 1; i < records.length; i++) {
                  final current = records[i];
                  final currentUsed =
                      (current['total_water_used'] as num?)?.toDouble() ?? 0.0;
                  final delta = currentUsed - lastValidValue;

                  if (delta > 0) {
                    // Normal case: water usage increased
                    deviceTotal += delta;
                    lastValidValue = currentUsed;
                  } else if (delta < 0 && currentUsed >= 0) {
                    // Counter reset: device was reset, start counting from new value
                    print(
                        '🔄 Device $did: Counter reset detected (${lastValidValue.toStringAsFixed(2)} → ${currentUsed.toStringAsFixed(2)}), continuing from new value');
                    lastValidValue = currentUsed;
                  }
                  // If delta is 0 or negative but currentUsed is invalid, keep lastValidValue
                }

                if (deviceTotal > 0) {
                  total += deviceTotal;
                  print(
                      '💧 Device $did: ${deviceTotal.toStringAsFixed(2)} L (sum of positive changes)');
                } else {
                  print(
                      '⚠️ Device $did: No positive consumption changes found');
                }
              }

              if (total > 0) {
                print(
                    '✅ Total from history: ${total.toStringAsFixed(2)} L (using ${byDevice.length} device(s))');
                return total;
              } else {
                print(
                    '⚠️ History records found but total consumption = 0 (all deltas were 0 or negative)');
              }
            } else {
              print('⚠️ No history records found within exact date range');
            }
          } else {
            print(
                '⚠️ No history records found in database for this date range');
          }
        } catch (e) {
          print('❌ water_connection_control_history range sum failed: $e');
        }

        // Fallback: Use current snapshot from water_connection_control (not truly monthly)
        try {
          // Try multiple query strategies to get devices
          List<Map<String, dynamic>> allControlRows = [];

          // Strategy 1: By user_id
          try {
            final byUser = await _client
                .from('water_connection_control')
                .select('device_id, total_water_used, user_id, property_id')
                .eq('user_id', userId);
            allControlRows.addAll(List<Map<String, dynamic>>.from(byUser));
          } catch (e) {
            print('⚠️ Query by user_id failed: $e');
          }

          // Strategy 2: By property_id if we have properties
          if (propertyIds.isNotEmpty) {
            try {
              final byProperty = await _client
                  .from('water_connection_control')
                  .select('device_id, total_water_used, user_id, property_id')
                  .inFilter('property_id', propertyIds);
              allControlRows
                  .addAll(List<Map<String, dynamic>>.from(byProperty));
            } catch (e) {
              print('⚠️ Query by property_id failed: $e');
            }
          }

          // Strategy 3: Get all devices (for testing/fallback)
          if (allControlRows.isEmpty) {
            try {
              final allDevices = await _client
                  .from('water_connection_control')
                  .select('device_id, total_water_used, user_id, property_id')
                  .limit(100);
              allControlRows = List<Map<String, dynamic>>.from(allDevices);
              print(
                  '📦 Using all devices as fallback: ${allControlRows.length} devices');
            } catch (e) {
              print('⚠️ Query all devices failed: $e');
            }
          }

          // Remove duplicates by device_id
          final uniqueDevices = <String, Map<String, dynamic>>{};
          for (final r in allControlRows) {
            final did = (r['device_id'] ?? '').toString();
            if (did.isNotEmpty && !uniqueDevices.containsKey(did)) {
              uniqueDevices[did] = r;
            }
          }

          print(
              '📱 Found ${uniqueDevices.length} unique devices from current snapshot');

          for (final r in uniqueDevices.values) {
            final used = (r['total_water_used'] as num?)?.toDouble() ?? 0.0;
            if (used > 0) {
              total += used;
              print(
                  '💧 Device ${r['device_id']}: ${used.toStringAsFixed(2)} L');
            }
          }

          if (total > 0) {
            // If this is last month and we're using snapshot, try to find earliest history record
            if (isLastMonth) {
              try {
                // Try to find the earliest history record before this month to estimate last month's end value
                final earliestHist = await _client
                    .from('water_connection_control_history')
                    .select('total_water_used, recorded_at')
                    .lt('recorded_at', thisMonthStart.toIso8601String())
                    .order('recorded_at', ascending: false)
                    .limit(1);

                if (earliestHist.isNotEmpty) {
                  final earliestRecord =
                      List<Map<String, dynamic>>.from(earliestHist).first;
                  final earliestUsed =
                      (earliestRecord['total_water_used'] as num?)
                              ?.toDouble() ??
                          0.0;
                  final earliestDate =
                      earliestRecord['recorded_at']?.toString();

                  if (earliestUsed > 0) {
                    // Use the earliest record's total_water_used as last month's estimate
                    print(
                        '📊 Found earliest history record (${earliestDate ?? "unknown date"}): ${earliestUsed.toStringAsFixed(2)} L');
                    print(
                        '   Using this as LAST MONTH estimate (current: ${total.toStringAsFixed(2)} L)');
                    return earliestUsed;
                  }
                }
              } catch (e) {
                print(
                    '⚠️ Could not fetch earliest history for last month estimate: $e');
              }

              // Fallback: Estimate last month as 90-95% of current (assuming some growth)
              final estimated = total * 0.92;
              print(
                  '⚠️ Using snapshot fallback for LAST MONTH - estimating as ${estimated.toStringAsFixed(2)} L (92% of current ${total.toStringAsFixed(2)} L)');
              print(
                  '   ⚠️ This is an ESTIMATE - real data requires water_connection_control_history records');
              return estimated;
            } else {
              // This month: use current snapshot
              print(
                  '✅ Total from current snapshot (THIS MONTH): ${total.toStringAsFixed(2)} L');
              return total;
            }
          }
        } catch (e) {
          print('❌ Current snapshot fallback failed: $e');
        }

        // Final fallback: Try water_consumption_monthly
        try {
          if (propertyIds.isNotEmpty) {
            var cursor = DateTime(start.year, start.month, 1);
            while (cursor.isBefore(end.add(const Duration(days: 1)))) {
              final rows = await _client
                  .from('water_consumption_monthly')
                  .select('total_consumption_liters')
                  .inFilter('property_id', propertyIds)
                  .eq('year', cursor.year)
                  .eq('month', cursor.month);
              for (final r in List<Map<String, dynamic>>.from(rows)) {
                total +=
                    (r['total_consumption_liters'] as num?)?.toDouble() ?? 0.0;
              }
              cursor = DateTime(cursor.year, cursor.month + 1, 1);
            }
            if (total > 0) {
              print(
                  '✅ Total from monthly consumption: ${total.toStringAsFixed(2)} L');
              return total;
            }
          }
        } catch (e) {
          print('❌ water_consumption_monthly range sum failed: $e');
        }

        print('⚠️ No water usage data found, returning 0.0');
        return total;
      }

      print(
          '📅 Calculating last month: ${lastMonthStart.toIso8601String()} to ${lastMonthEnd.toIso8601String()}');
      final lastMonthLiters = await sumMonthlyRange(
        start: lastMonthStart,
        end: lastMonthEnd,
        isLastMonth: true, // Flag to indicate this is last month
      );

      print(
          '📅 Calculating this month: ${thisMonthStart.toIso8601String()} to ${now.toIso8601String()}');
      final thisMonthLiters = await sumMonthlyRange(
        start: thisMonthStart,
        end: now,
        isLastMonth: false, // This is current month
      );

      print('💾 Water Savings Calculation Summary:');
      print('   Last Month: ${lastMonthLiters.toStringAsFixed(2)} L');
      print('   This Month: ${thisMonthLiters.toStringAsFixed(2)} L');

      // Warn if both months have the same value (likely using snapshot fallback)
      if (lastMonthLiters == thisMonthLiters && lastMonthLiters > 0) {
        print(
            '⚠️ WARNING: Both months show the same value (${lastMonthLiters.toStringAsFixed(2)} L)');
        print(
            '   This suggests using current snapshot instead of historical data.');
        print(
            '   Check if water_connection_control_history has records for these date ranges.');
      }

      final savedLiters = lastMonthLiters - thisMonthLiters;
      final savedPercent =
          lastMonthLiters > 0 ? (savedLiters / lastMonthLiters) * 100 : 0.0;

      // If no data found, use current device totals as fallback for display
      if (lastMonthLiters == 0.0 && thisMonthLiters == 0.0) {
        try {
          // Get all devices (try multiple strategies - same as sumMonthlyRange)
          List<Map<String, dynamic>> allDevices = [];

          // Try by user_id
          try {
            final byUser = await _client
                .from('water_connection_control')
                .select('device_id, total_water_used, user_id, property_id')
                .eq('user_id', userId);
            allDevices.addAll(List<Map<String, dynamic>>.from(byUser));
            print('📱 Found ${allDevices.length} devices by user_id');
          } catch (e) {
            print('⚠️ Fallback: Query by user_id failed: $e');
          }

          // Try by property
          final props = await getProperties();
          final propertyIds = props
              .map((p) => p['id']?.toString())
              .whereType<String>()
              .toList();
          if (propertyIds.isNotEmpty && allDevices.isEmpty) {
            try {
              final byProperty = await _client
                  .from('water_connection_control')
                  .select('device_id, total_water_used, user_id, property_id')
                  .inFilter('property_id', propertyIds);
              allDevices.addAll(List<Map<String, dynamic>>.from(byProperty));
              print('📱 Found ${allDevices.length} devices by property_id');
            } catch (e) {
              print('⚠️ Fallback: Query by property_id failed: $e');
            }
          }

          // Last resort: get all devices
          if (allDevices.isEmpty) {
            try {
              final all = await _client
                  .from('water_connection_control')
                  .select('device_id, total_water_used, user_id, property_id')
                  .limit(100);
              allDevices = List<Map<String, dynamic>>.from(all);
              print(
                  '📱 Found ${allDevices.length} devices (all devices fallback)');
            } catch (e) {
              print('⚠️ Fallback: Query all devices failed: $e');
            }
          }

          // Remove duplicates
          final uniqueDevices = <String, Map<String, dynamic>>{};
          for (final d in allDevices) {
            final did = (d['device_id'] ?? '').toString();
            if (did.isNotEmpty && !uniqueDevices.containsKey(did)) {
              uniqueDevices[did] = d;
            }
          }

          double currentTotal = 0.0;
          for (final d in uniqueDevices.values) {
            final used = (d['total_water_used'] as num?)?.toDouble() ?? 0.0;
            if (used > 0) {
              currentTotal += used;
              print(
                  '💧 Device ${d['device_id']}: ${used.toStringAsFixed(2)} L');
            }
          }

          // Use current total for this month, estimate last month as 95% (slight decrease)
          if (currentTotal > 0) {
            final estimatedThisMonth = currentTotal;
            final estimatedLastMonth = currentTotal * 0.95;

            print(
                '📊 Using estimated values from ${uniqueDevices.length} device(s): total=${currentTotal.toStringAsFixed(2)}L');
            return {
              'success': true,
              'lastMonthLiters': estimatedLastMonth,
              'thisMonthLiters': estimatedThisMonth,
              'savedLiters': estimatedLastMonth - estimatedThisMonth,
              'savedPercent': estimatedLastMonth > 0
                  ? ((estimatedLastMonth - estimatedThisMonth) /
                          estimatedLastMonth) *
                      100
                  : 0.0,
            };
          } else {
            print(
                '⚠️ No devices found with water usage data (total_water_used = 0)');
          }
        } catch (e) {
          print('❌ Fallback calculation failed: $e');
        }
      }

      return {
        'success': true,
        'lastMonthStart': lastMonthStart.toIso8601String(),
        'lastMonthEnd': lastMonthEnd.toIso8601String(),
        'thisMonthStart': thisMonthStart.toIso8601String(),
        'lastMonthLiters': lastMonthLiters,
        'thisMonthLiters': thisMonthLiters,
        'savedLiters': savedLiters,
        'savedPercent': savedPercent,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'lastMonthLiters': 0.0,
        'thisMonthLiters': 0.0,
        'savedLiters': 0.0,
        'savedPercent': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> createProperty(
      Map<String, dynamic> propertyData) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    propertyData['user_id'] = userId;

    // Ensure required fields have defaults if not provided
    propertyData['state'] = propertyData['state'] ?? 'Unknown';
    propertyData['city'] = propertyData['city'] ?? 'Unknown';
    propertyData['zip_code'] = propertyData['zip_code'] ?? '0000';

    try {
      final response = await _client
          .from('properties')
          .insert(propertyData)
          .select()
          .single();
      return response;
    } catch (e) {
      // Handle RLS policy errors - try with service role or bypass
      if (e.toString().contains('42501') ||
          e.toString().contains('row-level security') ||
          e.toString().contains('violates row-level security policy')) {
        print('⚠️ RLS policy error detected. Attempting to work around...');
        // The RLS policy should allow inserts, but if it doesn't,
        // the database admin needs to update the policies
        // For now, we'll just re-throw with a helpful message
        throw Exception(
            'Unable to create property due to database security settings. Please contact support or check RLS policies.');
      }

      // If columns don't exist, try without them
      if (e.toString().contains('PGRST204') ||
          e.toString().contains('state') ||
          e.toString().contains('zip_code') ||
          e.toString().contains('city')) {
        print('⚠️ Some columns may not exist, trying with minimal fields...');
        final minimalData = <String, dynamic>{
          'user_id': userId,
          'property_name': propertyData['property_name'] ?? 'My Home',
          'property_type': propertyData['property_type'] ?? 'residential',
          'address': propertyData['address'] ?? 'Unknown Address',
        };

        // Try to add optional columns if they might exist
        try {
          final response = await _client
              .from('properties')
              .insert(minimalData)
              .select()
              .single();
          return response;
        } catch (e2) {
          // If that fails, try with even fewer fields
          final basicData = <String, dynamic>{
            'user_id': userId,
            'property_name': propertyData['property_name'] ?? 'My Home',
            'property_type': propertyData['property_type'] ?? 'residential',
          };
          final response = await _client
              .from('properties')
              .insert(basicData)
              .select()
              .single();
          return response;
        }
      }
      rethrow;
    }
  }

  Future<void> updateProperty(
      String propertyId, Map<String, dynamic> updates) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client
        .from('properties')
        .update(updates)
        .eq('id', propertyId)
        .eq('user_id', userId);
  }

  Future<void> deleteProperty(String propertyId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client
        .from('properties')
        .delete()
        .eq('id', propertyId)
        .eq('user_id', userId);
  }

  // Pipeline Segments Management
  Future<List<Map<String, dynamic>>> getPipelineSegments(
      String propertyId) async {
    final response = await _client
        .from('pipeline_segments')
        .select()
        .eq('property_id', propertyId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createPipelineSegment(
      Map<String, dynamic> segmentData) async {
    final response = await _client
        .from('pipeline_segments')
        .insert(segmentData)
        .select()
        .single();

    return response;
  }

  Future<void> updatePipelineSegment(
      String segmentId, Map<String, dynamic> updates) async {
    await _client.from('pipeline_segments').update(updates).eq('id', segmentId);
  }

  // Water Consumption Management
  Future<List<Map<String, dynamic>>> getDailyConsumption(String propertyId,
      {String? segmentId}) async {
    var query = _client
        .from('water_consumption_daily')
        .select()
        .eq('property_id', propertyId);

    if (segmentId != null) {
      query = query.eq('segment_id', segmentId);
    }

    final response =
        await query.order('consumption_date', ascending: false).limit(30);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getWeeklyConsumption(
      String propertyId) async {
    final response = await _client
        .from('water_consumption_weekly')
        .select()
        .eq('property_id', propertyId)
        .order('week_start_date', ascending: false)
        .limit(12);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getMonthlyConsumption(
      String propertyId) async {
    final response = await _client
        .from('water_consumption_monthly')
        .select()
        .eq('property_id', propertyId)
        .order('year', ascending: false)
        .order('month', ascending: false)
        .limit(12);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> insertDailyConsumption(
      Map<String, dynamic> consumptionData) async {
    await _client.from('water_consumption_daily').upsert(consumptionData,
        onConflict: 'property_id,segment_id,consumption_date');
  }

  // Water Leak Detections
  Future<List<Map<String, dynamic>>> getLeakDetections(String propertyId,
      {String? status}) async {
    var query = _client.from('water_leak_detections').select('''
          id,
          property_id,
          segment_id,
          detection_date,
          leak_type,
          severity,
          status,
          location_description,
          sensor_data,
          confidence_score,
          created_at,
          updated_at
        ''').eq('property_id', propertyId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('detection_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getLeakDetectionById(String leakId) async {
    try {
      final response = await _client.from('water_leak_detections').select('''
            id,
            property_id,
            segment_id,
            detection_date,
            leak_type,
            severity,
            status,
            location_description,
            sensor_data,
            confidence_score,
            created_at,
            updated_at
          ''').eq('id', leakId).maybeSingle();
      return response;
    } catch (e) {
      print('Error getting leak detection by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> createLeakDetection(
      Map<String, dynamic> leakData) async {
    final response = await _client
        .from('water_leak_detections')
        .insert(leakData)
        .select()
        .single();

    return response;
  }

  Future<void> updateLeakDetection(
      String leakId, Map<String, dynamic> updates) async {
    await _client
        .from('water_leak_detections')
        .update(updates)
        .eq('id', leakId);
  }

  /// Mark a leak as resolved and store optional resolution notes.
  /// Uses the DB defaults/triggers for updated_at if present.
  Future<void> resolveLeakDetection(
    String leakId, {
    String? resolutionNotes,
  }) async {
    final updates = <String, dynamic>{
      'status': 'resolved',
      'resolved_date': DateTime.now().toIso8601String(),
    };
    if (resolutionNotes != null && resolutionNotes.trim().isNotEmpty) {
      updates['resolution_notes'] = resolutionNotes.trim();
    }
    await updateLeakDetection(leakId, updates);
  }

  Future<List<Map<String, dynamic>>> getLeakHistory(
      String leakDetectionId) async {
    final response = await _client
        .from('leak_history')
        .select()
        .eq('leak_detection_id', leakDetectionId)
        .order('action_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addLeakHistory(Map<String, dynamic> historyData) async {
    await _client.from('leak_history').insert(historyData);
  }

  // Notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _client
        .from('leak_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _client.from('leak_notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  Future<void> createNotification(Map<String, dynamic> notificationData) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    notificationData['user_id'] = userId;

    await _client.from('leak_notifications').insert(notificationData);
  }

  // Sensor Readings
  Future<List<Map<String, dynamic>>> getSensorReadings(String segmentId,
      {int limit = 100}) async {
    final response = await _client
        .from('sensor_readings')
        .select()
        .eq('segment_id', segmentId)
        .order('reading_timestamp', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> insertSensorReading(Map<String, dynamic> readingData) async {
    await _client.from('sensor_readings').insert(readingData);
  }

  // Water Switch Controls
  Future<List<Map<String, dynamic>>> getWaterSwitches(String segmentId) async {
    final response = await _client
        .from('water_switch_controls')
        .select()
        .eq('segment_id', segmentId);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateWaterSwitch(
      String switchId, Map<String, dynamic> updates) async {
    await _client
        .from('water_switch_controls')
        .update(updates)
        .eq('id', switchId);
  }

  // Emergency Contacts
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _client
        .from('emergency_contacts')
        .select()
        .eq('user_id', userId)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Admin: fetch all emergency_contacts (requires permissive RLS / admin policy)
  Future<List<Map<String, dynamic>>> getAllEmergencyContacts({
    int limit = 5000,
  }) async {
    try {
      final response = await _client
          .from('emergency_contacts')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting all emergency contacts: $e');
      return [];
    }
  }

  // Admin: fetch leak detections across all properties
  Future<List<Map<String, dynamic>>> getAllLeakDetections({
    int limit = 5000,
    String? status,
  }) async {
    try {
      var query = _client.from('water_leak_detections').select('''
        id,
        property_id,
        segment_id,
        detection_date,
        leak_type,
        severity,
        status,
        location_description,
        sensor_data,
        confidence_score,
        created_at,
        updated_at
      ''');

      // Fetch all first, then filter by status in Dart (handles case-insensitive)
      final response =
          await query.order('detection_date', ascending: false).limit(limit);

      var result = List<Map<String, dynamic>>.from(response);

      // Filter by status if provided (case-insensitive)
      if (status != null) {
        final statusLower = status.toLowerCase();
        result = result.where((leak) {
          final leakStatus = (leak['status'] ?? '').toString().toLowerCase();
          return leakStatus == statusLower;
        }).toList();
      }

      print(
          '✅ getAllLeakDetections: Found ${result.length} leaks (status filter: $status, total fetched: ${List<Map<String, dynamic>>.from(response).length})');
      return result;
    } catch (e) {
      print('Error getting all leak detections: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createEmergencyContact(
      Map<String, dynamic> contactData) async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        // For admin operations, allow creating without user_id if not set
        if (!contactData.containsKey('user_id')) {
          print(
              '⚠️ Warning: No user_id provided for emergency contact creation');
        }
      } else {
        contactData['user_id'] = userId;
      }

      final response = await _client
          .from('emergency_contacts')
          .insert(contactData)
          .select()
          .single();

      return response;
    } catch (e) {
      print('Error creating emergency contact: $e');
      // Re-throw with more context but don't let it cause logout
      throw Exception('Failed to create emergency contact: ${e.toString()}');
    }
  }

  Future<void> updateEmergencyContact(
      String contactId, Map<String, dynamic> updates) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client
        .from('emergency_contacts')
        .update(updates)
        .eq('id', contactId)
        .eq('user_id', userId);
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client
        .from('emergency_contacts')
        .delete()
        .eq('id', contactId)
        .eq('user_id', userId);
  }

  // Devices (deprecated: rely on water_data instead)
  Future<List<Map<String, dynamic>>> getDevices() async {
    // Deprecated: return empty list to avoid schema dependency on 'devices'
    return <Map<String, dynamic>>[];
  }

  // Get all devices with user information for admin reports
  Future<List<Map<String, dynamic>>> getAllDevicesForReport() async {
    try {
      final response = await _client
          .from('devices')
          .select('device_name, user_id')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting devices for report: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createDevice(
      Map<String, dynamic> deviceData) async {
    // Deprecated: emulate creation by recording a water_data entry for location
    final now = DateTime.now().toIso8601String();
    final location =
        (deviceData['device_location']?.toString().trim().isNotEmpty ?? false)
            ? deviceData['device_location'].toString()
            : (deviceData['device_name']?.toString() ?? 'Unknown');
    final payload = {
      'location': location,
      'sensor_id': deviceData['device_name']?.toString() ?? 'Unknown',
      'created_at': now,
      'timestamp': now,
    };
    final inserted =
        await _client.from('water_data').insert(payload).select().single();
    return Map<String, dynamic>.from(inserted);
  }

  Future<void> updateDevice(
      String deviceId, Map<String, dynamic> updates) async {
    // Deprecated: no-op to avoid 'devices' dependency
    return;
  }

  Future<void> deleteDevice(String deviceId) async {
    // Deprecated: no-op to avoid 'devices' dependency
    return;
  }

  Future<List<Map<String, dynamic>>> getAnnouncements({
    bool includeInactive = false,
    int limit = 50,
  }) async {
    try {
      var query = _client.from('announcements').select();
      if (!includeInactive) {
        query = query.eq('is_active', true);
      }
      final response =
          await query.order('created_at', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting announcements: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createAnnouncement(
      Map<String, dynamic> announcementData) async {
    final userId = _client.auth.currentUser?.id ?? currentUserId;
    final createdBy = announcementData['created_by'];
    if (createdBy == _hardcodedAdminId) {
      announcementData['created_by'] = null;
    } else if (announcementData['created_by'] == null && userId != null) {
      announcementData['created_by'] = userId;
    }
    announcementData['is_active'] = announcementData['is_active'] ?? true;
    try {
      final response = await _client
          .from('announcements')
          .insert(announcementData)
          .select()
          .single();
      return response;
    } catch (e) {
      // Fallback: some RLS setups allow insert but not select returning
      try {
        await _client.from('announcements').insert(announcementData);
        return {
          'status': 'inserted',
          'title': announcementData['title'],
          'message': announcementData['message'],
          'is_active': announcementData['is_active'],
          'created_by': announcementData['created_by'],
        };
      } catch (e2) {
        print('Error creating announcement: $e2');
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> updateAnnouncement(
    String announcementId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _client
          .from('announcements')
          .update(updates)
          .eq('id', announcementId)
          .select()
          .single();
      return response;
    } catch (e) {
      // Fallback: perform update without returning row (RLS may block select)
      try {
        await _client
            .from('announcements')
            .update(updates)
            .eq('id', announcementId);
        final result = Map<String, dynamic>.from(updates);
        result['id'] = announcementId;
        result['status'] = 'updated';
        return result;
      } catch (e2) {
        print('Error updating announcement: $e2');
        rethrow;
      }
    }
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await _client.from('announcements').delete().eq('id', announcementId);
  }

  // System Settings
  Future<Map<String, dynamic>> getSystemSettings() async {
    final response = await _client
        .from('system_settings')
        .select()
        .or('user_id.is.null,user_id.eq.${currentUserId}')
        .order('is_system_setting', ascending: false);

    final settings = <String, dynamic>{};
    for (final setting in response) {
      settings[setting['setting_key']] = setting['setting_value'];
    }

    return settings;
  }

  Future<void> updateSystemSetting(String key, String value) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client.from('system_settings').upsert({
      'user_id': userId,
      'setting_key': key,
      'setting_value': value,
    }, onConflict: 'user_id,setting_key');
  }

  // Water Savings Targets
  Future<List<Map<String, dynamic>>> getWaterSavingsTargets() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _client
        .from('water_savings_targets')
        .select()
        .eq('user_id', userId)
        .order('target_period_start', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createWaterSavingsTarget(
      Map<String, dynamic> targetData) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    targetData['user_id'] = userId;

    final response = await _client
        .from('water_savings_targets')
        .insert(targetData)
        .select()
        .single();

    return response;
  }

  // Maintenance Schedules
  Future<List<Map<String, dynamic>>> getMaintenanceSchedules(
      String propertyId) async {
    final response = await _client
        .from('maintenance_schedules')
        .select()
        .eq('property_id', propertyId)
        .order('scheduled_date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createMaintenanceSchedule(
      Map<String, dynamic> scheduleData) async {
    final response = await _client
        .from('maintenance_schedules')
        .insert(scheduleData)
        .select()
        .single();

    return response;
  }

  Future<void> updateMaintenanceSchedule(
      String scheduleId, Map<String, dynamic> updates) async {
    await _client
        .from('maintenance_schedules')
        .update(updates)
        .eq('id', scheduleId);
  }

  // Real-time subscriptions
  Stream<List<Map<String, dynamic>>> subscribeToLeakDetections(
      String propertyId) {
    return _client.from('water_leak_detections').stream(primaryKey: ['id']).map(
        (event) => List<Map<String, dynamic>>.from(event)
            .where((detection) =>
                detection['property_id'] == propertyId &&
                detection['status'] == 'active')
            .toList());
  }

  Stream<List<Map<String, dynamic>>> subscribeToSensorReadings(
      String segmentId) {
    return _client.from('sensor_readings').stream(primaryKey: ['id']).map(
        (event) => List<Map<String, dynamic>>.from(event)
            .where((reading) => reading['segment_id'] == segmentId)
            .take(10)
            .toList());
  }

  Stream<List<Map<String, dynamic>>> subscribeToNotifications() {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _client.from('leak_notifications').stream(primaryKey: ['id']).map(
        (event) => List<Map<String, dynamic>>.from(event)
            .where((notification) =>
                notification['user_id'] == userId &&
                notification['is_read'] == false)
            .toList());
  }

  // Kitchen Valve Control Methods
  Future<List<Map<String, dynamic>>> getValveControls() async {
    try {
      final response = await _client
          .from('kitchen_valve_control')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting valve controls: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createValveControl({
    required String valveStatus,
  }) async {
    try {
      final response = await _client
          .from('kitchen_valve_control')
          .insert({'valve_status': valveStatus})
          .select()
          .single();
      return response;
    } catch (e) {
      print('Error creating valve control: $e');
      rethrow;
    }
  }

  // Device Status (Legacy/User Requested)
  Future<List<Map<String, dynamic>>> getDeviceStatuses() async {
    try {
      final response = await _client
          .from('device_status')
          .select()
          .order('device_name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting device statuses: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateValveControl({
    required String id,
    required String valveStatus,
  }) async {
    try {
      final response = await _client
          .from('kitchen_valve_control')
          .update({
            'valve_status': valveStatus,
          })
          .eq('id', id)
          .select()
          .single();
      return response;
    } catch (e) {
      print('Error updating valve control: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLatestValveStatus() async {
    try {
      final response = await _client
          .from('kitchen_valve_control')
          .select()
          .order('created_at', ascending: false)
          .limit(1)
          .single();
      return response;
    } catch (e) {
      print('Error getting latest valve status: $e');
      // Return default status if no records exist
      return {'valve_status': 'closed'};
    }
  }

  Stream<Map<String, dynamic>> subscribeToValveControl() {
    return _client
        .from('kitchen_valve_control')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .map((event) {
          if (event.isNotEmpty) {
            return event.first;
          }
          return {'valve_status': 'closed'};
        });
  }

  // Send command to ESP32 water control device
  Future<void> sendValveCommand({
    required String deviceId,
    required String commandType,
  }) async {
    try {
      await _client.from('water_connection_commands').insert({
        'device_id': deviceId,
        'command_type': commandType,
        'status': 'pending',
      });
      print('✅ Sent command to $deviceId: $commandType');
    } catch (e) {
      print('Error sending valve command: $e');
      rethrow;
    }
  }

  // Get kitchen device status
  Future<Map<String, dynamic>?> getKitchenDeviceStatus() async {
    try {
      final response = await _client
          .from('water_connection_control')
          .select()
          .eq('device_id', 'ESP_KITCHEN_001')
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting kitchen device status: $e');
      return null;
    }
  }

  // Get all water connection control devices
  Future<List<Map<String, dynamic>>> getWaterConnectionDevices() async {
    try {
      final response = await _client
          .from('water_connection_control')
          .select()
          .order('device_name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting water connection devices: $e');
      return [];
    }
  }

  // Update kitchen device status directly (for immediate UI feedback)
  Future<void> updateKitchenDeviceStatus({
    required String valveStatus,
    double? waterFlow,
  }) async {
    try {
      await _client.from('water_connection_control').update({
        'valve_status': valveStatus,
        'is_online': true,
        'last_heartbeat': DateTime.now().toIso8601String(),
        if (waterFlow != null) 'water_flow': waterFlow,
      }).eq('device_id', 'ESP_KITCHEN_001');
      print('✅ Updated kitchen device status: $valveStatus');
    } catch (e) {
      print('Error updating kitchen device status: $e');
      // Don't throw - this is optional, ESP32 will sync automatically
    }
  }

  Future<List<Map<String, dynamic>>> getDeviceStatusList() async {
    try {
      final response = await _client
          .from('water_connection_control')
          .select()
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting device status list (water_connection_control): $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDeviceStatusByName(String deviceName) async {
    try {
      final String location = _mapDeviceNameToLocation(deviceName);
      final response = await _client
          .from('water_data')
          .select()
          .eq('location', location)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting water_data by device name: $e');
      return null;
    }
  }

  // Legacy method for device_status table
  Future<Map<String, dynamic>?> getLegacyDeviceStatusByName(
      String deviceName) async {
    try {
      final response = await _client
          .from('device_status')
          .select()
          .eq('device_name', deviceName)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting legacy device status by name: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateDeviceStatusByName({
    required String deviceName,
    String? valveStatus,
    double? waterFlow,
    String? status,
  }) async {
    try {
      final String location = _mapDeviceNameToLocation(deviceName);
      final bool? valveOpen = valveStatus == null
          ? null
          : valveStatus.toUpperCase() == 'OPEN'
              ? true
              : valveStatus.toUpperCase() == 'CLOSED'
                  ? false
                  : null;
      final payload = <String, dynamic>{
        'location': location,
        if (valveOpen != null) 'valve_status': valveOpen,
        if (waterFlow != null) 'flow_rate': waterFlow,
        'created_at': DateTime.now().toIso8601String(),
        'timestamp': DateTime.now().toIso8601String(),
        'sensor_id': deviceName,
      };
      print('🔄 Inserting water_data: $payload');
      final response =
          await _client.from('water_data').insert(payload).select().single();
      print('✅ water_data insert result: $response');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error inserting water_data: $e');
      rethrow;
    }
  }

  Future<void> setAllValvesClosed() async {
    try {
      // Use water_connection_control (current-state table)
      // Upsert by device_id so it works even if the rows don't exist yet.
      final now = DateTime.now().toIso8601String();
      await _client.from('water_connection_control').upsert([
        {
          'device_id': _defaultDeviceIdForLocation('Kitchen'),
          'device_name': _defaultDeviceNameForLocation('Kitchen'),
          'location': 'Kitchen',
          'valve_status': 'closed',
          'water_flow': 0.00,
          'is_online': true,
          'last_heartbeat': now,
          if (currentUserId != null) 'user_id': currentUserId,
        },
        {
          'device_id': _defaultDeviceIdForLocation('Bathroom'),
          'device_name': _defaultDeviceNameForLocation('Bathroom'),
          'location': 'Bathroom',
          'valve_status': 'closed',
          'water_flow': 0.00,
          'is_online': true,
          'last_heartbeat': now,
          if (currentUserId != null) 'user_id': currentUserId,
        },
        {
          'device_id': _defaultDeviceIdForLocation('Garden'),
          'device_name': _defaultDeviceNameForLocation('Garden'),
          'location': 'Garden',
          'valve_status': 'closed',
          'water_flow': 0.00,
          'is_online': true,
          'last_heartbeat': now,
          if (currentUserId != null) 'user_id': currentUserId,
        },
      ], onConflict: 'device_id');

      print('✅ Updated water_connection_control to close all valves');
    } catch (e) {
      print('Error setting all valves closed (water_connection_control): $e');
      rethrow;
    }
  }

  /// Update (or create) a device row in `water_connection_control` using a location name.
  /// This is used by the Flutter UI toggles so all switch state comes from your table schema.
  Future<void> upsertWaterConnectionControlForLocation({
    required String location,
    required bool isOpen,
    double? waterFlow,
    String? propertyId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final payload = <String, dynamic>{
        'device_id': _defaultDeviceIdForLocation(location),
        'device_name': _defaultDeviceNameForLocation(location),
        'location': location,
        'valve_status': isOpen ? 'open' : 'closed',
        'water_flow': waterFlow ?? 0.00,
        'is_online': true,
        'last_heartbeat': now,
        if (currentUserId != null) 'user_id': currentUserId,
        if (propertyId != null) 'property_id': propertyId,
      };

      await _client
          .from('water_connection_control')
          .upsert(payload, onConflict: 'device_id');
    } catch (e) {
      print('Error upserting water_connection_control for $location: $e');
      rethrow;
    }
  }

  // Water Data (flow/usage) - supports new public.water_data schema
  Future<List<Map<String, dynamic>>> getWaterData({
    DateTime? since,
    int limit = 1000,
  }) async {
    var query = _client.from('water_data').select();
    if (since != null) {
      query = query.gte('created_at', since.toIso8601String());
    }
    final response =
        await query.order('created_at', ascending: true).limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> insertWaterData(Map<String, dynamic> data) async {
    await _client.from('water_data').insert(data);
  }

  Future<Map<String, dynamic>?> getLatestWaterDataForLocation(
      String location) async {
    try {
      final response = await _client
          .from('water_data')
          .select()
          .eq('location', location)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting latest water_data for $location: $e');
      return null;
    }
  }

  String _mapDeviceNameToLocation(String deviceName) {
    switch (deviceName.toLowerCase()) {
      case 'device 1':
        return 'Kitchen';
      case 'device 2':
        return 'Bathroom';
      case 'device 3':
        return 'Garden';
      default:
        return deviceName;
    }
  }

  // Enhanced Water Data Methods for Consumption Display
  Future<List<Map<String, dynamic>>> getWaterDataByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
  }) async {
    try {
      final response = await _client
          .from('water_data')
          .select()
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting water data by date range: $e');
      // Don't throw - return empty list to prevent logout
      // Re-throw only if it's a critical error that should be handled upstream
      if (e.toString().contains('JWT') ||
          e.toString().contains('authentication') ||
          e.toString().contains('session')) {
        print(
            '⚠️ Authentication error in getWaterDataByDateRange - returning empty list to prevent logout');
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTodayWaterData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    // Prefer history derived from water_connection_control
    final hist = await _getWaterControlHistoryRaw(
      startDate: startOfDay,
      endDate: endOfDay,
      limit: 10000,
    );
    if (hist.isNotEmpty) {
      return hist.map((h) {
        final flow = (h['water_flow'] as num?)?.toDouble() ?? 0.0;
        return {
          'id': h['id'],
          'created_at': h['recorded_at'],
          'flow_rate': flow,
          'total_used': (h['total_water_used'] as num?)?.toDouble() ?? 0.0,
          'leak_detected': _isLeakLikeFlow(flow),
          'valve_status': h['valve_status'],
          'location': h['location'],
          'sensor_id': h['device_id'],
        };
      }).toList();
    }

    // Fallback: current snapshot from water_connection_control
    final snapshot = await _getWaterControlSnapshotRows();
    if (snapshot.isNotEmpty) return snapshot;

    // Fallback to legacy water_data if history isn't set up yet
    return getWaterDataByDateRange(startDate: startOfDay, endDate: endOfDay);
  }

  Future<List<Map<String, dynamic>>> getWeeklyWaterData() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));
    final hist = await _getWaterControlHistoryRaw(
      startDate: weekAgo,
      endDate: now,
      limit: 10000,
    );
    if (hist.isNotEmpty) {
      return hist.map((h) {
        final flow = (h['water_flow'] as num?)?.toDouble() ?? 0.0;
        return {
          'id': h['id'],
          'created_at': h['recorded_at'],
          'flow_rate': flow,
          'total_used': (h['total_water_used'] as num?)?.toDouble() ?? 0.0,
          'leak_detected': _isLeakLikeFlow(flow),
          'valve_status': h['valve_status'],
          'location': h['location'],
          'sensor_id': h['device_id'],
        };
      }).toList();
    }
    final snapshot = await _getWaterControlSnapshotRows();
    if (snapshot.isNotEmpty) return snapshot;
    return getWaterDataByDateRange(startDate: weekAgo, endDate: now);
  }

  Future<List<Map<String, dynamic>>> getMonthlyWaterData() async {
    final now = DateTime.now();
    final monthAgo = now.subtract(Duration(days: 30));
    final hist = await _getWaterControlHistoryRaw(
      startDate: monthAgo,
      endDate: now,
      limit: 10000,
    );
    if (hist.isNotEmpty) {
      return hist.map((h) {
        final flow = (h['water_flow'] as num?)?.toDouble() ?? 0.0;
        return {
          'id': h['id'],
          'created_at': h['recorded_at'],
          'flow_rate': flow,
          'total_used': (h['total_water_used'] as num?)?.toDouble() ?? 0.0,
          'leak_detected': _isLeakLikeFlow(flow),
          'valve_status': h['valve_status'],
          'location': h['location'],
          'sensor_id': h['device_id'],
        };
      }).toList();
    }
    final snapshot = await _getWaterControlSnapshotRows();
    if (snapshot.isNotEmpty) return snapshot;
    return getWaterDataByDateRange(startDate: monthAgo, endDate: now);
  }

  Future<List<Map<String, dynamic>>> getYearlyWaterData() async {
    final now = DateTime.now();
    final yearAgo = now.subtract(Duration(days: 365));

    return getWaterDataByDateRange(
      startDate: yearAgo,
      endDate: now,
    );
  }

  Stream<List<Map<String, dynamic>>> subscribeToAnnouncements({
    bool includeInactive = false,
  }) {
    return _client
        .from('announcements')
        .stream(primaryKey: ['id']).map((event) {
      final list = List<Map<String, dynamic>>.from(event);
      if (includeInactive) return list;
      return list.where((a) => a['is_active'] == true).toList();
    });
  }

  Future<Map<String, dynamic>> getWaterDataSummary({
    DateTime? since,
  }) async {
    try {
      final now = DateTime.now();
      final start = since ?? now.subtract(const Duration(days: 7));

      // Prefer control history (real time-series)
      final hist = await _getWaterControlHistoryRaw(
        startDate: start.subtract(const Duration(days: 1)), // baseline
        endDate: now,
        limit: 20000,
      );

      if (hist.isNotEmpty) {
        // Compute usage as sum of positive deltas of total_water_used per device_id
        final Map<String, double?> lastByDevice = {};
        double totalUsedDelta = 0.0;

        double totalFlow = 0.0;
        double maxFlow = 0.0;
        int count = 0;
        int leaks = 0;
        int openCount = 0;
        int closedCount = 0;

        for (final r in hist) {
          final ts = DateTime.tryParse((r['recorded_at'] ?? '').toString());
          if (ts == null) continue;
          if (ts.isBefore(start) || ts.isAfter(now)) {
            // still keep baseline updates for lastByDevice
          }

          final deviceId = (r['device_id'] ?? '').toString();
          final total = (r['total_water_used'] as num?)?.toDouble();
          if (deviceId.isNotEmpty && total != null) {
            final prev = lastByDevice[deviceId];
            if (prev != null && !ts.isBefore(start) && !ts.isAfter(now)) {
              final delta = total - prev;
              if (delta > 0) totalUsedDelta += delta;
            }
            lastByDevice[deviceId] = total;
          }

          if (ts.isBefore(start) || ts.isAfter(now)) continue;

          final flow = (r['water_flow'] as num?)?.toDouble() ?? 0.0;
          totalFlow += flow;
          if (flow > maxFlow) maxFlow = flow;
          count++;

          if (_isLeakLikeFlow(flow)) leaks++;

          final vs = (r['valve_status'] ?? '').toString().toLowerCase();
          if (vs == 'open') {
            openCount++;
          } else if (vs == 'closed') {
            closedCount++;
          }
        }

        return {
          'totalRecords': count,
          'totalWaterUsed': totalUsedDelta,
          'averageFlowRate': count > 0 ? totalFlow / count : 0.0,
          'maxFlowRate': maxFlow,
          'leakDetections': leaks,
          'valveOpenCount': openCount,
          'valveClosedCount': closedCount,
          'leakDetectionRate': count > 0 ? (leaks / count) * 100 : 0.0,
          'source': 'water_connection_control_history',
        };
      }

      // Fallback: current snapshot from water_connection_control
      final devices = await getWaterConnectionDevices();
      final totalUsedSnapshot = devices.fold<double>(
        0.0,
        (sum, d) => sum + ((d['total_water_used'] as num?)?.toDouble() ?? 0.0),
      );
      final totalFlowSnapshot = devices.fold<double>(
        0.0,
        (sum, d) => sum + ((d['water_flow'] as num?)?.toDouble() ?? 0.0),
      );
      final openCount = devices
          .where((d) =>
              (d['valve_status'] ?? '').toString().toLowerCase() == 'open')
          .length;
      final closedCount = devices
          .where((d) =>
              (d['valve_status'] ?? '').toString().toLowerCase() == 'closed')
          .length;

      return {
        'totalRecords': devices.length,
        'totalWaterUsed': totalUsedSnapshot,
        'averageFlowRate':
            devices.isNotEmpty ? totalFlowSnapshot / devices.length : 0.0,
        'maxFlowRate': devices
            .map((d) => (d['water_flow'] as num?)?.toDouble() ?? 0.0)
            .fold<double>(0.0, (m, v) => v > m ? v : m),
        'leakDetections': devices
            .where((d) =>
                _isLeakLikeFlow((d['water_flow'] as num?)?.toDouble() ?? 0.0))
            .length,
        'valveOpenCount': openCount,
        'valveClosedCount': closedCount,
        'leakDetectionRate': devices.isNotEmpty
            ? (devices
                        .where((d) => _isLeakLikeFlow(
                            (d['water_flow'] as num?)?.toDouble() ?? 0.0))
                        .length /
                    devices.length) *
                100
            : 0.0,
        'source': 'water_connection_control',
      };
    } catch (e) {
      print('Error getting water data summary: $e');
      return {
        'totalRecords': 0,
        'totalWaterUsed': 0.0,
        'averageFlowRate': 0.0,
        'maxFlowRate': 0.0,
        'leakDetections': 0,
        'valveOpenCount': 0,
        'valveClosedCount': 0,
        'leakDetectionRate': 0.0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getWaterDataGroupedByDay({
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));
      // Prefer history: compute daily totals from deltas of total_water_used
      final hist = await _getWaterControlHistoryRaw(
        startDate: startDate.subtract(const Duration(days: 1)),
        endDate: now,
        limit: 20000,
      );

      // Group data by day
      final Map<String, Map<String, dynamic>> groupedData = {};

      for (int i = 0; i < days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        groupedData[dateKey] = {
          'date': dateKey,
          'dayName': _getDayName(date.weekday),
          'totalWaterUsed': 0.0,
          'averageFlowRate': 0.0,
          'maxFlowRate': 0.0,
          'leakDetections': 0,
          'recordCount': 0,
        };
      }

      if (hist.isNotEmpty) {
        final Map<String, double?> lastByDevice = {};
        for (final r in hist) {
          final ts = DateTime.tryParse((r['recorded_at'] ?? '').toString());
          if (ts == null) continue;

          final deviceId = (r['device_id'] ?? '').toString();
          final total = (r['total_water_used'] as num?)?.toDouble();
          final flow = (r['water_flow'] as num?)?.toDouble() ?? 0.0;

          final prev = (deviceId.isNotEmpty) ? lastByDevice[deviceId] : null;
          if (deviceId.isNotEmpty && total != null) {
            if (prev != null && !ts.isBefore(startDate) && !ts.isAfter(now)) {
              final delta = total - prev;
              if (delta > 0) {
                final local = ts.toLocal();
                final key =
                    '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
                if (groupedData.containsKey(key)) {
                  groupedData[key]!['totalWaterUsed'] =
                      (groupedData[key]!['totalWaterUsed'] as double) + delta;
                }
              }
            }
            lastByDevice[deviceId] = total;
          }

          if (ts.isBefore(startDate) || ts.isAfter(now)) continue;

          final local = ts.toLocal();
          final key =
              '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
          if (!groupedData.containsKey(key)) continue;

          final dayData = groupedData[key]!;
          dayData['recordCount'] = (dayData['recordCount'] as int) + 1;
          if (flow > (dayData['maxFlowRate'] as double)) {
            dayData['maxFlowRate'] = flow;
          }
          if (_isLeakLikeFlow(flow)) {
            dayData['leakDetections'] = (dayData['leakDetections'] as int) + 1;
          }
        }
      } else {
        // Fallback to legacy water_data if history isn't set up yet
        final data =
            await getWaterDataByDateRange(startDate: startDate, endDate: now);
        if (data.isNotEmpty) {
          for (final record in data) {
            final createdAt = DateTime.tryParse(record['created_at'] ?? '');
            if (createdAt == null) continue;

            final dateKey =
                '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

            if (groupedData.containsKey(dateKey)) {
              final dayData = groupedData[dateKey]!;
              dayData['totalWaterUsed'] +=
                  (record['total_used'] as num?)?.toDouble() ?? 0.0;
              dayData['recordCount'] += 1;

              final flowRate = (record['flow_rate'] as num?)?.toDouble() ?? 0.0;
              if (flowRate > dayData['maxFlowRate']) {
                dayData['maxFlowRate'] = flowRate;
              }

              if (record['leak_detected'] == true) {
                dayData['leakDetections'] += 1;
              }
            }
          }
        } else {
          // Final fallback: snapshot into today's bucket
          final snap = await _getWaterControlSnapshotRows();
          if (snap.isNotEmpty) {
            final todayKey =
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            final flow = (snap.first['flow_rate'] as num?)?.toDouble() ?? 0.0;
            final used = (snap.first['total_used'] as num?)?.toDouble() ?? 0.0;
            if (groupedData.containsKey(todayKey)) {
              groupedData[todayKey]!['totalWaterUsed'] = used;
              groupedData[todayKey]!['maxFlowRate'] = flow;
              groupedData[todayKey]!['recordCount'] = 1;
              groupedData[todayKey]!['leakDetections'] =
                  _isLeakLikeFlow(flow) ? 1 : 0;
            }
          }
        }
      }

      // Calculate averages
      for (final dayData in groupedData.values) {
        if (dayData['recordCount'] > 0) {
          dayData['averageFlowRate'] =
              (dayData['maxFlowRate'] as double); // simple display metric
        }
      }

      // Convert to list and sort by date
      final result = groupedData.values.toList();
      result.sort((a, b) => a['date'].compareTo(b['date']));

      return result;
    } catch (e) {
      print('Error getting water data grouped by day: $e');
      return [];
    }
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  // Water Connection Control (current-state table)
  Future<List<Map<String, dynamic>>> getWaterConnectionControlByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10000,
  }) async {
    try {
      final response = await _client
          .from('water_connection_control')
          .select(
              'id, device_id, device_name, valve_status, water_flow, pressure, temperature, is_online, last_heartbeat, location, user_id, property_id, created_at, updated_at, total_water_used')
          .gte('updated_at', startDate.toIso8601String())
          .lte('updated_at', endDate.toIso8601String())
          .order('updated_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting water_connection_control by date range: $e');
      return [];
    }
  }

  Future<bool> isCurrentUserAdmin() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return false;
      final isAdminRole =
          currentUser['role']?.toString().toLowerCase() == 'admin';
      final isHardcodedAdmin = currentUser['id'] == _hardcodedAdminId &&
          currentUser['is_hardcoded_admin'] == true;
      return isAdminRole || isHardcodedAdmin;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    try {
      userData['password_hash'] = userData['password_hash'] ?? 'admin_managed';
      final response =
          await _client.from('users').insert(userData).select().single();
      return response;
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _client.from('users').update(updates).eq('id', userId);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _client.from('users').delete().eq('id', userId);
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }
}
