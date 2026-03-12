import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../modules/ride_management/models/ride.dart';
import '../modules/ride_management/services/ride_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Ride> _rides = [];
  bool _isLoading = true;
  String? _error;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
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

  List<Ride> get _monthlyRides {
    return _rides.where((r) {
      return r.pickupDateTime.year == _selectedMonth.year &&
          r.pickupDateTime.month == _selectedMonth.month &&
          r.status == RideStatus.completed;
    }).toList()
      ..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
  }

  Map<String, List<Ride>> get _groupedByClient {
    final grouped = <String, List<Ride>>{};
    for (final ride in _monthlyRides) {
      final key = ride.clientName;
      grouped.putIfAbsent(key, () => []).add(ride);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length)),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  String _generateInvoiceCsv(String clientName, List<Ride> rides) {
    final buffer = StringBuffer();
    final month = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

    buffer.writeln('Invoice for $clientName - $month');
    buffer.writeln('');
    buffer.writeln('Date,From,To,Driver,Price');

    double total = 0;
    for (final ride in rides) {
      final date = '${ride.pickupDateTime.day}.${ride.pickupDateTime.month}.${ride.pickupDateTime.year}';
      final from = ride.from.address.replaceAll(',', ';');
      final to = ride.to.address.replaceAll(',', ';');
      final price = ride.price ?? 0;
      total += price;
      buffer.writeln('$date,$from,$to,${ride.driverName ?? ''},$price');
    }

    buffer.writeln('');
    buffer.writeln('Total,,,,${total.toStringAsFixed(2)}');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedByClient;
    final totalRevenue = _monthlyRides.fold<double>(0, (sum, r) => sum + (r.price ?? 0));
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthLabel = '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Column(
      children: [
        _buildHeader(),
        _buildMonthSelector(monthLabel),
        if (!_isLoading && _error == null)
          _buildMonthlySummary(grouped.length, _monthlyRides.length, totalRevenue),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 12),
                          Text(_error!),
                          ElevatedButton(onPressed: _loadRides, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : grouped.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('No completed rides in $monthLabel',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRides,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: grouped.length,
                            itemBuilder: (context, index) {
                              final entry = grouped.entries.elementAt(index);
                              return _buildClientInvoiceCard(entry.key, entry.value);
                            },
                          ),
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
            const Icon(Icons.receipt_long, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Billing & Invoices',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadRides,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(String monthLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              monthLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(int clients, int rides, double revenue) {
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
          _buildSummaryItem('Clients', '$clients', Icons.person),
          _buildSummaryItem('Rides', '$rides', Icons.directions_car),
          _buildSummaryItem('Revenue', '\u20AC${revenue.toStringAsFixed(0)}', Icons.euro),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.success),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildClientInvoiceCard(String clientName, List<Ride> rides) {
    final total = rides.fold<double>(0, (sum, r) => sum + (r.price ?? 0));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.clientColor.withAlpha(30),
          child: Text(
            clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.clientColor),
          ),
        ),
        title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${rides.length} rides'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u20AC${total.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copy invoice CSV',
              onPressed: () {
                final csv = _generateInvoiceCsv(clientName, rides);
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invoice for $clientName copied to clipboard')),
                );
              },
            ),
          ],
        ),
        children: rides.map((ride) {
          final date = '${ride.pickupDateTime.day}.${ride.pickupDateTime.month}';
          final time = '${ride.pickupDateTime.hour.toString().padLeft(2, '0')}:${ride.pickupDateTime.minute.toString().padLeft(2, '0')}';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text('$date $time', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${ride.from.address} \u2192 ${ride.to.address}',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  ride.price != null ? '\u20AC${ride.price!.toStringAsFixed(2)}' : '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _rideService.dispose();
    super.dispose();
  }
}
