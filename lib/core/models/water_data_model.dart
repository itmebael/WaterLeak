class WaterDataModel {
  final String id;
  final DateTime createdAt;
  final double? flowRate;
  final double? totalUsed;
  final bool? leakDetected;
  final bool? valveStatus;

  WaterDataModel({
    required this.id,
    required this.createdAt,
    this.flowRate,
    this.totalUsed,
    this.leakDetected,
    this.valveStatus,
  });

  factory WaterDataModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawValveStatus = map['valve_status'];
    bool? parsedValveStatus;
    if (rawValveStatus is bool) {
      parsedValveStatus = rawValveStatus;
    } else if (rawValveStatus != null) {
      final s = rawValveStatus.toString().toLowerCase();
      if (s == 'open' || s == 'true' || s == '1') {
        parsedValveStatus = true;
      } else if (s == 'closed' || s == 'false' || s == '0') {
        parsedValveStatus = false;
      }
    }

    return WaterDataModel(
      id: map['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      flowRate: (map['flow_rate'] as num?)?.toDouble(),
      totalUsed: (map['total_used'] as num?)?.toDouble(),
      leakDetected: map['leak_detected'] as bool?,
      valveStatus: parsedValveStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'flow_rate': flowRate,
      'total_used': totalUsed,
      'leak_detected': leakDetected,
      'valve_status': valveStatus,
    };
  }

  // Formatted getters for display
  String get formattedCreatedAt {
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get formattedFlowRate {
    return flowRate != null ? '${flowRate!.toStringAsFixed(2)} L/min' : 'N/A';
  }

  String get formattedTotalUsed {
    return totalUsed != null ? '${totalUsed!.toStringAsFixed(1)} L' : 'N/A';
  }

  String get leakStatusText {
    if (leakDetected == true) {
      return 'LEAK';
    } else if (leakDetected == false) {
      return 'OK';
    } else {
      return 'UNKNOWN';
    }
  }

  String get valveStatusText {
    if (valveStatus == true) return 'OPEN';
    if (valveStatus == false) return 'CLOSED';
    return 'UNKNOWN';
  }

  // Color getters for UI
  bool get hasLeak => leakDetected == true;
  bool get isValveOpen => valveStatus == true;
  bool get isValveClosed => valveStatus == false;
}
