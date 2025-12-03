import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/ride.dart';
import '../../services/ride_service.dart';
import 'ride_event.dart';
import 'ride_state.dart';

class RideBloc extends Bloc<RideEvent, RideState> {
  final RideService privateRideService;

  RideBloc({RideService? rideService})
    : privateRideService = rideService ?? RideService(),
      super(RideState.initial()) {
    on<RideLoadRequested>(onLoadRequested);
    on<RideRefreshRequested>(onRefreshRequested);
    on<RideDeleteRequested>(onDeleteRequested);
    on<RideAdded>(onRideAdded);
    on<RideUpdated>(onRideUpdated);
    on<RideCreateRequested>(onCreateRequested);
    on<RideStatusUpdateRequested>(onStatusUpdateRequested);
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

  Future<void> onDeleteRequested(
    RideDeleteRequested event,
    Emitter<RideState> emit,
  ) async {
    emit(
      state.copyWith(
        status: RideStateStatus.deleting,
        deletingRideId: event.rideId,
      ),
    );

    try {
      final success = await privateRideService.deleteRide(event.rideId);
      if (success) {
        final updatedRides = state.rides
            .where((ride) => ride.id != event.rideId)
            .toList();
        emit(RideState.loaded(updatedRides));
      } else {
        emit(
          state.copyWith(
            status: RideStateStatus.error,
            errorMessage: 'Failed to delete ride',
            deletingRideId: null,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: RideStateStatus.error,
          errorMessage: 'Delete error: $e',
          deletingRideId: null,
        ),
      );
    }
  }

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
    // Set loading state with current rides still visible
    emit(state.copyWith(
      status: RideStateStatus.loading,
      errorMessage: null,
    ));

    try {
      final createdRide = await privateRideService.createRide(event.ride);
      
      // Add the new ride to the existing list
      final updatedRides = List<Ride>.from(state.rides)..add(createdRide);
      
      emit(RideState.loaded(updatedRides));
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
    // Set loading state
    emit(state.copyWith(
      status: RideStateStatus.loading,
      errorMessage: null,
    ));

    try {
      final success = await privateRideService.updateRideStatus(event.rideId, event.status);
      
      if (success) {
        // Update the ride status in the existing list
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

  @override
  Future<void> close() {
    privateRideService.dispose();
    return super.close();
  }
}
