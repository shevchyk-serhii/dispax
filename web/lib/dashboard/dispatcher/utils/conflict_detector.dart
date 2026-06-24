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
      // Never report the ride being assigned as a conflict with itself.
      // Mirrors the backend check in RideService.checkScheduleConflict
      // (`r.id != candidateRide.id`).
      if (existing.id == newRide.id) {
        return false;
      }

      // Only active rides count as conflicts, matching the backend set
      // (Assigned | Confirmed | InProgress).
      if (existing.status != RideStatus.assigned &&
          existing.status != RideStatus.confirmed &&
          existing.status != RideStatus.inProgress) {
        return false;
      }

      final existingStart = existing.pickupDateTime;
      final existingEnd = existingStart.add(
        const Duration(minutes: _overlapWindowMinutes),
      );

      return newStart.isBefore(existingEnd) && newEnd.isAfter(existingStart);
    }).toList();
  }
}
