import 'package:flutter_bloc/flutter_bloc.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/services/ride_service.dart';
import '../../modules/core/services/api_client.dart';
import 'ride_event.dart';
import 'ride_state.dart';

class RideBloc extends Bloc<RideEvent, RideState> {
  final RideService privateRideService;

  RideBloc({RideService? rideService})
    : privateRideService = rideService ?? RideService(),
      super(RideState.initial()) {
    on<RideLoadRequested>(onLoadRequested);
    on<RideRefreshRequested>(onRefreshRequested);
    // NOTE: RideDeleteRequested removed — backend does not support DELETE /rides/:id
    // on<RideDeleteRequested>(onDeleteRequested);
    on<RideAdded>(onRideAdded);
    on<RideUpdated>(onRideUpdated);
    on<RideCreateRequested>(onCreateRequested);
    on<RideStatusUpdateRequested>(onStatusUpdateRequested);
    on<RideLoadPendingRequested>(onLoadPendingRequested);
    on<RideAssignRequested>(onAssignRequested);
    on<RideReassignRequested>(onReassignRequested);
    on<RideConfirmRequested>(onConfirmRequested);
    on<RideRejectRequested>(onRejectRequested);
    on<RideStatusReceived>(onStatusReceived);
    on<RideCancelRequested>(onCancelRequested);
    on<RideHandOffRequested>(onHandOffRequested);
  }

  Future<void> onLoadRequested(
    RideLoadRequested event,
    Emitter<RideState> emit,
  ) async {
    if (state.status == RideStateStatus.initial) {
      emit(RideState.loading());
    }

    try {
      final rides = await privateRideService.getRidesForUser(event.user);
      emit(RideState.loaded(rides));
    } catch (e) {
      emit(RideState.error('Failed to load rides: $e'));
    }
  }

  Future<void> onRefreshRequested(
    RideRefreshRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(RideState.loading());

    try {
      final rides = await privateRideService.getRidesForUser(event.user);
      emit(RideState.loaded(rides));
    } catch (e) {
      emit(RideState.error('Failed to refresh rides: $e'));
    }
  }

  // NOTE: onDeleteRequested removed — backend does not support DELETE /rides/:id
  // The entire delete handler has been removed. See git history for original code.

  void onRideAdded(RideAdded event, Emitter<RideState> emit) {
    // Deduplicate by id: a WebSocket RideCreated can race a getRides() reload,
    // so the same ride may already be present. Replace it instead of appending
    // a duplicate that would then show twice in the list.
    final existing = state.rides.indexWhere((r) => r.id == event.ride.id);
    final updatedRides = List<Ride>.from(state.rides);
    if (existing == -1) {
      updatedRides.add(event.ride);
    } else {
      updatedRides[existing] = event.ride;
    }
    emit(RideState.loaded(updatedRides));
  }

  void onRideUpdated(RideUpdated event, Emitter<RideState> emit) {
    final updatedRides = state.rides.map((ride) {
      return ride.id == event.ride.id ? event.ride : ride;
    }).toList();
    emit(RideState.loaded(updatedRides));
  }

  Future<void> onCreateRequested(
    RideCreateRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(status: RideStateStatus.loading, errorMessage: null));

    try {
      final createdRide = await privateRideService.createRide(event.request);
      final updatedRides = List<Ride>.from(state.rides)..add(createdRide);

      // A driver may opt in to "Assign to me" while creating the ride. The
      // backend creates the ride into the pool first and only then tries to
      // self-assign; if that hits a schedule conflict it swallows the error and
      // returns the ride still unassigned (the ride is never lost). Detect that
      // case — self-assign was requested (driverId in the request) but the
      // created ride came back without a driver — and surface assignConflict so
      // the UI can offer "assign anyway" via the existing override path.
      final requestedDriverId = event.request.driverId;
      if (requestedDriverId != null && createdRide.driverId == null) {
        emit(
          RideState(
            status: RideStateStatus.assignConflict,
            rides: updatedRides,
            conflictRideId: createdRide.id,
            conflictDriverId: requestedDriverId,
          ),
        );
      } else {
        emit(RideState(status: RideStateStatus.created, rides: updatedRides));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to create ride: $e',
        ),
      );
    }
  }

  Future<void> onStatusUpdateRequested(
    RideStatusUpdateRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(status: RideStateStatus.loading, errorMessage: null));

    try {
      final success = await privateRideService.updateRideStatus(
        event.rideId,
        event.status,
      );

      if (success) {
        final updatedRides = state.rides.map((ride) {
          if (ride.id == event.rideId) {
            return ride.copyWith(status: event.status);
          }
          return ride;
        }).toList();

        emit(RideState.loaded(updatedRides));
      } else {
        emit(
          state.copyWith(
            status: RideStateStatus.error,
            errorMessage: 'Failed to update ride status',
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to update ride status: $e',
        ),
      );
    }
  }

  Future<void> onLoadPendingRequested(
    RideLoadPendingRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(status: RideStateStatus.loading));

    try {
      final rides = await privateRideService.getPendingRides();
      emit(RideState.loaded(rides));
    } catch (e) {
      emit(RideState.error('Failed to load pending rides: $e'));
    }
  }

  Future<void> onAssignRequested(
    RideAssignRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(status: RideStateStatus.assigning));

    try {
      final updatedRide = await privateRideService.assignDriver(
        event.rideId,
        event.driverId,
        overrideScheduleConflict: event.overrideScheduleConflict,
      );
      final updatedRides = state.rides.map((ride) {
        return ride.id == updatedRide.id ? updatedRide : ride;
      }).toList();
      emit(RideState.loaded(updatedRides));
    } on ApiException catch (e) {
      // A 409 covers two distinct cases. "Ride already assigned" means the ride
      // was taken (another dispatcher or auto-assignment) since this view was
      // loaded — a stale-state race, NOT a schedule conflict. Overriding cannot
      // help, so reload the pending list (the ride moves to the Assigned tab)
      // and surface a non-error state so the UI shows an info message, not a red
      // failure with a doomed Retry.
      if (e.statusCode == 409 && _isAlreadyAssigned(e.message)) {
        final rides = await _reloadPendingSilently();
        emit(
          RideState(
            status: RideStateStatus.alreadyAssigned,
            rides: rides,
            errorMessage: e.message,
          ),
        );
        return;
      }
      // Any other 409 means the driver has a schedule conflict. Unless the
      // dispatcher already chose to override, surface a distinct state so the UI
      // can offer to assign anyway.
      if (e.statusCode == 409 && !event.overrideScheduleConflict) {
        emit(
          state.copyWith(
            status: RideStateStatus.assignConflict,
            errorMessage: e.message,
            conflictRideId: event.rideId,
            conflictDriverId: event.driverId,
            conflictInfo: e.scheduleConflict,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: RideStateStatus.error,
            errorMessage: e.message,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to assign driver: $e',
        ),
      );
    }
  }

  /// Matches the backend's `RideAlreadyAssigned` error body ("Ride already
  /// assigned", see RideSecure.fromRideError) so we can distinguish the
  /// stale-state race from a schedule conflict — both arrive as HTTP 409.
  bool _isAlreadyAssigned(String message) =>
      message.toLowerCase().contains('already assigned');

  /// Refreshes the pending list after a stale-state rejection, keeping the
  /// current rides if the reload itself fails (best effort — the goal is to drop
  /// the now-assigned ride from the pending tab, not to surface a load error).
  Future<List<Ride>> _reloadPendingSilently() async {
    try {
      return await privateRideService.getPendingRides();
    } catch (_) {
      return state.rides;
    }
  }

  Future<void> onReassignRequested(
    RideReassignRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(status: RideStateStatus.assigning));

    try {
      final updatedRide = await privateRideService.reassignDriver(
        event.rideId,
        event.newDriverId,
        overrideScheduleConflict: event.overrideScheduleConflict,
      );
      final updatedRides = state.rides.map((ride) {
        return ride.id == updatedRide.id ? updatedRide : ride;
      }).toList();
      emit(RideState.loaded(updatedRides));
    } on ApiException catch (e) {
      // A 409 means the new driver has a schedule conflict. Unless the
      // dispatcher already chose to override, surface a distinct state so the
      // UI can offer to reassign anyway.
      if (e.statusCode == 409 && !event.overrideScheduleConflict) {
        emit(
          state.copyWith(
            status: RideStateStatus.reassignConflict,
            errorMessage: e.message,
            conflictRideId: event.rideId,
            conflictDriverId: event.newDriverId,
            conflictInfo: e.scheduleConflict,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: RideStateStatus.error,
            errorMessage: e.message,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to reassign driver: $e',
        ),
      );
    }
  }

  Future<void> onConfirmRequested(
    RideConfirmRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(status: RideStateStatus.loading, errorMessage: null));

    try {
      final updatedRide = await privateRideService.confirmRide(event.rideId);
      final updatedRides = state.rides.map((ride) {
        return ride.id == updatedRide.id ? updatedRide : ride;
      }).toList();
      emit(RideState.loaded(updatedRides));
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to confirm ride: $e',
        ),
      );
    }
  }

  Future<void> onRejectRequested(
    RideRejectRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(status: RideStateStatus.loading, errorMessage: null));

    try {
      final updatedRide = await privateRideService.rejectRide(
        event.rideId,
        event.reason,
      );
      final updatedRides = state.rides.map((ride) {
        return ride.id == updatedRide.id ? updatedRide : ride;
      }).toList();
      emit(RideState.loaded(updatedRides));
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to reject ride: $e',
        ),
      );
    }
  }

  void onStatusReceived(RideStatusReceived event, Emitter<RideState> emit) {
    if (state.rides.isEmpty) return;
    final idx = state.rides.indexWhere((r) => r.id == event.rideId);
    if (idx == -1) return;
    final updatedRides = List<Ride>.from(state.rides);
    updatedRides[idx] = updatedRides[idx].copyWith(status: event.newStatus);
    // A live WebSocket update proves the system is responsive, so settle back
    // to a clean loaded state instead of preserving a stale error status (and
    // its message) left over from an earlier failed operation.
    emit(RideState.loaded(updatedRides));
  }

  Future<void> onCancelRequested(
    RideCancelRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(
      state.copyWith(status: RideStateStatus.cancelling, errorMessage: null),
    );
    try {
      await privateRideService.cancelRide(event.rideId, event.reason);
      // Remove the cancelled ride from the list so the panel refreshes immediately.
      final updatedRides = state.rides
          .where((r) => r.id != event.rideId)
          .toList();
      emit(RideState.loaded(updatedRides));
    } on ApiException catch (e) {
      emit(
        state.copyWith(status: RideStateStatus.error, errorMessage: e.message),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to cancel ride: $e',
        ),
      );
    }
  }

  Future<void> onHandOffRequested(
    RideHandOffRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(
      state.copyWith(status: RideStateStatus.handingOff, errorMessage: null),
    );
    try {
      final updatedRide = await privateRideService.handOffRide(
        event.rideId,
        externalDriverId: event.externalDriverId,
        partnerCompanyId: event.partnerCompanyId,
      );
      final updatedRides = state.rides.map((r) {
        return r.id == updatedRide.id ? updatedRide : r;
      }).toList();
      emit(RideState.loaded(updatedRides));
    } on ApiException catch (e) {
      emit(
        state.copyWith(status: RideStateStatus.error, errorMessage: e.message),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to hand off ride: $e',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    privateRideService.dispose();
    return super.close();
  }
}
