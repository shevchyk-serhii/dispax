import '../../core/json_parse.dart';

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
    distanceKm: JsonParse.requiredDouble(json, 'distanceKm'),
    durationMinutes: JsonParse.requiredInt(json, 'durationMinutes'),
    estimatedPrice: JsonParse.requiredDouble(json, 'estimatedPrice'),
    currency: JsonParse.optionalString(json, 'currency') ?? 'EUR',
  );
}
