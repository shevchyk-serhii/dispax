class RideTemplate {
  final String id;
  final String companyId;
  final String clientId;
  final String creatorId;
  final String name;
  final String fromAddress;
  final double? fromLat;
  final double? fromLng;
  final String toAddress;
  final double? toLat;
  final double? toLng;
  final String? preferredDriverId;
  final String? notes;
  final String? flightNumber;
  final String recurrencePattern;
  final String? recurrenceDays;
  final String pickupTime;
  final bool isActive;
  final bool isAirportTransfer;
  final double? price;

  const RideTemplate({
    required this.id,
    required this.companyId,
    required this.clientId,
    required this.creatorId,
    required this.name,
    required this.fromAddress,
    this.fromLat,
    this.fromLng,
    required this.toAddress,
    this.toLat,
    this.toLng,
    this.preferredDriverId,
    this.notes,
    this.flightNumber,
    required this.recurrencePattern,
    this.recurrenceDays,
    required this.pickupTime,
    this.isActive = true,
    this.isAirportTransfer = false,
    this.price,
  });

  factory RideTemplate.fromJson(Map<String, dynamic> json) {
    return RideTemplate(
      id: json['id'] ?? '',
      companyId: json['companyId'] ?? '',
      clientId: json['clientId'] ?? '',
      creatorId: json['creatorId'] ?? '',
      name: json['name'] ?? '',
      fromAddress: json['fromAddress'] ?? '',
      fromLat: json['fromLat']?.toDouble(),
      fromLng: json['fromLng']?.toDouble(),
      toAddress: json['toAddress'] ?? '',
      toLat: json['toLat']?.toDouble(),
      toLng: json['toLng']?.toDouble(),
      preferredDriverId: json['preferredDriverId'],
      notes: json['notes'],
      flightNumber: json['flightNumber'],
      recurrencePattern: json['recurrencePattern'] ?? 'Daily',
      recurrenceDays: json['recurrenceDays'],
      pickupTime: json['pickupTime'] ?? '08:00',
      isActive: json['isActive'] ?? true,
      isAirportTransfer: json['isAirportTransfer'] ?? false,
      price: json['price']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'clientId': clientId,
      'creatorId': creatorId,
      'name': name,
      'fromAddress': fromAddress,
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toAddress': toAddress,
      'toLat': toLat,
      'toLng': toLng,
      'preferredDriverId': preferredDriverId,
      'notes': notes,
      'flightNumber': flightNumber,
      'recurrencePattern': recurrencePattern,
      'recurrenceDays': recurrenceDays,
      'pickupTime': pickupTime,
      'isActive': isActive,
      'isAirportTransfer': isAirportTransfer,
      'price': price,
    };
  }
}

class CreateRideTemplateRequest {
  final String name;
  final String clientId;
  final String fromAddress;
  final String toAddress;
  final String pickupTime;
  final String recurrencePattern;
  final String? recurrenceDays;
  final String? preferredDriverId;
  final String? notes;
  final String? flightNumber;
  final bool isAirportTransfer;
  final double? price;

  const CreateRideTemplateRequest({
    required this.name,
    required this.clientId,
    required this.fromAddress,
    required this.toAddress,
    required this.pickupTime,
    required this.recurrencePattern,
    this.recurrenceDays,
    this.preferredDriverId,
    this.notes,
    this.flightNumber,
    this.isAirportTransfer = false,
    this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'clientId': clientId,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'pickupTime': pickupTime,
      'recurrencePattern': recurrencePattern,
      'recurrenceDays': recurrenceDays,
      'preferredDriverId': preferredDriverId,
      'notes': notes,
      'flightNumber': flightNumber,
      'isAirportTransfer': isAirportTransfer,
      'price': price,
    };
  }
}
