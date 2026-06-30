import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../constants/app_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/core/services/error_messages.dart';

class SecretaryReportsPanel extends StatefulWidget {
  const SecretaryReportsPanel({super.key});

  @override
  State<SecretaryReportsPanel> createState() => _SecretaryReportsPanelState();
}

class _SecretaryReportsPanelState extends State<SecretaryReportsPanel> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  Object? _error;

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
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Graphite header
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMedium,
              vertical: 14,
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.reportsTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _loadStats,
                    tooltip: l10n.refresh,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator.adaptive());
    }
    final error = _error == null ? null : friendlyError(_error, l10n);
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              error,
              style: AppStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadStats, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    return RefreshIndicator(onRefresh: _loadStats, child: _buildContent());
  }

  Widget _buildContent() {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
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
        // Overview stat tiles — 2 rows of 2
        Row(
          children: [
            _buildStatTile(
              l10n.totalRidesLabel,
              total.toString(),
              Icons.directions_car,
              Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            _buildStatTile(
              l10n.completed,
              completed.toString(),
              Icons.check_circle,
              AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatTile(
              l10n.inProgressLabel,
              inProgress.toString(),
              Icons.play_circle,
              AppColors.rideInProgress,
            ),
            const SizedBox(width: 10),
            _buildStatTile(
              l10n.requestedLabel,
              requested.toString(),
              Icons.pending,
              AppColors.rideRequested,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatTile(
              l10n.assignedLabel,
              assigned.toString(),
              Icons.assignment,
              AppColors.rideAssigned,
            ),
            const SizedBox(width: 10),
            _buildStatTile(
              l10n.cancelled,
              cancelled.toString(),
              Icons.cancel,
              AppColors.error,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Key metrics card
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: AppStyles.primaryCardDecorationOf(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.keyMetrics,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetricRow(
                l10n.cancellationRateLabel,
                '${cancelRate.toStringAsFixed(1)}%',
                cancelRate < 10
                    ? AppColors.success
                    : cancelRate < 25
                    ? AppColors.warning
                    : AppColors.error,
              ),
              _buildMetricRow(
                l10n.totalClients,
                clients.toString(),
                AppColors.accent,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Status breakdown card
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: AppStyles.primaryCardDecorationOf(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.statusBreakdown,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              if (total > 0) ...[
                _buildStatusBar(
                  l10n.completed,
                  completed,
                  total,
                  AppColors.success,
                ),
                const SizedBox(height: 8),
                _buildStatusBar(
                  l10n.inProgressLabel,
                  inProgress,
                  total,
                  AppColors.rideInProgress,
                ),
                const SizedBox(height: 8),
                _buildStatusBar(
                  l10n.assignedLabel,
                  assigned,
                  total,
                  AppColors.rideAssigned,
                ),
                const SizedBox(height: 8),
                _buildStatusBar(
                  l10n.requestedLabel,
                  requested,
                  total,
                  AppColors.rideRequested,
                ),
                const SizedBox(height: 8),
                _buildStatusBar(
                  l10n.cancelled,
                  cancelled,
                  total,
                  AppColors.error,
                ),
              ] else
                Center(
                  child: Text(
                    l10n.noRideDataYet,
                    style: AppStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowXs,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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

  Widget _buildStatusBar(String label, num value, num total, Color color) {
    final fraction = total > 0 ? value / total : 0.0;
    final percentage = (fraction * 100).toStringAsFixed(0);

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          width: 54,
          child: Text(
            '$value ($percentage%)',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
