import 'package:equatable/equatable.dart';
import '../../modules/schedule_management/models/schedule_day.dart';

enum ScheduleStateStatus { initial, loading, loaded, error }

class ScheduleState extends Equatable {
  final ScheduleStateStatus status;
  final List<ScheduleDay> scheduleDays;
  final String? errorMessage;
  final String? lastDriverId;

  const ScheduleState({
    this.status = ScheduleStateStatus.initial,
    this.scheduleDays = const [],
    this.errorMessage,
    this.lastDriverId,
  });

  factory ScheduleState.initial() {
    return const ScheduleState();
  }

  factory ScheduleState.loading() {
    return const ScheduleState(status: ScheduleStateStatus.loading);
  }

  factory ScheduleState.loaded(List<ScheduleDay> days, {String? driverId}) {
    return ScheduleState(
      status: ScheduleStateStatus.loaded,
      scheduleDays: days,
      lastDriverId: driverId,
    );
  }

  factory ScheduleState.error(String message) {
    return ScheduleState(
      status: ScheduleStateStatus.error,
      errorMessage: message,
    );
  }

  ScheduleState copyWith({
    ScheduleStateStatus? status,
    List<ScheduleDay>? scheduleDays,
    String? errorMessage,
    String? lastDriverId,
  }) {
    return ScheduleState(
      status: status ?? this.status,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      errorMessage: errorMessage,
      lastDriverId: lastDriverId ?? this.lastDriverId,
    );
  }

  bool get isLoading => status == ScheduleStateStatus.loading;
  bool get isLoaded => status == ScheduleStateStatus.loaded;
  bool get hasError => status == ScheduleStateStatus.error;
  bool get isEmpty => scheduleDays.isEmpty && isLoaded;

  List<ScheduleDay> getScheduleForDate(DateTime date) {
    return scheduleDays
        .where(
          (day) =>
              day.date.year == date.year &&
              day.date.month == date.month &&
              day.date.day == date.day,
        )
        .toList();
  }

  @override
  List<Object?> get props => [status, scheduleDays, errorMessage, lastDriverId];
}
