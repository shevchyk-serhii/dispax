import 'package:equatable/equatable.dart';
import '../../modules/ride_management/models/ride.dart';

enum RideStateStatus {
  initial,
  loading,
  loaded,
  created,
  error,
  deleting,
  assigning,
  cancelling,
  handingOff,
  // The backend rejected a reassignment because the new driver's schedule
  // conflicts; the dispatcher may retry with override.
  reassignConflict,
  // The backend rejected a primary assignment because the driver's schedule
  // conflicts (ride overlap or unavailability); the dispatcher may retry with
  // override.
  assignConflict,
  // The backend rejected a primary assignment because the ride was already
  // assigned to a driver (stale dispatcher view: another dispatcher or
  // auto-assignment took it first). Not retryable — the UI should reload the
  // pending list and inform the dispatcher.
  alreadyAssigned,
}

class RideState extends Equatable {
  final RideStateStatus status;
  final List<Ride> rides;
  final String? errorMessage;
  final String? deletingRideId;

  /// Set together with [RideStateStatus.reassignConflict]: identifies the ride
  /// and the driver the dispatcher tried to assign, so the UI can offer to
  /// override the schedule conflict.
  final String? conflictRideId;
  final String? conflictDriverId;

  const RideState({
    this.status = RideStateStatus.initial,
    this.rides = const [],
    this.errorMessage,
    this.deletingRideId,
    this.conflictRideId,
    this.conflictDriverId,
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
    // [errorMessage] uses a sentinel so callers can distinguish "leave as is"
    // (omit the argument) from "explicitly clear it" (pass null). A plain
    // nullable parameter cannot tell those apart, so an omitted argument used
    // to silently null the message — producing a `status == error` state with
    // a null message that crashed TodayRidesScreen at `errorMessage!`.
    Object? errorMessage = _unset,
    String? deletingRideId,
    String? conflictRideId,
    String? conflictDriverId,
  }) {
    return RideState(
      status: status ?? this.status,
      rides: rides ?? this.rides,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      deletingRideId: deletingRideId,
      conflictRideId: conflictRideId,
      conflictDriverId: conflictDriverId,
    );
  }

  /// Sentinel for [copyWith]: marks an argument the caller did not supply, so
  /// an omitted [errorMessage] keeps the current value instead of nulling it.
  static const Object _unset = Object();

  bool get isLoading => status == RideStateStatus.loading;
  bool get isLoaded =>
      status == RideStateStatus.loaded || status == RideStateStatus.created;
  bool get hasError => status == RideStateStatus.error;
  bool get isEmpty => rides.isEmpty && isLoaded;
  bool get isDeleting => status == RideStateStatus.deleting;
  bool get isAssigning => status == RideStateStatus.assigning;
  bool get isCancelling => status == RideStateStatus.cancelling;
  bool get isHandingOff => status == RideStateStatus.handingOff;
  bool get hasReassignConflict =>
      status == RideStateStatus.reassignConflict &&
      conflictRideId != null &&
      conflictDriverId != null;

  bool get hasAssignConflict =>
      status == RideStateStatus.assignConflict &&
      conflictRideId != null &&
      conflictDriverId != null;

  bool get isAlreadyAssigned => status == RideStateStatus.alreadyAssigned;

  @override
  List<Object?> get props => [
    status,
    rides,
    errorMessage,
    deletingRideId,
    conflictRideId,
    conflictDriverId,
  ];
}
