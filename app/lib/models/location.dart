class Location {
  final String address;

  const Location({required this.address});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(address: json['address'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'address': address};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Location && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() {
    return address;
  }
}
