import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../modules/core/models/person.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<Person> _drivers = [];
  String? _selectedDriverId;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  Map<String, dynamic>? _payrollData;
  bool _isLoading = false;
  bool _isLoadingDrivers = true;
  String? _error;
  double _commissionPercent = 20.0;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/users/drivers');

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _drivers = data.map((e) => Person.fromJson(e)).toList();
          _isLoadingDrivers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDrivers = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadPayroll() async {
    if (_selectedDriverId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

      final response = await apiClient.get(
        '/stats/payroll?driverId=$_selectedDriverId&from=$fromStr&to=$toStr',
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _payrollData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load payroll data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _copyPayrollCsv() {
    if (_payrollData == null) return;

    final driverName =
        _drivers.where((d) => d.id == _selectedDriverId).firstOrNull?.name ??
        'Unknown';
    final totalRides = _payrollData!['totalRides'] ?? 0;
    final totalEarnings = (_payrollData!['totalEarnings'] ?? 0).toDouble();
    final totalExpenses = (_payrollData!['totalExpenses'] ?? 0).toDouble();
    final commission = totalEarnings * (_commissionPercent / 100);
    final netPay = totalEarnings - totalExpenses - commission;

    final csv = StringBuffer();
    csv.writeln('Payroll Report');
    csv.writeln('Driver,$driverName');
    csv.writeln(
      'Period,${DateFormat('dd.MM.yyyy').format(_fromDate)} - ${DateFormat('dd.MM.yyyy').format(_toDate)}',
    );
    csv.writeln('');
    csv.writeln('Metric,Value');
    csv.writeln('Total Rides,$totalRides');
    csv.writeln('Total Earnings,${totalEarnings.toStringAsFixed(2)} EUR');
    csv.writeln('Total Expenses,${totalExpenses.toStringAsFixed(2)} EUR');
    csv.writeln(
      'Commission (${_commissionPercent.toStringAsFixed(0)}%),${commission.toStringAsFixed(2)} EUR',
    );
    csv.writeln('Net Pay,${netPay.toStringAsFixed(2)} EUR');

    Clipboard.setData(ClipboardData(text: csv.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payroll CSV copied to clipboard'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
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
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Driver Payroll',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_payrollData != null)
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white, size: 22),
                  onPressed: _copyPayrollCsv,
                  tooltip: 'Copy CSV',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingDrivers) {
      return Center(child: CircularProgressIndicator.adaptive());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver picker
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Select Driver'),
            initialValue: _selectedDriverId,
            items: _drivers
                .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                .toList(),
            onChanged: (v) => setState(() => _selectedDriverId = v),
          ),
          const SizedBox(height: AppDimensions.paddingMedium),

          // Date range
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'From'),
                    child: Text(DateFormat('dd.MM.yyyy').format(_fromDate)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'To'),
                    child: Text(DateFormat('dd.MM.yyyy').format(_toDate)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingMedium),

          // Commission slider
          Row(
            children: [
              const Text(
                'Commission: ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: Slider(
                  value: _commissionPercent,
                  min: 0,
                  max: 50,
                  divisions: 50,
                  label: '${_commissionPercent.toStringAsFixed(0)}%',
                  onChanged: (v) => setState(() => _commissionPercent = v),
                ),
              ),
              Text(
                '${_commissionPercent.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingMedium),

          // Load button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedDriverId != null ? _loadPayroll : null,
              icon: const Icon(Icons.search),
              label: const Text('Load Payroll'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dispatcherColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingLarge),

          if (_isLoading) Center(child: CircularProgressIndicator.adaptive()),

          if (_error != null)
            Center(
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),

          if (_payrollData != null && !_isLoading) _buildPayrollSummary(),
        ],
      ),
    );
  }

  Widget _buildPayrollSummary() {
    final totalRides = _payrollData!['totalRides'] ?? 0;
    final totalEarnings = (_payrollData!['totalEarnings'] ?? 0).toDouble();
    final totalExpenses = (_payrollData!['totalExpenses'] ?? 0).toDouble();
    final commission = totalEarnings * (_commissionPercent / 100);
    final netPay = totalEarnings - totalExpenses - commission;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payroll Summary',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildStatRow(
          'Total Rides',
          '$totalRides',
          Icons.directions_car,
          Theme.of(context).colorScheme.primary,
        ),
        _buildStatRow(
          'Total Earnings',
          '${totalEarnings.toStringAsFixed(2)} EUR',
          Icons.trending_up,
          AppColors.success,
        ),
        _buildStatRow(
          'Total Expenses',
          '${totalExpenses.toStringAsFixed(2)} EUR',
          Icons.trending_down,
          AppColors.error,
        ),
        _buildStatRow(
          'Commission (${_commissionPercent.toStringAsFixed(0)}%)',
          '${commission.toStringAsFixed(2)} EUR',
          Icons.percent,
          AppColors.warning,
        ),
        const Divider(thickness: 2),
        _buildStatRow(
          'Net Pay',
          '${netPay.toStringAsFixed(2)} EUR',
          Icons.account_balance_wallet,
          netPay >= 0 ? AppColors.success : AppColors.error,
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
