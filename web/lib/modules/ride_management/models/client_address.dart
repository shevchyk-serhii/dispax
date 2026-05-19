class ClientAddress {
  final String id;
  final String clientId;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final int useCount;
  final List<String> aliases;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClientAddress({
    required this.id,
    required this.clientId,
    required this.label,
    required this.address,
    this.latitude,
    this.longitude,
    required this.useCount,
    this.aliases = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  static String _id(dynamic raw) =>
      raw is Map ? raw['value']?.toString() ?? '' : raw?.toString() ?? '';

  factory ClientAddress.fromJson(Map<String, dynamic> json) => ClientAddress(
        id: _id(json['id']),
        clientId: _id(json['clientId']),
        label: json['label'] as String,
        address: json['address'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        useCount: json['useCount'] as int? ?? 1,
        aliases: (json['aliases'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientId': clientId,
        'label': label,
        'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'useCount': useCount,
        'aliases': aliases,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
