import '../../core/json_parse.dart';

enum ScheduleDayStatus {
  scheduled('Scheduled'),
  active('Active'),
  completed('Completed'),
  cancelled('Cancelled');

  const ScheduleDayStatus(this.value);
  final String value;

  String get displayName => value;

  static ScheduleDayStatus fromString(String value) {
    return ScheduleDayStatus.values.firstWhere(
      (status) => status.value.toLowerCase() == value.toLowerCase(),
      orElse: () => ScheduleDayStatus.scheduled,
    );
  }
}

class ScheduleDay {
  final String id;
  final String driverId;
  final String companyId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final ScheduleDayStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScheduleDay({
    required this.id,
    required this.driverId,
    required this.companyId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status = ScheduleDayStatus.scheduled,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScheduleDay.fromJson(Map<String, dynamic> json) {
    return ScheduleDay(
      id: json['id'] ?? '',
      driverId: json['driverId'] ?? '',
      companyId: json['companyId'] ?? '',
      date: JsonParse.requiredDateTime(json, 'date'),
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      status: ScheduleDayStatus.fromString(json['status'] ?? 'Scheduled'),
      notes: json['notes'],
      createdAt: JsonParse.requiredDateTime(json, 'createdAt'),
      updatedAt: JsonParse.requiredDateTime(json, 'updatedAt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'companyId': companyId,
      'date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'startTime': startTime,
      'endTime': endTime,
      'status': status.value,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ScheduleDay copyWith({
    String? id,
    String? driverId,
    String? companyId,
    DateTime? date,
    String? startTime,
    String? endTime,
    ScheduleDayStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleDay(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      companyId: companyId ?? this.companyId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleDay && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ScheduleDay(id: $id, driverId: $driverId, date: $date, startTime: $startTime, endTime: $endTime, status: ${status.value})';
  }
}
