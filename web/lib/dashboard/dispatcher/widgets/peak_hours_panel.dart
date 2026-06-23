import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';

class PeakHoursPanel extends StatefulWidget {
  const PeakHoursPanel({super.key});

  @override
  State<PeakHoursPanel> createState() => _PeakHoursPanelState();
}

class _PeakHoursPanelState extends State<PeakHoursPanel> {
  List<Map<String, dynamic>>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/stats/peak-hours?days=30');

      if (response.statusCode == 200) {
        _data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
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
              ? Center(child: CircularProgressIndicator.adaptive())
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
                      Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          return ElevatedButton(
                            onPressed: _loadData,
                            child: Text(l10n.retry),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(onRefresh: _loadData, child: _buildContent()),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.dispatcherGradient),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(
                Icons.access_time_filled,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Peak Hours Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_data == null || _data!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 56,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No peak hours data available',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Build heatmap grid: 7 days x 24 hours
    final grid = List.generate(7, (_) => List.filled(24, 0));
    int maxCount = 1;
    int totalRides = 0;
    int busiestDay = 0;
    int busiestHour = 0;
    int busiestDayCount = 0;
    int busiestHourCount = 0;

    for (final entry in _data!) {
      final day = (entry['dayOfWeek'] as num?)?.toInt() ?? 0;
      final hour = (entry['hour'] as num?)?.toInt() ?? 0;
      final count = (entry['count'] as num?)?.toInt() ?? 0;
      if (day >= 0 && day < 7 && hour >= 0 && hour < 24) {
        grid[day][hour] = count;
        totalRides += count;
        if (count > maxCount) maxCount = count;
      }
    }

    // Find busiest day and hour
    final dayCounts = List.filled(7, 0);
    final hourCounts = List.filled(24, 0);
    for (int d = 0; d < 7; d++) {
      for (int h = 0; h < 24; h++) {
        dayCounts[d] += grid[d][h];
        hourCounts[h] += grid[d][h];
      }
    }
    for (int d = 0; d < 7; d++) {
      if (dayCounts[d] > busiestDayCount) {
        busiestDayCount = dayCounts[d];
        busiestDay = d;
      }
    }
    for (int h = 0; h < 24; h++) {
      if (hourCounts[h] > busiestHourCount) {
        busiestHourCount = hourCounts[h];
        busiestHour = h;
      }
    }

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Row(
          children: [
            _buildSummaryCard(
              'Total Rides',
              totalRides.toString(),
              Icons.directions_car,
              colorScheme.primary,
              colorScheme,
            ),
            const SizedBox(width: 12),
            _buildSummaryCard(
              'Busiest Day',
              dayLabels[busiestDay],
              Icons.calendar_today,
              AppColors.warning,
              colorScheme,
            ),
            const SizedBox(width: 12),
            _buildSummaryCard(
              'Busiest Hour',
              '${busiestHour.toString().padLeft(2, '0')}:00',
              Icons.schedule,
              AppColors.error,
              colorScheme,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Heatmap
        const Text(
          'Ride Density Heatmap',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hour headers
              Row(
                children: [
                  const SizedBox(width: 40),
                  ...List.generate(
                    24,
                    (h) => SizedBox(
                      width: 28,
                      child: Text(
                        h.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 8,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Day rows
              ...List.generate(
                7,
                (d) => Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        dayLabels[d],
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...List.generate(24, (h) {
                      final count = grid[d][h];
                      final intensity = maxCount > 0 ? count / maxCount : 0.0;
                      return Tooltip(
                        message:
                            '${dayLabels[d]} ${h.toString().padLeft(2, '0')}:00 - $count rides',
                        child: Container(
                          width: 26,
                          height: 26,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: _heatmapColor(intensity, colorScheme),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: count > 0
                              ? Center(
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      fontSize: 7,
                                      color: intensity > 0.5
                                          ? Colors.white
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        // Color legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Less ',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            ...[0.0, 0.25, 0.5, 0.75, 1.0].map(
              (v) => Container(
                width: 20,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _heatmapColor(v, colorScheme),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              ' More',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _heatmapColor(double intensity, ColorScheme colorScheme) {
    if (intensity <= 0) return colorScheme.surfaceContainerLow;
    if (intensity < 0.25) return AppColors.infoBorder;
    if (intensity < 0.5) return AppColors.info;
    if (intensity < 0.75) return AppColors.infoStrong;
    return AppColors.errorStrong;
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
