import 'package:equatable/equatable.dart';
import '../../models/person.dart';
import '../../models/ride.dart';

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
  final int rideId;

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
  final Ride ride;

  const RideCreateRequested({required this.ride});

  @override
  List<Object> get props => [ride];
}

class RideStatusUpdateRequested extends RideEvent {
  final int rideId;
  final RideStatus status;

  const RideStatusUpdateRequested({
    required this.rideId,
    required this.status,
  });

  @override
  List<Object> get props => [rideId, status];
}
