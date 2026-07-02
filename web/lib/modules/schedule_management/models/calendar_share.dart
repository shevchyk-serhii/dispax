// Models for cross-company personal calendar sharing
// (see backend `CalendarShareApi`: /api/calendar-shares/*).

class CalendarShareInvite {
  final String id;
  final String code;
  final DateTime createdAt;
  final DateTime expiresAt;

  const CalendarShareInvite({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.expiresAt,
  });

  factory CalendarShareInvite.fromJson(Map<String, dynamic> json) {
    return CalendarShareInvite(
      id: json['id'] as String,
      code: json['code'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class CalendarShareGrant {
  final String id;
  final String grantorName;
  final String grantorCompanyName;
  final String granteeName;
  final String granteeCompanyName;
  final DateTime createdAt;

  const CalendarShareGrant({
    required this.id,
    required this.grantorName,
    required this.grantorCompanyName,
    required this.granteeName,
    required this.granteeCompanyName,
    required this.createdAt,
  });

  factory CalendarShareGrant.fromJson(Map<String, dynamic> json) {
    return CalendarShareGrant(
      id: json['id'] as String,
      grantorName: json['grantorName'] as String? ?? '',
      grantorCompanyName: json['grantorCompanyName'] as String? ?? '',
      granteeName: json['granteeName'] as String? ?? '',
      granteeCompanyName: json['granteeCompanyName'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// A shift of the shared (grantor's) calendar: date + times + status only.
class SharedShift {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String status;

  const SharedShift({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory SharedShift.fromJson(Map<String, dynamic> json) {
    return SharedShift(
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }
}

/// A busy interval of the shared calendar. `kind` is "Ride" or "Unavailability".
class SharedBusySlot {
  final DateTime start;
  final DateTime end;
  final String kind;

  const SharedBusySlot({
    required this.start,
    required this.end,
    required this.kind,
  });

  factory SharedBusySlot.fromJson(Map<String, dynamic> json) {
    return SharedBusySlot(
      start: DateTime.parse(json['start'] as String).toLocal(),
      end: DateTime.parse(json['end'] as String).toLocal(),
      kind: json['kind'] as String? ?? 'Ride',
    );
  }
}

class SharedCalendar {
  final String grantId;
  final String grantorName;
  final List<SharedShift> shifts;
  final List<SharedBusySlot> busySlots;

  const SharedCalendar({
    required this.grantId,
    required this.grantorName,
    required this.shifts,
    required this.busySlots,
  });

  factory SharedCalendar.fromJson(Map<String, dynamic> json) {
    return SharedCalendar(
      grantId: json['grantId'] as String,
      grantorName: json['grantorName'] as String? ?? '',
      shifts: (json['shifts'] as List<dynamic>? ?? [])
          .map((j) => SharedShift.fromJson(j as Map<String, dynamic>))
          .toList(),
      busySlots: (json['busySlots'] as List<dynamic>? ?? [])
          .map((j) => SharedBusySlot.fromJson(j as Map<String, dynamic>))
          .toList(),
    );
  }
}
