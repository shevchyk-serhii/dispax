import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:dispax/modules/ride_management/models/vehicle_class.dart';
import 'package:dispax/modules/ride_management/models/ride_estimate.dart';

void main() {
  group('CreateRideFormBloc — VehicleClassSelected', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'selects business by default',
      build: CreateRideFormBloc.new,
      verify: (bloc) =>
          expect(bloc.state.selectedVehicleClass, VehicleClass.business),
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'VehicleClassSelected(van) updates selectedVehicleClass',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const VehicleClassSelected(VehicleClass.van)),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.selectedVehicleClass,
          'selectedVehicleClass',
          VehicleClass.van,
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'VehicleClassSelected(business) switches back to business',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState.initial().copyWith(
        selectedVehicleClass: VehicleClass.van,
      ),
      act: (bloc) =>
          bloc.add(const VehicleClassSelected(VehicleClass.business)),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.selectedVehicleClass,
          'selectedVehicleClass',
          VehicleClass.business,
        ),
      ],
    );
  });

  group('CreateRideFormBloc — ScheduleModeToggled', () {
    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'isScheduled starts as true',
      build: CreateRideFormBloc.new,
      verify: (bloc) => expect(bloc.state.isScheduled, isTrue),
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ScheduleModeToggled(scheduled:false) sets isScheduled to false and picks ASAP time',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(const ScheduleModeToggled(scheduled: false)),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.isScheduled,
          'isScheduled',
          false,
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'ScheduleModeToggled(scheduled:true) sets isScheduled back to true',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState.initial().copyWith(isScheduled: false),
      act: (bloc) => bloc.add(const ScheduleModeToggled(scheduled: true)),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.isScheduled,
          'isScheduled',
          true,
        ),
      ],
    );
  });

  group('CreateRideFormBloc — EstimateReceived', () {
    const businessEstimate = RideEstimate(
      distanceKm: 25.0,
      durationMinutes: 30,
      estimatedPrice: 62.0,
      currency: 'EUR',
    );

    const vanEstimate = RideEstimate(
      distanceKm: 25.0,
      durationMinutes: 30,
      estimatedPrice: 88.0,
      currency: 'EUR',
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'EstimateReceived for business populates estimateBusiness',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(
        const EstimateReceived(
          vehicleClass: VehicleClass.business,
          estimate: businessEstimate,
        ),
      ),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.estimateBusiness?.estimatedPrice,
          'estimateBusiness.estimatedPrice',
          62.0,
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'EstimateReceived for van populates estimateVan',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc.add(
        const EstimateReceived(
          vehicleClass: VehicleClass.van,
          estimate: vanEstimate,
        ),
      ),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.estimateVan?.estimatedPrice,
          'estimateVan.estimatedPrice',
          88.0,
        ),
      ],
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'activeEstimate returns business estimate when business selected',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc
        ..add(
          const EstimateReceived(
            vehicleClass: VehicleClass.business,
            estimate: businessEstimate,
          ),
        )
        ..add(
          const EstimateReceived(
            vehicleClass: VehicleClass.van,
            estimate: vanEstimate,
          ),
        ),
      verify: (bloc) {
        expect(bloc.state.selectedVehicleClass, VehicleClass.business);
        expect(bloc.state.activeEstimate?.estimatedPrice, 62.0);
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'activeEstimate returns van estimate when van selected',
      build: CreateRideFormBloc.new,
      act: (bloc) => bloc
        ..add(const VehicleClassSelected(VehicleClass.van))
        ..add(
          const EstimateReceived(
            vehicleClass: VehicleClass.business,
            estimate: businessEstimate,
          ),
        )
        ..add(
          const EstimateReceived(
            vehicleClass: VehicleClass.van,
            estimate: vanEstimate,
          ),
        ),
      verify: (bloc) {
        expect(bloc.state.selectedVehicleClass, VehicleClass.van);
        expect(bloc.state.activeEstimate?.estimatedPrice, 88.0);
      },
    );

    blocTest<CreateRideFormBloc, CreateRideFormState>(
      'EstimateReceived(estimate:null) clears the estimate',
      build: CreateRideFormBloc.new,
      seed: () => CreateRideFormState.initial().copyWith(
        estimateBusiness: businessEstimate,
      ),
      act: (bloc) => bloc.add(
        const EstimateReceived(
          vehicleClass: VehicleClass.business,
          estimate: null,
        ),
      ),
      expect: () => [
        isA<CreateRideFormState>().having(
          (s) => s.estimateBusiness,
          'estimateBusiness',
          isNull,
        ),
      ],
    );
  });
}
