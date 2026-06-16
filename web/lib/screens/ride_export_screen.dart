import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../modules/ride_management/models/ride.dart';
import '../modules/ride_management/services/ride_service.dart';

class RideExportScreen extends StatefulWidget {
  const RideExportScreen({super.key});

  @override
  State<RideExportScreen> createState() => _RideExportScreenState();
}

class _RideExportScreenState extends State<RideExportScreen> {
  List<Ride> _rides = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'All';
  DateTimeRange? _dateRange;
  late RideService _rideService;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthBloc>().apiClient;
    _rideService = RideService(apiClient: apiClient);
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rides = await _rideService.getAllRides();
      setState(() {
        _rides = rides;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<Ride> get _filteredRides {
    var filtered = _rides;

    if (_filterStatus != 'All') {
      filtered = filtered
          .where((r) => r.status.value == _filterStatus)
          .toList();
    }

    if (_dateRange != null) {
      filtered = filtered.where((r) {
        return r.pickupDateTime.isAfter(_dateRange!.start) &&
            r.pickupDateTime.isBefore(
              _dateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    filtered.sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime));
    return filtered;
  }

  String _generateCsv() {
    final rides = _filteredRides;
    final buffer = StringBuffer();

    buffer.writeln('ID,Date,Client,From,To,Status,Driver,Price');

    for (final ride in rides) {
      final date =
          '${ride.pickupDateTime.year}-${ride.pickupDateTime.month.toString().padLeft(2, '0')}-${ride.pickupDateTime.day.toString().padLeft(2, '0')}';
      final from = ride.from.address.replaceAll(',', ';');
      final to = ride.to.address.replaceAll(',', ';');
      final price = ride.price?.toStringAsFixed(2) ?? '';

      buffer.writeln(
        '${ride.id},$date,${ride.clientName},$from,$to,${ride.status.value},${ride.driverName ?? ''},$price',
      );
    }

    return buffer.toString();
  }

  Future<void> _exportCsv() async {
    final csv = _generateCsv();

    await Clipboard.setData(ClipboardData(text: csv));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'CSV data copied to clipboard (${_filteredRides.length} rides)',
          ),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRides;
    final totalRevenue = filtered.fold<double>(
      0,
      (sum, r) => sum + (r.price ?? 0),
    );
    final completedCount = filtered
        .where((r) => r.status == RideStatus.completed)
        .length;

    return Column(
      children: [
        _buildHeader(),
        _buildFilters(),
        _buildSummary(filtered.length, completedCount, totalRevenue),
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
                      ElevatedButton(
                        onPressed: _loadRides,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : filtered.isEmpty
              ? const Center(child: Text('No rides match the filters'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildRideRow(filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.dispatcherGradient),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.download, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Export Rides',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _filteredRides.isNotEmpty ? _exportCsv : null,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy CSV'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withAlpha(40),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadRides,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _filterStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: [
                'All',
                'Requested',
                'Assigned',
                'InProgress',
                'Completed',
                'Cancelled',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _filterStatus = v);
              },
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(
              _dateRange != null
                  ? '${_dateRange!.start.day}.${_dateRange!.start.month} - ${_dateRange!.end.day}.${_dateRange!.end.month}'
                  : 'Date Range',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => setState(() => _dateRange = null),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(int total, int completed, double revenue) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total', '$total', Icons.list),
          _buildSummaryItem('Completed', '$completed', Icons.check_circle),
          _buildSummaryItem(
            'Revenue',
            '\u20AC${revenue.toStringAsFixed(0)}',
            Icons.euro,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.success),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRideRow(Ride ride) {
    final date =
        '${ride.pickupDateTime.day}.${ride.pickupDateTime.month}.${ride.pickupDateTime.year}';
    final time =
        '${ride.pickupDateTime.hour.toString().padLeft(2, '0')}:${ride.pickupDateTime.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.clientName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${ride.from.address} \u2192 ${ride.to.address}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(ride.status).withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ride.status.value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _statusColor(ride.status),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: Text(
                ride.price != null
                    ? '\u20AC${ride.price!.toStringAsFixed(0)}'
                    : '-',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.rideRequested;
      case RideStatus.assigned:
        return AppColors.rideAssigned;
      case RideStatus.inProgress:
        return AppColors.rideInProgress;
      case RideStatus.completed:
        return AppColors.rideCompleted;
      case RideStatus.cancelled:
        return AppColors.rideCancelled;
    }
  }

  @override
  void dispose() {
    _rideService.dispose();
    super.dispose();
  }
}
