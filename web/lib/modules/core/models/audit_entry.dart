class AuditEntry {
  final String id;
  final String companyId;
  final String actorId;
  final String action;
  final String entityType;
  final String entityId;
  final String? oldValue;
  final String? newValue;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.companyId,
    required this.actorId,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValue,
    this.newValue,
    this.metadata,
    required this.createdAt,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] ?? '',
      companyId: json['companyId'] ?? '',
      actorId: json['actorId'] ?? '',
      action: json['action'] ?? '',
      entityType: json['entityType'] ?? '',
      entityId: json['entityId'] ?? '',
      oldValue: json['oldValue'],
      newValue: json['newValue'],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'actorId': actorId,
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'oldValue': oldValue,
      'newValue': newValue,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
