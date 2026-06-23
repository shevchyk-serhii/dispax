import 'package:equatable/equatable.dart';
import '../../modules/core/models/person.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/models/create_ride_request.dart';

abstract class RideEvent extends Equatable {
  const RideEvent();

  @override
  List<Object?> get props => [];
}

class RideLoadRequested extends RideEvent {
  final Person user;

  const RideLoadRequested({required this.user});

  @override
  List<Object> get props => [user];
}

class RideRefreshRequested extends RideEvent {
  final Person user;

  const RideRefreshRequested({required this.user});

  @override
  List<Object> get props => [user];
}

// NOTE: RideDeleteRequested removed — backend does not support DELETE /rides/:id
// class RideDeleteRequested extends RideEvent {
//   final String rideId;
//   const RideDeleteRequested({required this.rideId});
//   @override
//   List<Object> get props => [rideId];
// }

class RideAdded extends RideEvent {
  final Ride ride;

  const RideAdded({required this.ride});

  @override
  List<Object> get props => [ride];
}

class RideUpdated extends RideEvent {
  final Ride ride;

  const RideUpdated({required this.ride});

  @override
  List<Object> get props => [ride];
}

class RideCreateRequested extends RideEvent {
  final CreateRideRequest request;

  const RideCreateRequested({required this.request});

  @override
  List<Object> get props => [request];
}

class RideStatusUpdateRequested extends RideEvent {
  final String rideId;
  final RideStatus status;

  const RideStatusUpdateRequested({required this.rideId, required this.status});

  @override
  List<Object> get props => [rideId, status];
}

class RideLoadPendingRequested extends RideEvent {
  const RideLoadPendingRequested();
}

class RideAssignRequested extends RideEvent {
  final String rideId;
  final String driverId;

  /// When true, the dispatcher has confirmed assignment despite a schedule conflict;
  /// the backend skips the conflict check for this request.
  final bool overrideScheduleConflict;

  const RideAssignRequested({
    required this.rideId,
    required this.driverId,
    this.overrideScheduleConflict = false,
  });

  @override
  List<Object> get props => [rideId, driverId, overrideScheduleConflict];
}

class RideReassignRequested extends RideEvent {
  final String rideId;
  final String newDriverId;

  /// When true, the dispatcher has confirmed reassignment despite a schedule
  /// conflict; the backend skips the conflict check for this request.
  final bool overrideScheduleConflict;

  const RideReassignRequested({
    required this.rideId,
    required this.newDriverId,
    this.overrideScheduleConflict = false,
  });

  @override
  List<Object> get props => [rideId, newDriverId, overrideScheduleConflict];
}

/// Driver confirms an assigned ride (PUT /rides/{id}/confirm).
class RideConfirmRequested extends RideEvent {
  final String rideId;

  const RideConfirmRequested({required this.rideId});

  @override
  List<Object> get props => [rideId];
}

/// Driver rejects an assigned ride with a reason (PUT /rides/{id}/reject).
class RideRejectRequested extends RideEvent {
  final String rideId;
  final String reason;

  const RideRejectRequested({required this.rideId, required this.reason});

  @override
  List<Object> get props => [rideId, reason];
}

/// Locally applies a status change received via WebSocket — no HTTP call.
class RideStatusReceived extends RideEvent {
  final String rideId;
  final RideStatus newStatus;

  const RideStatusReceived({required this.rideId, required this.newStatus});

  @override
  List<Object> get props => [rideId, newStatus];
}

/// Asks the bloc to cancel a ride with the given [reason].
/// Used by the dispatcher "Close" action on unassigned (Requested) rides.
class RideCancelRequested extends RideEvent {
  final String rideId;
  final String reason;

  const RideCancelRequested({required this.rideId, required this.reason});

  @override
  List<Object> get props => [rideId, reason];
}

/// Asks the bloc to hand off a ride to an external driver and partner company.
class RideHandOffRequested extends RideEvent {
  final String rideId;
  final String externalDriverId;
  final String partnerCompanyId;

  const RideHandOffRequested({
    required this.rideId,
    required this.externalDriverId,
    required this.partnerCompanyId,
  });

  @override
  List<Object> get props => [rideId, externalDriverId, partnerCompanyId];
}
