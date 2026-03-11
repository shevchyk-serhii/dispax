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

class RideDeleteRequested extends RideEvent {
  final String rideId;

  const RideDeleteRequested({required this.rideId});

  @override
  List<Object> get props => [rideId];
}

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

  const RideStatusUpdateRequested({
    required this.rideId,
    required this.status,
  });

  @override
  List<Object> get props => [rideId, status];
}

class RideLoadPendingRequested extends RideEvent {
  const RideLoadPendingRequested();
}

class RideAssignRequested extends RideEvent {
  final String rideId;
  final String driverId;

  const RideAssignRequested({required this.rideId, required this.driverId});

  @override
  List<Object> get props => [rideId, driverId];
}
