import 'package:equatable/equatable.dart';
import '../../modules/ride_management/models/ride.dart';

enum RideStateStatus { initial, loading, loaded, created, error, deleting, assigning }

class RideState extends Equatable {
  final RideStateStatus status;
  final List<Ride> rides;
  final String? errorMessage;
  final String? deletingRideId;

  const RideState({
    this.status = RideStateStatus.initial,
    this.rides = const [],
    this.errorMessage,
    this.deletingRideId,
  });

  factory RideState.initial() {
    return const RideState();
  }

  factory RideState.loading() {
    return const RideState(status: RideStateStatus.loading);
  }

  factory RideState.loaded(List<Ride> rides) {
    return RideState(status: RideStateStatus.loaded, rides: rides);
  }

  factory RideState.error(String message) {
    return RideState(status: RideStateStatus.error, errorMessage: message);
  }

  RideState copyWith({
    RideStateStatus? status,
    List<Ride>? rides,
    String? errorMessage,
    String? deletingRideId,
  }) {
    return RideState(
      status: status ?? this.status,
      rides: rides ?? this.rides,
      errorMessage: errorMessage,
      deletingRideId: deletingRideId,
    );
  }

  bool get isLoading => status == RideStateStatus.loading;
  bool get isLoaded => status == RideStateStatus.loaded || status == RideStateStatus.created;
  bool get hasError => status == RideStateStatus.error;
  bool get isEmpty => rides.isEmpty && isLoaded;
  bool get isDeleting => status == RideStateStatus.deleting;
  bool get isAssigning => status == RideStateStatus.assigning;

  @override
  List<Object?> get props => [status, rides, errorMessage, deletingRideId];
}
