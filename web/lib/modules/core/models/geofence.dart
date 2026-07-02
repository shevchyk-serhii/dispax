import '../json_parse.dart';

class Geofence {
  final String id;
  final String companyId;
  final String name;
  final String geofenceType;
  final double centerLatitude;
  final double centerLongitude;
  final int radiusMeters;
  final bool isActive;
  final bool notifyOnEntry;
  final bool notifyOnExit;
  final DateTime createdAt;

  const Geofence({
    required this.id,
    required this.companyId,
    required this.name,
    required this.geofenceType,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    required this.isActive,
    required this.notifyOnEntry,
    required this.notifyOnExit,
    required this.createdAt,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) {
    return Geofence(
      id: json['id'] ?? '',
      companyId: json['companyId'] ?? '',
      name: json['name'] ?? '',
      geofenceType: json['geofenceType'] ?? 'CustomZone',
      centerLatitude: (json['centerLatitude'] ?? 0).toDouble(),
      centerLongitude: (json['centerLongitude'] ?? 0).toDouble(),
      radiusMeters: json['radiusMeters'] ?? 500,
      isActive: json['isActive'] ?? true,
      notifyOnEntry: json['notifyOnEntry'] ?? true,
      notifyOnExit: json['notifyOnExit'] ?? false,
      createdAt:
          JsonParse.optionalDateTime(json, 'createdAt') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name,
      'geofenceType': geofenceType,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'notifyOnEntry': notifyOnEntry,
      'notifyOnExit': notifyOnExit,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class CreateGeofenceRequest {
  final String name;
  final String geofenceType;
  final double centerLatitude;
  final double centerLongitude;
  final int radiusMeters;
  final bool notifyOnEntry;
  final bool notifyOnExit;

  const CreateGeofenceRequest({
    required this.name,
    required this.geofenceType,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    required this.notifyOnEntry,
    required this.notifyOnExit,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'geofenceType': geofenceType,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusMeters': radiusMeters,
      'notifyOnEntry': notifyOnEntry,
      'notifyOnExit': notifyOnExit,
    };
  }
}

class GeofenceAlert {
  final String id;
  final String geofenceId;
  final String driverId;

  /// Resolved display name of the driver; null when the backend could not
  /// resolve it (person deleted). Fall back to a shortened [driverId] then.
  final String? driverName;
  final String companyId;
  final String alertType;
  final String geofenceName;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const GeofenceAlert({
    required this.id,
    required this.geofenceId,
    required this.driverId,
    this.driverName,
    required this.companyId,
    required this.alertType,
    required this.geofenceName,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory GeofenceAlert.fromJson(Map<String, dynamic> json) {
    return GeofenceAlert(
      id: json['id'] ?? '',
      geofenceId: json['geofenceId'] ?? '',
      driverId: json['driverId'] ?? '',
      driverName: json['driverName'] as String?,
      companyId: json['companyId'] ?? '',
      alertType: json['alertType'] ?? 'entry',
      geofenceName: json['geofenceName'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      createdAt:
          JsonParse.optionalDateTime(json, 'createdAt') ?? DateTime.now(),
    );
  }
}
