/// Result returned by POST /rides/estimate.
class RideEstimate {
  final double distanceKm;
  final int durationMinutes;
  final double estimatedPrice;
  final String currency;

  const RideEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    required this.estimatedPrice,
    required this.currency,
  });

  factory RideEstimate.fromJson(Map<String, dynamic> json) => RideEstimate(
    distanceKm: (json['distanceKm'] as num).toDouble(),
    durationMinutes: json['durationMinutes'] as int,
    estimatedPrice: (json['estimatedPrice'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'EUR',
  );
}
