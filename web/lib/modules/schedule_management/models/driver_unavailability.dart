enum DriverUnavailabilityReason {
  lunch('Lunch'),
  vacation('Vacation'),
  personal('Personal');

  const DriverUnavailabilityReason(this.value);
  final String value;

  String get displayName => value;

  static DriverUnavailabilityReason fromString(String value) {
    return DriverUnavailabilityReason.values.firstWhere(
      (r) => r.value.toLowerCase() == value.toLowerCase(),
      orElse: () => DriverUnavailabilityReason.personal,
    );
  }
}

class DriverUnavailability {
  final String id;
  final String driverId;
  final String companyId;
  final DateTime fromTime;
  final DateTime toTime;
  final DriverUnavailabilityReason reason;
  final String? note;
  final DateTime createdAt;

  const DriverUnavailability({
    required this.id,
    required this.driverId,
    required this.companyId,
    required this.fromTime,
    required this.toTime,
    required this.reason,
    this.note,
    required this.createdAt,
  });

  factory DriverUnavailability.fromJson(Map<String, dynamic> json) {
    return DriverUnavailability(
      id: json['id'] ?? '',
      driverId: json['driverId'] ?? '',
      companyId: json['companyId'] ?? '',
      fromTime: DateTime.parse(json['fromTime']),
      toTime: DateTime.parse(json['toTime']),
      reason: DriverUnavailabilityReason.fromString(
        json['reason'] ?? 'Personal',
      ),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'companyId': companyId,
      'fromTime': fromTime.toUtc().toIso8601String(),
      'toTime': toTime.toUtc().toIso8601String(),
      'reason': reason.value,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DriverUnavailability && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DriverUnavailability(id: $id, driverId: $driverId, reason: ${reason.value}, from: $fromTime, to: $toTime)';
  }
}
