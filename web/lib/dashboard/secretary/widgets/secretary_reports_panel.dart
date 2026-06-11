import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_styles.dart';

class SecretaryReportsPanel extends StatefulWidget {
  const SecretaryReportsPanel({super.key});

  @override
  State<SecretaryReportsPanel> createState() => _SecretaryReportsPanelState();
}

class _SecretaryReportsPanelState extends State<SecretaryReportsPanel> {
  Map<String, dynamic>? _stats;
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

      if (statsResponse.statusCode == 200) {
        _stats = jsonDecode(statsResponse.body);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports', style: AppStyles.titleLarge.copyWith(color: AppColors.textOnPrimary)),
        backgroundColor: AppColors.secretaryColor,
        foregroundColor: AppColors.textOnPrimary,
        elevation: AppDimensions.appBarElevation,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!, style: AppStyles.bodyMedium),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadStats, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: _buildContent(),
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
    final clients = (stats['totalClients'] ?? 0) as num;
    final cancelRate = total > 0 ? (cancelled / total * 100) : 0;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      children: [
        // Overview cards
        Row(
          children: [
            _buildStatCard('Total Rides', total.toString(), Icons.directions_car, Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            _buildStatCard('Completed', completed.toString(), Icons.check_circle, AppColors.success),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard('In Progress', inProgress.toString(), Icons.play_circle, AppColors.rideInProgress),
            const SizedBox(width: 12),
            _buildStatCard('Requested', requested.toString(), Icons.pending, AppColors.rideRequested),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard('Assigned', assigned.toString(), Icons.assignment, AppColors.rideAssigned),
            const SizedBox(width: 12),
            _buildStatCard('Cancelled', cancelled.toString(), Icons.cancel, AppColors.error),
          ],
        ),

        const SizedBox(height: 24),

        // Key metrics
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Key Metrics', style: AppStyles.titleSmall),
              const SizedBox(height: 12),
              _buildMetricRow(
                'Cancellation Rate',
                '${cancelRate.toStringAsFixed(1)}%',
                cancelRate < 10 ? AppColors.success : cancelRate < 25 ? AppColors.warning : AppColors.error,
              ),
              _buildMetricRow('Total Clients', clients.toString(), AppColors.clientColor),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Status breakdown
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status Breakdown', style: AppStyles.titleSmall),
              const SizedBox(height: 16),
              if (total > 0) ...[
                _buildStatusBar('Completed', completed, total, AppColors.success),
                const SizedBox(height: 8),
                _buildStatusBar('In Progress', inProgress, total, AppColors.rideInProgress),
                const SizedBox(height: 8),
                _buildStatusBar('Assigned', assigned, total, AppColors.rideAssigned),
                const SizedBox(height: 8),
                _buildStatusBar('Requested', requested, total, AppColors.rideRequested),
                const SizedBox(height: 8),
                _buildStatusBar('Cancelled', cancelled, total, AppColors.error),
              ] else
                Center(
                  child: Text('No ride data yet', style: AppStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(label,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(String label, num value, num total, Color color) {
    final fraction = total > 0 ? value / total : 0.0;
    final percentage = (fraction * 100).toStringAsFixed(0);

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction.toDouble(),
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            '$value ($percentage%)',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
