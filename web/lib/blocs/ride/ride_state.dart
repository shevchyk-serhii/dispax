import 'package:equatable/equatable.dart';
import '../../modules/core/services/api_client.dart'
    show ApiException, ScheduleConflictInfo;
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

  /// The typed cause behind an error state, when available (e.g. the
  /// [ApiException] from a failed load). The UI passes this to `friendlyError`
  /// to render a short, localized, non-technical message — rather than the raw
  /// [errorMessage], which may carry the backend URL or a wrapped exception.
  /// Optional and additive: emit sites that still set only [errorMessage] keep
  /// working unchanged.
  final Object? error;
  final String? deletingRideId;

  /// Set together with [RideStateStatus.reassignConflict]: identifies the ride
  /// and the driver the dispatcher tried to assign, so the UI can offer to
  /// override the schedule conflict.
  final String? conflictRideId;
  final String? conflictDriverId;

  /// Structured details of the ride the driver is already booked for (route,
  /// client, pickup time), from the backend's schedule-conflict error. Lets the
  /// conflict dialog show a human-readable description instead of a raw id.
  /// Null when the backend sent no structured details (e.g. an unavailability
  /// conflict).
  final ScheduleConflictInfo? conflictInfo;

  const RideState({
    this.status = RideStateStatus.initial,
    this.rides = const [],
    this.errorMessage,
    this.error,
    this.deletingRideId,
    this.conflictRideId,
    this.conflictDriverId,
    this.conflictInfo,
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

  factory RideState.error(String message, {Object? cause}) {
    return RideState(
      status: RideStateStatus.error,
      errorMessage: message,
      error: cause,
    );
  }

  RideState copyWith({
    RideStateStatus? status,
    List<Ride>? rides,
    // All nullable fields below use the same sentinel so callers can
    // distinguish "leave as is" (omit the argument) from "explicitly clear it"
    // (pass null). A plain nullable parameter cannot tell those apart, so an
    // omitted argument used to silently null the field. For [errorMessage] that
    // produced a `status == error` state with a null message that crashed
    // TodayRidesScreen at `errorMessage!`. For the conflict fields it was worse:
    // a WebSocket status update (`onStatusReceived` → `copyWith(rides: ...)`)
    // arriving while a conflict dialog was open would null out
    // [conflictRideId]/[conflictDriverId], flipping `hasAssignConflict` to false
    // and breaking the "assign anyway" override dialog mid-flow.
    Object? errorMessage = _unset,
    Object? error = _unset,
    Object? deletingRideId = _unset,
    Object? conflictRideId = _unset,
    Object? conflictDriverId = _unset,
    Object? conflictInfo = _unset,
  }) {
    return RideState(
      status: status ?? this.status,
      rides: rides ?? this.rides,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      error: identical(error, _unset) ? this.error : error,
      deletingRideId: identical(deletingRideId, _unset)
          ? this.deletingRideId
          : deletingRideId as String?,
      conflictRideId: identical(conflictRideId, _unset)
          ? this.conflictRideId
          : conflictRideId as String?,
      conflictDriverId: identical(conflictDriverId, _unset)
          ? this.conflictDriverId
          : conflictDriverId as String?,
      conflictInfo: identical(conflictInfo, _unset)
          ? this.conflictInfo
          : conflictInfo as ScheduleConflictInfo?,
    );
  }

  /// Sentinel for [copyWith]: marks an argument the caller did not supply, so an
  /// omitted nullable field keeps its current value instead of being nulled.
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
    // ApiException has no value equality, so keying props on the object by
    // identity would defeat Equatable. Use a stable surrogate (its kind) so two
    // states carrying the same kind of error compare equal; errorMessage above
    // already distinguishes different messages.
    error is ApiException ? (error as ApiException).kind : error?.runtimeType,
    deletingRideId,
    conflictRideId,
    conflictDriverId,
    // ScheduleConflictInfo has no value equality; compare by its fields so two
    // states with the same conflict details are equal.
    conflictInfo?.rideId,
    conflictInfo?.clientId,
    conflictInfo?.from,
    conflictInfo?.to,
    conflictInfo?.pickupAt,
  ];
}
