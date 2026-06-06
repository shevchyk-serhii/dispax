import 'package:flutter_bloc/flutter_bloc.dart';
import '../../modules/ride_management/models/driver_earnings.dart';
import '../../modules/ride_management/services/ride_service.dart';

enum EarningsPeriod { day, week, month }

extension EarningsPeriodValue on EarningsPeriod {
  String get apiValue => switch (this) {
    EarningsPeriod.day => 'day',
    EarningsPeriod.week => 'week',
    EarningsPeriod.month => 'month',
  };
}

enum EarningsStatus { initial, loading, loaded, error }

class EarningsState {
  final EarningsStatus status;
  final EarningsPeriod period;
  final DateTime anchorDate;
  final DriverEarnings? data;
  final String? error;

  const EarningsState({
    required this.status,
    required this.period,
    required this.anchorDate,
    this.data,
    this.error,
  });

  factory EarningsState.initial() => EarningsState(
    status: EarningsStatus.initial,
    period: EarningsPeriod.week,
    anchorDate: DateTime.now(),
  );

  EarningsState copyWith({
    EarningsStatus? status,
    EarningsPeriod? period,
    DateTime? anchorDate,
    DriverEarnings? data,
    String? error,
    bool clearError = false,
  }) {
    return EarningsState(
      status: status ?? this.status,
      period: period ?? this.period,
      anchorDate: anchorDate ?? this.anchorDate,
      data: data ?? this.data,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class EarningsCubit extends Cubit<EarningsState> {
  final RideService privateRideService;
  String? _driverId;

  EarningsCubit({RideService? rideService})
    : privateRideService = rideService ?? RideService(),
      super(EarningsState.initial());

  /// Загружает заработок для водителя и текущих period/anchorDate.
  Future<void> load(String driverId) async {
    _driverId = driverId;
    emit(state.copyWith(status: EarningsStatus.loading, clearError: true));
    try {
      final data = await privateRideService.getDriverEarnings(
        driverId,
        state.period.apiValue,
        state.anchorDate,
      );
      emit(state.copyWith(status: EarningsStatus.loaded, data: data));
    } catch (e) {
      emit(
        state.copyWith(
          status: EarningsStatus.error,
          error: 'Failed to load earnings: $e',
        ),
      );
    }
  }

  Future<void> setPeriod(EarningsPeriod period) async {
    if (period == state.period) return;
    emit(state.copyWith(period: period, anchorDate: DateTime.now()));
    await _reload();
  }

  Future<void> nextPeriod() async {
    emit(state.copyWith(anchorDate: _shift(state.anchorDate, state.period, 1)));
    await _reload();
  }

  Future<void> prevPeriod() async {
    emit(
      state.copyWith(anchorDate: _shift(state.anchorDate, state.period, -1)),
    );
    await _reload();
  }

  Future<void> goToToday() async {
    emit(state.copyWith(anchorDate: DateTime.now()));
    await _reload();
  }

  Future<void> _reload() async {
    final id = _driverId;
    if (id != null) await load(id);
  }

  DateTime _shift(DateTime date, EarningsPeriod period, int direction) {
    return switch (period) {
      EarningsPeriod.day => date.add(Duration(days: direction)),
      EarningsPeriod.week => date.add(Duration(days: 7 * direction)),
      EarningsPeriod.month => DateTime(
        date.year,
        date.month + direction,
        date.day,
      ),
    };
  }

  @override
  Future<void> close() {
    privateRideService.dispose();
    return super.close();
  }
}
