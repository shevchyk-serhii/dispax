import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

class DriverEarningsPanel extends StatefulWidget {
  const DriverEarningsPanel({super.key});

  @override
  State<DriverEarningsPanel> createState() => _DriverEarningsPanelState();
}

class _DriverEarningsPanelState extends State<DriverEarningsPanel> {
  List<Map<String, dynamic>>? _driverStats;
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'earnings'; // earnings, rides, name

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
      final response = await apiClient.get('/stats/drivers');

      if (response.statusCode == 200) {
        _driverStats = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _sortedStats {
    if (_driverStats == null) return [];
    final sorted = List<Map<String, dynamic>>.from(_driverStats!);
    switch (_sortBy) {
      case 'earnings':
        sorted.sort((a, b) => ((b['earnings'] as num?) ?? 0).compareTo((a['earnings'] as num?) ?? 0));
      case 'rides':
        sorted.sort((a, b) => ((b['totalRides'] as num?) ?? 0).compareTo((a['totalRides'] as num?) ?? 0));
      case 'name':
        sorted.sort((a, b) => (a['driverName'] as String? ?? '').compareTo(b['driverName'] as String? ?? ''));
    }
    return sorted;
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
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text(_error!),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadStats, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadStats,
                      child: _buildContent(),
                    ),
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
            const Icon(Icons.euro, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Driver Earnings',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Colors.white, size: 22),
              onSelected: (v) => setState(() => _sortBy = v),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'earnings',
                  child: Row(
                    children: [
                      if (_sortBy == 'earnings') const Icon(Icons.check, size: 16),
                      if (_sortBy == 'earnings') const SizedBox(width: 8),
                      const Text('Sort by Earnings'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rides',
                  child: Row(
                    children: [
                      if (_sortBy == 'rides') const Icon(Icons.check, size: 16),
                      if (_sortBy == 'rides') const SizedBox(width: 8),
                      const Text('Sort by Rides'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'name',
                  child: Row(
                    children: [
                      if (_sortBy == 'name') const Icon(Icons.check, size: 16),
                      if (_sortBy == 'name') const SizedBox(width: 8),
                      const Text('Sort by Name'),
                    ],
                  ),
                ),
              ],
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
    final stats = _sortedStats;
    final colorScheme = Theme.of(context).colorScheme;

    if (stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 56, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('No driver data available', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final totalEarnings = stats.fold<num>(0, (sum, s) => sum + ((s['earnings'] as num?) ?? 0));
    final totalRides = stats.fold<num>(0, (sum, s) => sum + ((s['totalRides'] as num?) ?? 0));
    final maxEarnings = stats.fold<num>(0, (max, s) {
      final e = (s['earnings'] as num?) ?? 0;
      return e > max ? e : max;
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    Text(
                      '\u20AC${totalEarnings.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                    const SizedBox(height: 4),
                    Text('Total Earnings', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    Text(
                      '$totalRides',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text('Total Rides', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Per-driver cards
        ...stats.map((driver) {
          final name = driver['driverName'] as String? ?? 'Unknown';
          final earnings = (driver['earnings'] as num?) ?? 0;
          final total = (driver['totalRides'] as num?) ?? 0;
          final completed = (driver['completedRides'] as num?) ?? 0;
          final cancelled = (driver['cancelledRides'] as num?) ?? 0;
          final fraction = maxEarnings > 0 ? earnings / maxEarnings : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.surfaceContainerHighest),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.driverColor.withAlpha(30),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: AppColors.driverColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Text(
                      '\u20AC${earnings.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Earnings bar
                Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction.toDouble(),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.success, AppColors.success.withAlpha(180)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniStat('Total', total.toString(), colorScheme.primary, colorScheme),
                    const SizedBox(width: 16),
                    _buildMiniStat('Done', completed.toString(), AppColors.success, colorScheme),
                    const SizedBox(width: 16),
                    _buildMiniStat('Cancelled', cancelled.toString(), AppColors.error, colorScheme),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, ColorScheme colorScheme) {
    return Row(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
