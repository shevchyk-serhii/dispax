/// Vehicle class offered for client bookings.
///
/// Wire values match the backend enum (lowercase): "business" | "van".
enum VehicleClass {
  business('business', 'Business · E-Class', 3, 2),
  van('van', 'Van · V-Class', 6, 5);

  const VehicleClass(this.wire, this.label, this.seats, this.bags);

  /// Wire string sent to and received from the backend.
  final String wire;

  /// Human-readable label for the booking UI.
  final String label;

  /// Maximum passenger seats.
  final int seats;

  /// Maximum bag capacity.
  final int bags;

  /// Seat + bag subtitle shown in vehicle-class rows.
  String get capacityLabel => '$seats seats · $bags bags';

  static VehicleClass fromWire(String? raw) {
    if (raw == null) return VehicleClass.business;
    return VehicleClass.values.firstWhere(
      (v) => v.wire == raw.toLowerCase(),
      orElse: () => VehicleClass.business,
    );
  }
}
