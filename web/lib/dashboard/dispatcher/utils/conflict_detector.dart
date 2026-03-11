import '../../../modules/ride_management/models/ride.dart';

class ConflictDetector {
  static const _overlapWindowMinutes = 60;

  static bool hasTimeConflict(Ride newRide, List<Ride> driverRides) {
    return findConflicts(newRide, driverRides).isNotEmpty;
  }

  static List<Ride> findConflicts(Ride newRide, List<Ride> driverRides) {
    final newStart = newRide.pickupDateTime;
    final newEnd = newStart.add(const Duration(minutes: _overlapWindowMinutes));

    return driverRides.where((existing) {
      if (existing.status == RideStatus.cancelled ||
          existing.status == RideStatus.completed) {
        return false;
      }

      final existingStart = existing.pickupDateTime;
      final existingEnd = existingStart.add(const Duration(minutes: _overlapWindowMinutes));

      return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
    }).toList();
  }
}
