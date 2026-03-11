import 'package:equatable/equatable.dart';

abstract class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

class ScheduleLoadDriverSchedule extends ScheduleEvent {
  final String driverId;

  const ScheduleLoadDriverSchedule({required this.driverId});

  @override
  List<Object> get props => [driverId];
}

class ScheduleLoadForDate extends ScheduleEvent {
  final DateTime date;

  const ScheduleLoadForDate({required this.date});

  @override
  List<Object> get props => [date];
}

class ScheduleLoadForDateRange extends ScheduleEvent {
  final DateTime from;
  final DateTime to;

  const ScheduleLoadForDateRange({required this.from, required this.to});

  @override
  List<Object> get props => [from, to];
}

class ScheduleCreateDay extends ScheduleEvent {
  final String driverId;
  final String date;
  final String startTime;
  final String endTime;
  final String? notes;

  const ScheduleCreateDay({
    required this.driverId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.notes,
  });

  @override
  List<Object?> get props => [driverId, date, startTime, endTime, notes];
}

class ScheduleCancelDay extends ScheduleEvent {
  final String scheduleDayId;

  const ScheduleCancelDay({required this.scheduleDayId});

  @override
  List<Object> get props => [scheduleDayId];
}

class ScheduleRefreshRequested extends ScheduleEvent {
  const ScheduleRefreshRequested();
}
