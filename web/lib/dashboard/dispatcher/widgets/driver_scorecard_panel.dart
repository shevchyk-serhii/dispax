import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

class DriverScorecardPanel extends StatefulWidget {
  const DriverScorecardPanel({super.key});

  @override
  State<DriverScorecardPanel> createState() => _DriverScorecardPanelState();
}

class _DriverScorecardPanelState extends State<DriverScorecardPanel> {
  List<Map<String, dynamic>>? _data;
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'rides';

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
      final response = await apiClient.get('/stats/driver-performance');

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

  List<Map<String, dynamic>> get _sortedData {
    if (_data == null) return [];
    final sorted = List<Map<String, dynamic>>.from(_data!);
    switch (_sortBy) {
      case 'rides':
        sorted.sort((a, b) => ((b['totalRides'] as num?) ?? 0).compareTo((a['totalRides'] as num?) ?? 0));
      case 'earnings':
        sorted.sort((a, b) => ((b['totalEarnings'] as num?) ?? 0).compareTo((a['totalEarnings'] as num?) ?? 0));
      case 'completion':
        sorted.sort((a, b) => ((b['completionRate'] as num?) ?? 0).compareTo((a['completionRate'] as num?) ?? 0));
      case 'rating':
        sorted.sort((a, b) => ((b['avgRating'] as num?) ?? 0).compareTo((a['avgRating'] as num?) ?? 0));
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
                          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
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
            const Icon(Icons.leaderboard, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Driver Performance',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Colors.white, size: 22),
              onSelected: (v) => setState(() => _sortBy = v),
              itemBuilder: (_) => [
                _buildSortItem('rides', 'Sort by Rides'),
                _buildSortItem('earnings', 'Sort by Earnings'),
                _buildSortItem('completion', 'Sort by Completion'),
                _buildSortItem('rating', 'Sort by Rating'),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadData,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortBy == value) const Icon(Icons.check, size: 16),
          if (_sortBy == value) const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final data = _sortedData;
    final colorScheme = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 56, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('No driver performance data', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final totalDrivers = data.length;
    final totalRides = data.fold<num>(0, (s, d) => s + ((d['totalRides'] as num?) ?? 0));
    final totalEarnings = data.fold<num>(0, (s, d) => s + ((d['totalEarnings'] as num?) ?? 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Row(
          children: [
            _buildSummaryCard('Drivers', totalDrivers.toString(), AppColors.driverColor, colorScheme),
            const SizedBox(width: 12),
            _buildSummaryCard('Rides', totalRides.toString(), AppColors.primary, colorScheme),
            const SizedBox(width: 12),
            _buildSummaryCard('Earnings', '\u20AC${totalEarnings.toStringAsFixed(0)}', AppColors.success, colorScheme),
          ],
        ),
        const SizedBox(height: 16),

        // Driver cards
        ...data.map((driver) {
          final name = driver['driverName'] as String? ?? 'Unknown';
          final rides = (driver['totalRides'] as num?) ?? 0;
          final earnings = (driver['totalEarnings'] as num?) ?? 0;
          final completionRate = (driver['completionRate'] as num?)?.toDouble() ?? 0;
          final onTimeRate = (driver['onTimeRate'] as num?)?.toDouble() ?? 0;
          final avgEarnings = rides > 0 ? earnings / rides : 0;

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
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.driverColor.withAlpha(30),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: AppColors.driverColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Text(
                      '\u20AC${earnings.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Completion rate bar
                Row(
                  children: [
                    SizedBox(width: 80, child: Text('Completion', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completionRate / 100,
                          backgroundColor: colorScheme.surfaceContainerLow,
                          color: completionRate >= 90 ? AppColors.success
                              : completionRate >= 70 ? AppColors.warning
                              : AppColors.error,
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${completionRate.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMiniStat('Rides', rides.toString(), AppColors.primary, colorScheme),
                    const SizedBox(width: 16),
                    _buildMiniStat('Avg/ride', '\u20AC${avgEarnings.toStringAsFixed(0)}', AppColors.success, colorScheme),
                    const SizedBox(width: 16),
                    _buildMiniStat('On-time', '${onTimeRate.toStringAsFixed(0)}%', AppColors.info, colorScheme),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, ColorScheme colorScheme) {
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
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, ColorScheme colorScheme) {
    return Row(
      children: [
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
