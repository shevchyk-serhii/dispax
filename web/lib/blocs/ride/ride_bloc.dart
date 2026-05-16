import 'package:flutter_bloc/flutter_bloc.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/services/ride_service.dart';
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
    final updatedRides = List<Ride>.from(state.rides)..add(event.ride);
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
    emit(state.copyWith(
      status: RideStateStatus.loading,
      errorMessage: null,
    ));

    try {
      final createdRide = await privateRideService.createRide(event.request);
      final updatedRides = List<Ride>.from(state.rides)..add(createdRide);
      emit(RideState(status: RideStateStatus.created, rides: updatedRides));
    } catch (e) {
      emit(state.copyWith(
        status: RideStateStatus.error,
        errorMessage: 'Failed to create ride: $e',
      ));
    }
  }

  Future<void> onStatusUpdateRequested(
    RideStatusUpdateRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(
      status: RideStateStatus.loading,
      errorMessage: null,
    ));

    try {
      final success = await privateRideService.updateRideStatus(event.rideId, event.status);

      if (success) {
        final updatedRides = state.rides.map((ride) {
          if (ride.id == event.rideId) {
            return ride.copyWith(status: event.status);
          }
          return ride;
        }).toList();

        emit(RideState.loaded(updatedRides));
      } else {
        emit(state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Failed to update ride status',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: RideStateStatus.error,
        errorMessage: 'Failed to update ride status: $e',
      ));
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
      final updatedRide = await privateRideService.assignDriver(event.rideId, event.driverId);
      final updatedRides = state.rides.map((ride) {
        return ride.id == updatedRide.id ? updatedRide : ride;
      }).toList();
      emit(RideState.loaded(updatedRides));
    } catch (e) {
      emit(state.copyWith(
        status: RideStateStatus.error,
        errorMessage: 'Failed to assign driver: $e',
      ));
    }
  }

  Future<void> onReassignRequested(
    RideReassignRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(state.copyWith(status: RideStateStatus.assigning));

    try {
      final updatedRide = await privateRideService.reassignDriver(event.rideId, event.newDriverId);
      final updatedRides = state.rides.map((ride) {
        return ride.id == updatedRide.id ? updatedRide : ride;
      }).toList();
      emit(RideState.loaded(updatedRides));
    } catch (e) {
      emit(state.copyWith(
        status: RideStateStatus.error,
        errorMessage: 'Failed to reassign driver: $e',
      ));
    }
  }

  @override
  Future<void> close() {
    privateRideService.dispose();
    return super.close();
  }
}
