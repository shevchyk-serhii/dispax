import 'dart:async';
import 'package:flutter/material.dart';
import '../../flight_management/models/airport_timing.dart';
import '../../ride_management/models/ride.dart';
import '../../flight_management/services/airport_timing_service.dart';
import '../../core/services/location_service.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';

class AirportEntryTimer extends StatefulWidget {
  final Ride ride;
  final VoidCallback? onEntryTimeReached;

  const AirportEntryTimer({
    super.key,
    required this.ride,
    this.onEntryTimeReached,
  });

  @override
  State<AirportEntryTimer> createState() => _AirportEntryTimerState();
}

class _AirportEntryTimerState extends State<AirportEntryTimer> {
  AirportTiming? _airportTiming;
  Timer? _updateTimer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAirportTiming();
    _startPeriodicUpdate();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _loadAirportTiming();
    });
  }

  Future<void> _loadAirportTiming() async {
    if (!widget.ride.isAirportTransfer ||
        widget.ride.status != RideStatus.assigned) {
      return;
    }

    final position = await LocationService.instance.getCurrentPosition();
    if (position == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final timing = await AirportTimingService.instance.getOptimalEntryTime(
        rideId: widget.ride.id.toString(),
        driverLatitude: position.latitude,
        driverLongitude: position.longitude,
      );

      if (mounted) {
        setState(() {
          _airportTiming = timing;
          _isLoading = false;
        });

        if (timing?.shouldDepartNow == true) {
          widget.onEntryTimeReached?.call();
          // Departure has been signalled — no further recalculation is useful, so stop
          // the per-minute polling (and its network call) for this ride.
          _updateTimer?.cancel();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ride.isAirportTransfer) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: AppDimensions.paddingMedium),
          if (_isLoading)
            _buildLoadingState()
          else if (_errorMessage != null)
            _buildErrorState()
          else if (_airportTiming != null)
            _buildTimingInfo()
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.flight_land,
          color: AppColors.textOnPrimary,
          size: AppDimensions.iconMedium,
        ),
        const SizedBox(width: AppDimensions.paddingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Airport Entry Time',
                style: AppStyles.titleMedium.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              Text(
                '${widget.ride.flightNumber} • ${widget.ride.terminal} • Gate ${widget.ride.gate}',
                style: AppStyles.bodySmall.copyWith(
                  color: AppColors.textOnPrimary.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.textOnPrimary),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(50),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: AppColors.error,
            size: AppDimensions.iconSmall,
          ),
          const SizedBox(width: AppDimensions.paddingSmall),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Text(
      'Loading entry time data...',
      style: AppStyles.bodyMedium.copyWith(
        color: AppColors.textOnPrimary.withAlpha(180),
      ),
    );
  }

  Widget _buildTimingInfo() {
    final timing = _airportTiming!;

    return Column(
      children: [
        _buildMainTimingCard(timing),

        const SizedBox(height: AppDimensions.paddingMedium),

        _buildSavingsInfo(timing),

        if (timing.isFlightDelayed) ...[
          const SizedBox(height: AppDimensions.paddingMedium),
          _buildFlightDelayNotice(timing),
        ],
      ],
    );
  }

  Widget _buildMainTimingCard(AirportTiming timing) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(150),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Depart in:',
                style: AppStyles.bodyLarge.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
              Text(
                timing.formattedTimeToDepart,
                style: AppStyles.titleLarge.copyWith(
                  color: timing.shouldDepartNow
                      ? AppColors.error
                      : timing.isCritical
                      ? AppColors.warning
                      : AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingMedium),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Airport entry:',
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.textOnPrimary.withAlpha(200),
                ),
              ),
              Text(
                timing.formattedOptimalEntryTime,
                style: AppStyles.titleMedium.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.paddingSmall),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Travel time:',
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.textOnPrimary.withAlpha(200),
                ),
              ),
              Text(
                '${timing.travelTime.inMinutes} min',
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsInfo(AirportTiming timing) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(30),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(
            Icons.savings,
            color: AppColors.success,
            size: AppDimensions.iconSmall,
          ),
          const SizedBox(width: AppDimensions.paddingSmall),
          Expanded(
            child: Text(
              'Parking savings: ${timing.formattedSavings}',
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightDelayNotice(AirportTiming timing) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(30),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flight_land,
            color: AppColors.warning,
            size: AppDimensions.iconSmall,
          ),
          const SizedBox(width: AppDimensions.paddingSmall),
          Expanded(
            child: Text(
              'Flight delayed. Entry time recalculated.',
              style: AppStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    if (_airportTiming?.shouldDepartNow == true) {
      return AppColors.error.withAlpha(200);
    } else if (_airportTiming?.isCritical == true) {
      return AppColors.warning.withAlpha(200);
    } else {
      return AppColors.driverColor.withAlpha(200);
    }
  }
}
