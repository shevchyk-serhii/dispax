import 'package:equatable/equatable.dart';
import '../../modules/core/services/api_client.dart' show ApiException;
import '../../modules/schedule_management/models/schedule_day.dart';

enum ScheduleStateStatus { initial, loading, loaded, error }

class ScheduleState extends Equatable {
  final ScheduleStateStatus status;
  final List<ScheduleDay> scheduleDays;
  final String? errorMessage;

  /// Typed cause behind an error state, when available. The UI passes this to
  /// `friendlyError` to render a localized, non-technical message instead of the
  /// raw [errorMessage]. Additive: emit sites that set only [errorMessage] keep
  /// working.
  final Object? error;
  final String? lastDriverId;

  const ScheduleState({
    this.status = ScheduleStateStatus.initial,
    this.scheduleDays = const [],
    this.errorMessage,
    this.error,
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

  factory ScheduleState.error(String message, {Object? cause}) {
    return ScheduleState(
      status: ScheduleStateStatus.error,
      errorMessage: message,
      error: cause,
    );
  }

  ScheduleState copyWith({
    ScheduleStateStatus? status,
    List<ScheduleDay>? scheduleDays,
    // [errorMessage]/[error] use a sentinel so callers can distinguish "leave
    // as is" (omit the argument) from "explicitly clear it" (pass null). An
    // omitted argument used to silently null the field, losing the error text
    // on any unrelated copyWith. Same pattern as RideState.copyWith.
    Object? errorMessage = _unset,
    Object? error = _unset,
    String? lastDriverId,
  }) {
    return ScheduleState(
      status: status ?? this.status,
      scheduleDays: scheduleDays ?? this.scheduleDays,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      error: identical(error, _unset) ? this.error : error,
      lastDriverId: lastDriverId ?? this.lastDriverId,
    );
  }

  static const Object _unset = Object();

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
  List<Object?> get props => [
    status,
    scheduleDays,
    errorMessage,
    // ApiException has no value equality; key on its kind (stable) so two error
    // states of the same kind compare equal. errorMessage above distinguishes
    // different messages.
    error is ApiException ? (error as ApiException).kind : error?.runtimeType,
    lastDriverId,
  ];
}
