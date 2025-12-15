class Location {
  final String address;
  final double? latitude;
  final double? longitude;

  const Location({
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      address: json['address'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location &&
           other.address == address &&
           other.latitude == latitude &&
           other.longitude == longitude;
  }

  @override
  int get hashCode => address.hashCode ^ latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() {
    return address;
  }
}
