import 'package:flutter/material.dart';
import '../../ride_management/models/ride.dart';

class TodayStatsCard extends StatelessWidget {
  final List<Ride> todayRides;

  const TodayStatsCard({
    Key? key,
    required this.todayRides,
  }) : super(key: key);

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

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.event,
                count: todayRides.length,
                label: 'Total',
                color: Colors.blue,
              ),
              _buildStatItem(
                icon: Icons.play_arrow,
                count: upcomingRides,
                label: 'Upcoming',
                color: Colors.orange,
              ),
              _buildStatItem(
                icon: Icons.directions_car,
                count: inProgressRides,
                label: 'Active',
                color: Colors.green,
              ),
              _buildStatItem(
                icon: Icons.check_circle,
                count: completedRides,
                label: 'Done',
                color: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}