import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';

class TodayStatsCard extends StatelessWidget {
  final List<Ride> todayRides;

  const TodayStatsCard({
    super.key,
    required this.todayRides,
  });

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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}