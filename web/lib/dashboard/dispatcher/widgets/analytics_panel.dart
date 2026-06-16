import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

class AnalyticsPanel extends StatefulWidget {
  const AnalyticsPanel({super.key});

  @override
  State<AnalyticsPanel> createState() => _AnalyticsPanelState();
}

class _AnalyticsPanelState extends State<AnalyticsPanel> {
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _dailyStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final statsResponse = await apiClient.get('/stats/rides');
      final dailyResponse = await apiClient.get('/stats/rides/daily?days=7');

      if (statsResponse.statusCode == 200) {
        _stats = jsonDecode(statsResponse.body);
      }
      if (dailyResponse.statusCode == 200) {
        _dailyStats = List<Map<String, dynamic>>.from(
          jsonDecode(dailyResponse.body),
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadStats,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(onRefresh: _loadStats, child: _buildContent()),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.dispatcherGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.analytics, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadStats,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_stats == null) return const SizedBox.shrink();

    final stats = _stats!;
    final total = (stats['totalRides'] ?? 0) as num;
    final completed = (stats['completedRides'] ?? 0) as num;
    final cancelled = (stats['cancelledRides'] ?? 0) as num;
    final inProgress = (stats['inProgressRides'] ?? 0) as num;
    final requested = (stats['requestedRides'] ?? 0) as num;
    final assigned = (stats['assignedRides'] ?? 0) as num;
    final drivers = (stats['activeDrivers'] ?? 0) as num;
    final clients = (stats['totalClients'] ?? 0) as num;
    final todayRev = (stats['todayRevenue'] ?? 0) as num;
    final monthlyRev = (stats['monthlyRevenue'] ?? 0) as num;
    final avgAssign = (stats['avgAssignmentMinutes'] ?? 0) as num;
    final cancelRate = total > 0 ? (cancelled / total * 100) : 0;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI cards - row 1
        Row(
          children: [
            _buildKpiCard(
              'Total Rides',
              total.toString(),
              Icons.directions_car,
              colorScheme.primary,
              colorScheme,
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              'Completed',
              completed.toString(),
              Icons.check_circle,
              AppColors.success,
              colorScheme,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildKpiCard(
              'In Progress',
              inProgress.toString(),
              Icons.play_circle,
              AppColors.rideInProgress,
              colorScheme,
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              'Requested',
              requested.toString(),
              Icons.pending,
              AppColors.rideRequested,
              colorScheme,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildKpiCard(
              'Assigned',
              assigned.toString(),
              Icons.assignment,
              AppColors.rideAssigned,
              colorScheme,
            ),
            const SizedBox(width: 12),
            _buildKpiCard(
              'Cancelled',
              cancelled.toString(),
              Icons.cancel,
              AppColors.error,
              colorScheme,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Key metrics
        _buildMetricRow(
          'Cancellation Rate',
          '${cancelRate.toStringAsFixed(1)}%',
          cancelRate < 10
              ? AppColors.success
              : cancelRate < 25
              ? AppColors.warning
              : AppColors.error,
          colorScheme,
        ),
        _buildMetricRow(
          'Avg. Assignment Time',
          avgAssign > 0 ? '${avgAssign.toStringAsFixed(0)} min' : 'N/A',
          colorScheme.primary,
          colorScheme,
        ),
        _buildMetricRow(
          'Active Drivers',
          drivers.toString(),
          AppColors.driverColor,
          colorScheme,
        ),
        _buildMetricRow(
          'Total Clients',
          clients.toString(),
          AppColors.clientColor,
          colorScheme,
        ),

        const SizedBox(height: 20),

        // Revenue
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.success.withAlpha(30),
                AppColors.success.withAlpha(10),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Revenue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRevenueItem(
                    'Today',
                    '\u20AC${todayRev.toStringAsFixed(0)}',
                    colorScheme,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: colorScheme.outlineVariant,
                  ),
                  _buildRevenueItem(
                    'Month',
                    '\u20AC${monthlyRev.toStringAsFixed(0)}',
                    colorScheme,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Daily chart
        if (_dailyStats != null && _dailyStats!.isNotEmpty) ...[
          const Text(
            'Daily Overview (Last 7 Days)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDailyChart(colorScheme),
        ],
      ],
    );
  }

  Widget _buildKpiCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    Color color,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueItem(
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildDailyChart(ColorScheme colorScheme) {
    final days = _dailyStats!;
    final maxTotal = days
        .map((d) => (d['total'] as num?) ?? 0)
        .fold<num>(1, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        children: days.reversed.map((day) {
          final date = day['date'] as String? ?? '';
          final total = (day['total'] as num?) ?? 0;
          final completed = (day['completed'] as num?) ?? 0;
          final cancelled = (day['cancelled'] as num?) ?? 0;
          final fraction = maxTotal > 0 ? total / maxTotal : 0.0;
          final shortDate = date.length >= 10
              ? date.substring(5)
              : date; // MM-DD

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    shortDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fraction.toDouble(),
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                AppColors.primaryLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: Text(
                    '$total ($completed/$cancelled)',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
