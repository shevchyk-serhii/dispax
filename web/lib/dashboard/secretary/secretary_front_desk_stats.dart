import '../../modules/ride_management/models/ride.dart';

/// Pure helper computing the Front-desk stat-tile values from ride data.
/// Kept side-effect-free so the counting logic is unit-testable without
/// pumping the whole dashboard widget tree.
class SecretaryFrontDeskStats {
  /// Rides whose pickup is on [day] (defaults to today).
  static List<Ride> ridesOn(List<Ride> rides, {DateTime? day}) {
    final d = day ?? DateTime.now();
    return rides.where((r) {
      final p = r.pickupDateTime;
      return p.year == d.year && p.month == d.month && p.day == d.day;
    }).toList();
  }

  /// Number of rides booked for [day].
  static int bookedCount(List<Ride> rides, {DateTime? day}) =>
      ridesOn(rides, day: day).length;

  /// Number of [day]'s rides still awaiting confirmation (status Requested).
  static int awaitingConfirmCount(List<Ride> rides, {DateTime? day}) => ridesOn(
    rides,
    day: day,
  ).where((r) => r.status == RideStatus.requested).length;
}
