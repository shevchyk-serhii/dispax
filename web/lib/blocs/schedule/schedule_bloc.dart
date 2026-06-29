import 'package:flutter_bloc/flutter_bloc.dart';
import '../../modules/schedule_management/models/schedule_day.dart';
import '../../modules/schedule_management/services/schedule_service.dart';
import 'schedule_event.dart';
import 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final ScheduleService _scheduleService;

  ScheduleBloc({ScheduleService? scheduleService})
    : _scheduleService = scheduleService ?? ScheduleService(),
      super(ScheduleState.initial()) {
    on<ScheduleLoadDriverSchedule>(_onLoadDriverSchedule);
    on<ScheduleLoadForDate>(_onLoadForDate);
    on<ScheduleLoadForDateRange>(_onLoadForDateRange);
    on<ScheduleCreateDay>(_onCreateDay);
    on<ScheduleCancelDay>(_onCancelDay);
    on<ScheduleRefreshRequested>(_onRefresh);
  }

  Future<void> _onLoadDriverSchedule(
    ScheduleLoadDriverSchedule event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(ScheduleState.loading());
    try {
      final days = await _scheduleService.getDriverSchedule(event.driverId);
      emit(ScheduleState.loaded(days, driverId: event.driverId));
    } catch (e) {
      emit(ScheduleState.error('Failed to load driver schedule: $e'));
    }
  }

  Future<void> _onLoadForDate(
    ScheduleLoadForDate event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(ScheduleState.loading());
    try {
      final dateStr = _formatDate(event.date);
      final days = await _scheduleService.getScheduleForDate(dateStr);
      emit(ScheduleState.loaded(days));
    } catch (e) {
      emit(ScheduleState.error('Failed to load schedule for date: $e'));
    }
  }

  Future<void> _onLoadForDateRange(
    ScheduleLoadForDateRange event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(ScheduleState.loading());
    try {
      final fromStr = _formatDate(event.from);
      final toStr = _formatDate(event.to);
      final days = await _scheduleService.getScheduleForDateRange(
        fromStr,
        toStr,
      );
      emit(ScheduleState.loaded(days));
    } catch (e) {
      emit(ScheduleState.error('Failed to load schedule: $e'));
    }
  }

  Future<void> _onCreateDay(
    ScheduleCreateDay event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(state.copyWith(status: ScheduleStateStatus.loading));
    try {
      final newDay = await _scheduleService.createScheduleDay(
        driverId: event.driverId,
        date: event.date,
        startTime: event.startTime,
        endTime: event.endTime,
        notes: event.notes,
      );
      final updatedDays = List<ScheduleDay>.from(state.scheduleDays)
        ..add(newDay);
      emit(ScheduleState.loaded(updatedDays, driverId: state.lastDriverId));
    } catch (e) {
      emit(
        state.copyWith(
          status: ScheduleStateStatus.error,
          errorMessage: 'Failed to create schedule day: $e',
        ),
      );
    }
  }

  Future<void> _onCancelDay(
    ScheduleCancelDay event,
    Emitter<ScheduleState> emit,
  ) async {
    emit(state.copyWith(status: ScheduleStateStatus.loading));
    try {
      final cancelled = await _scheduleService.cancelScheduleDay(
        event.scheduleDayId,
      );
      final updatedDays = state.scheduleDays.map((day) {
        return day.id == cancelled.id ? cancelled : day;
      }).toList();
      emit(ScheduleState.loaded(updatedDays, driverId: state.lastDriverId));
    } catch (e) {
      emit(
        state.copyWith(
          status: ScheduleStateStatus.error,
          errorMessage: 'Failed to cancel schedule day: $e',
        ),
      );
    }
  }

  Future<void> _onRefresh(
    ScheduleRefreshRequested event,
    Emitter<ScheduleState> emit,
  ) async {
    final lastDriverId = state.lastDriverId;
    if (lastDriverId != null) {
      add(ScheduleLoadDriverSchedule(driverId: lastDriverId));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> close() {
    _scheduleService.dispose();
    return super.close();
  }
}
