import 'package:flutter/material.dart';
import '../models/ride.dart';
import '../../../utils/ride_status_styles.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/lucide_compat.dart';

class RideLifecycleStepperWidget extends StatefulWidget {
  final Ride ride;
  final bool isClientView;

  const RideLifecycleStepperWidget({
    super.key,
    required this.ride,
    this.isClientView = false,
  });

  @override
  State<RideLifecycleStepperWidget> createState() =>
      _RideLifecycleStepperWidgetState();
}

class _RideLifecycleStepperWidgetState extends State<RideLifecycleStepperWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Steps in order
  static const List<RideStatus> _steps = [
    RideStatus.requested,
    RideStatus.assigned,
    RideStatus.inProgress,
    RideStatus.completed,
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Returns the index of the current (active) step, or -1 if cancelled.
  int get _currentStepIndex {
    if (widget.ride.status == RideStatus.cancelled) return -1;
    return _steps.indexOf(widget.ride.status);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isCancelled = widget.ride.status == RideStatus.cancelled;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: AppStyles.primaryCardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ride Status',
            style: AppStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          if (isCancelled)
            _buildCancelledIndicator(brightness)
          else
            ..._buildStepList(brightness),
        ],
      ),
    );
  }

  Widget _buildCancelledIndicator(Brightness brightness) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.rideCancelled,
          ),
          child: const Icon(LucideCompat.x, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancelled',
              style: AppStyles.labelLarge.copyWith(
                color: AppColors.rideCancelled,
              ),
            ),
            Text('This ride has been cancelled', style: AppStyles.bodySmall),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildStepList(Brightness brightness) {
    final widgets = <Widget>[];
    for (int i = 0; i < _steps.length; i++) {
      final status = _steps[i];
      final isCurrent = i == _currentStepIndex;
      final isCompleted = i < _currentStepIndex;

      widgets.add(_buildStep(status, isCurrent, isCompleted, brightness));

      if (i < _steps.length - 1) {
        widgets.add(_buildConnector(isCompleted));
      }
    }
    return widgets;
  }

  Widget _buildStep(
    RideStatus status,
    bool isCurrent,
    bool isCompleted,
    Brightness brightness,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildStepDot(status, isCurrent, isCompleted, brightness),
        const SizedBox(width: 12),
        Expanded(child: _buildStepLabel(status, isCurrent, isCompleted)),
      ],
    );
  }

  Widget _buildStepDot(
    RideStatus status,
    bool isCurrent,
    bool isCompleted,
    Brightness brightness,
  ) {
    if (isCompleted) {
      final bgColor = RideStatusStyles.getStatusColor(status);
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
        child: const Icon(LucideCompat.check, color: Colors.white, size: 12),
      );
    }

    if (isCurrent) {
      final dotColor = RideStatusStyles.getStatusColor(status);
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, child) =>
            Transform.scale(scale: _pulseAnimation.value, child: child),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }

    // Pending step
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderPrimary, width: 2),
      ),
    );
  }

  Widget _buildStepLabel(RideStatus status, bool isCurrent, bool isCompleted) {
    final labelColor = isCurrent
        ? RideStatusStyles.getStatusColor(status)
        : isCompleted
        ? AppColors.textSecondary
        : AppColors.textLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RideStatusStyles.getStatusDisplayName(status),
          style: AppStyles.labelLarge.copyWith(
            color: labelColor,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        if (isCurrent)
          Text(_getStatusSubLabel(status), style: AppStyles.bodySmall),
      ],
    );
  }

  Widget _buildConnector(bool isCompleted) {
    return Container(
      width: 2,
      height: 16,
      margin: const EdgeInsets.only(left: 9),
      color: isCompleted ? AppColors.accent : AppColors.borderPrimary,
    );
  }

  String _getStatusSubLabel(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return widget.isClientView
            ? 'Waiting for driver assignment'
            : 'Awaiting assignment';
      case RideStatus.assigned:
        return widget.isClientView
            ? (widget.ride.driverEnRoute
                  ? 'Driver is on the way'
                  : 'Driver assigned')
            : 'You are assigned to this ride';
      case RideStatus.confirmed:
        return widget.isClientView
            ? 'Driver confirmed your ride'
            : 'You confirmed this ride';
      case RideStatus.inProgress:
        return widget.isClientView ? 'Ride in progress' : 'Drive safely';
      case RideStatus.completed:
        return 'Completed successfully';
      case RideStatus.cancelled:
        return 'Ride cancelled';
      case RideStatus.handedOff:
        return 'Handed off to partner';
    }
  }
}
