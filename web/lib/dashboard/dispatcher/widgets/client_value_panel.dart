import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/core/services/error_messages.dart';

class ClientValuePanel extends StatefulWidget {
  const ClientValuePanel({super.key});

  @override
  State<ClientValuePanel> createState() => _ClientValuePanelState();
}

class _ClientValuePanelState extends State<ClientValuePanel> {
  List<Map<String, dynamic>>? _data;
  bool _isLoading = true;
  Object? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/stats/client-value');

      if (response.statusCode == 200) {
        final data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        // Sort by total revenue descending
        data.sort(
          (a, b) => ((b['totalRevenue'] as num?) ?? 0).compareTo(
            (a['totalRevenue'] as num?) ?? 0,
          ),
        );
        _data = data;
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredData {
    final data = _data;
    if (data == null) return [];
    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return data;
    return data
        .where(
          (c) =>
              (c['clientName'] as String? ?? '').toLowerCase().contains(search),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      Text(friendlyError(_error, l10n)),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
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
              const Icon(Icons.diamond, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Client Lifetime Value',
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

    final data = _data;
    if (data == null || data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 56,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No client value data available',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final totalClients = data.length;
    final totalRevenue = data.fold<num>(
      0,
      (sum, c) => sum + ((c['totalRevenue'] as num?) ?? 0),
    );
    final avgValue = totalClients > 0 ? totalRevenue / totalClients : 0;
    final filtered = _filteredData;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary
        Row(
          children: [
            _buildSummaryCard(
              'Clients',
              totalClients.toString(),
              colorScheme.primary,
              colorScheme,
            ),
            const SizedBox(width: 12),
            _buildSummaryCard(
              'Total Rev.',
              '\u20AC${totalRevenue.toStringAsFixed(0)}',
              AppColors.success,
              colorScheme,
            ),
            const SizedBox(width: 12),
            _buildSummaryCard(
              'Avg Value',
              '\u20AC${avgValue.toStringAsFixed(0)}',
              colorScheme.primary,
              colorScheme,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search clients...',
            prefixIcon: Icon(Icons.search, size: 20),
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // Client table
        ...filtered.asMap().entries.map((entry) {
          final index = entry.key;
          final client = entry.value;
          final name = client['clientName'] as String? ?? 'Unknown';
          final rides = (client['totalRides'] as num?) ?? 0;
          final revenue = (client['totalRevenue'] as num?) ?? 0;
          final avgPrice = (client['avgRidePrice'] as num?) ?? 0;
          final firstRide = client['firstRideDate'] as String?;
          final lastRide = client['lastRideDate'] as String?;
          final isTop3 = index < 3;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isTop3
                  ? (isDark
                        ? AppColors.rideRequestedBgDark
                        : AppColors.warningBg)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTop3
                    ? AppColors.warning
                    : colorScheme.surfaceContainerHighest,
              ),
            ),
            child: Row(
              children: [
                if (isTop3)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colorScheme.onSurface.withAlpha(30),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$rides rides',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'avg \u20AC${avgPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (firstRide != null || lastRide != null)
                        Text(
                          '${firstRide != null ? _formatDate(firstRide) : '?'} - ${lastRide != null ? _formatDate(lastRide) : 'present'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '\u20AC${revenue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isTop3 ? AppColors.warningStrong : AppColors.success,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
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
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
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

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
