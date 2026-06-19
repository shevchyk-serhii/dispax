import '../json_parse.dart';

class RideRating {
  final String id;
  final String rideId;
  final String clientId;
  final String driverId;
  final String companyId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const RideRating({
    required this.id,
    required this.rideId,
    required this.clientId,
    required this.driverId,
    required this.companyId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory RideRating.fromJson(Map<String, dynamic> json) {
    return RideRating(
      id: json['id'] ?? '',
      rideId: json['rideId'] ?? '',
      clientId: json['clientId'] ?? '',
      driverId: json['driverId'] ?? '',
      companyId: json['companyId'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'],
      createdAt: JsonParse.requiredDateTime(json, 'createdAt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rideId': rideId,
      'clientId': clientId,
      'driverId': driverId,
      'companyId': companyId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
