import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';

class TodayStatsCard extends StatelessWidget {
  final List<Ride> todayRides;

  const TodayStatsCard({super.key, required this.todayRides});

  @override
  Widget build(BuildContext context) {
    final completedRides = todayRides
        .where((r) => r.status == RideStatus.completed)
        .length;
    final upcomingRides = todayRides
        .where((r) => r.status == RideStatus.assigned)
        .length;
    final inProgressRides = todayRides
        .where((r) => r.status == RideStatus.inProgress)
        .length;

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.primaryCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Overview',
            style: AppStyles.titleMedium.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: AppDimensions.paddingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context: context,
                icon: Icons.event,
                count: todayRides.length,
                label: 'Total',
                color: AppColors.info,
              ),
              _buildStatItem(
                context: context,
                icon: Icons.play_arrow,
                count: upcomingRides,
                label: 'Upcoming',
                color: AppColors.warning,
              ),
              _buildStatItem(
                context: context,
                icon: Icons.directions_car,
                count: inProgressRides,
                label: 'Active',
                color: AppColors.success,
              ),
              _buildStatItem(
                context: context,
                icon: Icons.check_circle,
                count: completedRides,
                label: 'Done',
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: Icon(icon, color: color, size: AppDimensions.iconLarge),
        ),
        const SizedBox(height: AppDimensions.paddingSmall),
        Text(
          count.toString(),
          style: AppStyles.displayLarge.copyWith(color: color),
        ),
        Text(
          label,
          style: AppStyles.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
