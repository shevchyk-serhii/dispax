import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';

class DatevExportScreen extends StatefulWidget {
  const DatevExportScreen({super.key});

  @override
  State<DatevExportScreen> createState() => _DatevExportScreenState();
}

class _DatevExportScreenState extends State<DatevExportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _monthParam =>
      '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/export/datev?month=$_monthParam');

      if (response.statusCode == 200) {
        setState(() {
          _data = jsonDecode(response.body) as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    _loadData();
  }

  // --- Data accessors ---

  Map<String, dynamic> get _revenue =>
      (_data?['revenue'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _expenses =>
      (_data?['expenses'] as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _summary =>
      (_data?['summary'] as Map<String, dynamic>?) ?? {};

  String get _revenueCsv => _revenue['csv'] as String? ?? '';
  int get _revenueRows => _revenue['totalRows'] as int? ?? 0;
  double get _revenueAmount =>
      (_revenue['totalAmount'] as num?)?.toDouble() ?? 0;
  List<String> get _revenuePreview =>
      (_revenue['preview'] as List<dynamic>?)?.cast<String>() ?? [];

  String get _expensesCsv => _expenses['csv'] as String? ?? '';
  int get _expensesRows => _expenses['totalRows'] as int? ?? 0;
  double get _expensesAmount =>
      (_expenses['totalAmount'] as num?)?.toDouble() ?? 0;
  List<String> get _expensesPreview =>
      (_expenses['preview'] as List<dynamic>?)?.cast<String>() ?? [];

  String get _summaryCsv => _summary['csv'] as String? ?? '';
  double get _netIncome =>
      (_summary['netIncome'] as num?)?.toDouble() ?? 0;
  List<Map<String, dynamic>> get _summaryLines =>
      (_summary['lines'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>() ??
      [];

  bool get _hasData =>
      _data != null &&
      (_revenueRows > 0 || _expensesRows > 0);

  // --- Clipboard ---

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label in die Zwischenablage kopiert')),
      );
    }
  }

  void _copyAll() {
    final buffer = StringBuffer();
    buffer.writeln('=== Erl\u00f6se ===');
    buffer.writeln(_revenueCsv);
    buffer.writeln();
    buffer.writeln('=== Ausgaben ===');
    buffer.writeln(_expensesCsv);
    buffer.writeln();
    buffer.writeln('=== Zusammenfassung ===');
    buffer.writeln(_summaryCsv);
    _copyToClipboard(buffer.toString(), 'Alle DATEV-Daten');
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final monthNames = [
      'Jan', 'Feb', 'M\u00e4r', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
    ];
    final monthLabel =
        '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Column(
      children: [
        _buildHeader(),
        _buildMonthSelector(monthLabel),
        Expanded(child: _buildBody(monthLabel)),
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
            const Icon(Icons.account_balance, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'DATEV Export',
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
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildBody(String monthLabel) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Erneut versuchen')),
          ],
        ),
      );
    }

    if (!_hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Keine Daten f\u00fcr $monthLabel',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildRevenueSection(),
              const SizedBox(height: 10),
              _buildExpensesSection(),
              const SizedBox(height: 10),
              _buildSummarySection(),
            ],
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  // --- Revenue Section ---

  Widget _buildRevenueSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withAlpha(30),
          child: const Icon(Icons.trending_up, color: AppColors.success),
        ),
        title: const Text(
          'Erl\u00f6se',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$_revenueRows Zeilen'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u20AC${_revenueAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'CSV kopieren',
              onPressed: () => _copyToClipboard(_revenueCsv, 'Erl\u00f6se CSV'),
            ),
          ],
        ),
        children: [
          if (_revenuePreview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _revenuePreview.take(5).join('\n'),
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Expenses Section ---

  Widget _buildExpensesSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.error.withAlpha(30),
          child: const Icon(Icons.trending_down, color: AppColors.error),
        ),
        title: const Text(
          'Ausgaben',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$_expensesRows Zeilen'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u20AC${_expensesAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'CSV kopieren',
              onPressed: () =>
                  _copyToClipboard(_expensesCsv, 'Ausgaben CSV'),
            ),
          ],
        ),
        children: [
          if (_expensesPreview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _expensesPreview.take(5).join('\n'),
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Summary Section ---

  Widget _buildSummarySection() {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.info.withAlpha(30),
          child: const Icon(Icons.summarize, color: AppColors.info),
        ),
        title: const Text(
          'Zusammenfassung',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Ergebnis: \u20AC${_netIncome.toStringAsFixed(2)}',
          style: TextStyle(
            color: _netIncome >= 0 ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: 'Zusammenfassung kopieren',
          onPressed: () =>
              _copyToClipboard(_summaryCsv, 'Zusammenfassung'),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                for (final line in _summaryLines)
                  _buildSummaryLine(line),
                const Divider(),
                _buildNetIncomeLine(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(Map<String, dynamic> line) {
    final label = line['label'] as String? ?? '';
    final amount = (line['amount'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            '\u20AC${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNetIncomeLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Ergebnis (Netto)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_netIncome >= 0 ? AppColors.success : AppColors.error)
                  .withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '\u20AC${_netIncome.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color:
                    _netIncome >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Bar ---

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _copyAll,
                icon: const Icon(Icons.copy_all),
                label: const Text('Alles kopieren'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'DATEV Buchungsstapel Format \u2013 Import via DATEV Unternehmen Online',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outlineVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
