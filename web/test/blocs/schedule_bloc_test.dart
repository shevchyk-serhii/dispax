import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/schedule/schedule_bloc.dart';
import 'package:dispax/blocs/schedule/schedule_event.dart';
import 'package:dispax/blocs/schedule/schedule_state.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/schedule_management/models/schedule_day.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockScheduleService mockScheduleService;
  late ScheduleDay testDay;
  late List<ScheduleDay> testDays;

  setUp(() {
    mockScheduleService = MockScheduleService();
    testDay = TestFixtures.scheduleDay();
    testDays = [testDay, TestFixtures.scheduleDay(id: 'schedule-2')];

    when(() => mockScheduleService.dispose()).thenReturn(null);
  });

  ScheduleBloc buildBloc() =>
      ScheduleBloc(scheduleService: mockScheduleService);

  group('ScheduleBloc', () {
    test('initial state is ScheduleState.initial()', () {
      final bloc = buildBloc();
      expect(bloc.state, ScheduleState.initial());
      bloc.close();
    });

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleLoadDriverSchedule emits loading then loaded',
      build: () {
        when(
          () => mockScheduleService.getDriverSchedule('driver-1'),
        ).thenAnswer((_) async => testDays);
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const ScheduleLoadDriverSchedule(driverId: 'driver-1')),
      expect: () => [
        ScheduleState.loading(),
        ScheduleState.loaded(testDays, driverId: 'driver-1'),
      ],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleLoadDriverSchedule emits error on failure',
      build: () {
        when(
          () => mockScheduleService.getDriverSchedule(any()),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      act: (bloc) =>
          bloc.add(const ScheduleLoadDriverSchedule(driverId: 'driver-1')),
      expect: () => [
        ScheduleState.loading(),
        isA<ScheduleState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleLoadForDate emits loading then loaded',
      build: () {
        when(
          () => mockScheduleService.getScheduleForDate(any()),
        ).thenAnswer((_) async => testDays);
        return buildBloc();
      },
      act: (bloc) => bloc.add(ScheduleLoadForDate(date: DateTime(2026, 3, 15))),
      expect: () => [ScheduleState.loading(), ScheduleState.loaded(testDays)],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleLoadForDateRange emits loading then loaded',
      build: () {
        when(
          () => mockScheduleService.getScheduleForDateRange(any(), any()),
        ).thenAnswer((_) async => testDays);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        ScheduleLoadForDateRange(
          from: DateTime(2026, 3, 1),
          to: DateTime(2026, 3, 31),
        ),
      ),
      expect: () => [ScheduleState.loading(), ScheduleState.loaded(testDays)],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleCreateDay emits loading then loaded with new day appended',
      build: () {
        final newDay = TestFixtures.scheduleDay(id: 'new-day');
        when(
          () => mockScheduleService.createScheduleDay(
            driverId: any(named: 'driverId'),
            date: any(named: 'date'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            notes: any(named: 'notes'),
          ),
        ).thenAnswer((_) async => newDay);
        return buildBloc();
      },
      seed: () => ScheduleState.loaded([testDay], driverId: 'driver-1'),
      act: (bloc) => bloc.add(
        const ScheduleCreateDay(
          driverId: 'driver-1',
          date: '2026-03-20',
          startTime: '09:00',
          endTime: '18:00',
        ),
      ),
      expect: () => [
        isA<ScheduleState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ScheduleState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having((s) => s.scheduleDays.length, 'days.length', 2),
      ],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleCreateDay emits error on failure',
      build: () {
        when(
          () => mockScheduleService.createScheduleDay(
            driverId: any(named: 'driverId'),
            date: any(named: 'date'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            notes: any(named: 'notes'),
          ),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      seed: () => ScheduleState.loaded([testDay]),
      act: (bloc) => bloc.add(
        const ScheduleCreateDay(
          driverId: 'driver-1',
          date: '2026-03-20',
          startTime: '09:00',
          endTime: '18:00',
        ),
      ),
      expect: () => [
        isA<ScheduleState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ScheduleState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleCancelDay emits loading then loaded with day updated',
      build: () {
        final cancelled = testDay.copyWith(status: ScheduleDayStatus.cancelled);
        when(
          () => mockScheduleService.cancelScheduleDay('schedule-1'),
        ).thenAnswer((_) async => cancelled);
        return buildBloc();
      },
      seed: () => ScheduleState.loaded([testDay], driverId: 'driver-1'),
      act: (bloc) =>
          bloc.add(const ScheduleCancelDay(scheduleDayId: 'schedule-1')),
      expect: () => [
        isA<ScheduleState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ScheduleState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having(
              (s) => s.scheduleDays.first.status,
              'status',
              ScheduleDayStatus.cancelled,
            ),
      ],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleCancelDay emits error on failure',
      build: () {
        when(
          () => mockScheduleService.cancelScheduleDay(any()),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      seed: () => ScheduleState.loaded([testDay]),
      act: (bloc) =>
          bloc.add(const ScheduleCancelDay(scheduleDayId: 'schedule-1')),
      expect: () => [
        isA<ScheduleState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ScheduleState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleRefreshRequested re-dispatches load if lastDriverId set',
      build: () {
        when(
          () => mockScheduleService.getDriverSchedule('driver-1'),
        ).thenAnswer((_) async => testDays);
        return buildBloc();
      },
      seed: () => ScheduleState.loaded([testDay], driverId: 'driver-1'),
      act: (bloc) => bloc.add(const ScheduleRefreshRequested()),
      expect: () => [
        ScheduleState.loading(),
        ScheduleState.loaded(testDays, driverId: 'driver-1'),
      ],
    );

    blocTest<ScheduleBloc, ScheduleState>(
      'ScheduleRefreshRequested is no-op if no lastDriverId',
      build: buildBloc,
      seed: () => ScheduleState.loaded([testDay]),
      act: (bloc) => bloc.add(const ScheduleRefreshRequested()),
      expect: () => [],
    );
  });
}
