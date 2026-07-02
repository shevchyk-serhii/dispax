import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_styles.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../modules/billing/csv_download_stub.dart'
    if (dart.library.html) '../modules/billing/csv_download_web.dart';
import '../modules/core/services/error_messages.dart';
import '../dashboard/superadmin/widgets/billing_widgets.dart';
import '../modules/core/services/api_client.dart';

class DatevExportScreen extends StatefulWidget {
  const DatevExportScreen({super.key});

  @override
  State<DatevExportScreen> createState() => _DatevExportScreenState();
}

class _DatevExportScreenState extends State<DatevExportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = false;
  bool _isDownloading = false;
  Object? _error;
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
          _error = ApiException(
            'Server error',
            statusCode: response.statusCode,
          );
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
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
  double get _netIncome => (_summary['netIncome'] as num?)?.toDouble() ?? 0;
  List<Map<String, dynamic>> get _summaryLines =>
      (_summary['lines'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  bool get _hasData => _data != null && (_revenueRows > 0 || _expensesRows > 0);

  // --- Clipboard ---

  void _copyToClipboard(String text, String label) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard(label))));
    }
  }

  void _copyAll() {
    final l10n = AppLocalizations.of(context)!;
    final buffer = StringBuffer();
    buffer.writeln(l10n.copyAllRevenueHeader);
    buffer.writeln(_revenueCsv);
    buffer.writeln();
    buffer.writeln(l10n.copyAllExpensesHeader);
    buffer.writeln(_expensesCsv);
    buffer.writeln();
    buffer.writeln(l10n.copyAllSummaryHeader);
    buffer.writeln(_summaryCsv);
    _copyToClipboard(buffer.toString(), l10n.allDatevDataLabel);
  }

  Future<void> _downloadExtf() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isDownloading = true);
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get(
        '/export/datev/extf?month=$_monthParam',
      );
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final filename = 'EXTF_Buchungsstapel_$_monthParam.csv';
        triggerCsvDownload(Uint8List.fromList(bytes), filename);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                friendlyError(
                  ApiException('download', statusCode: response.statusCode),
                  l10n,
                ),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, l10n)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final monthNames = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    final monthLabel =
        '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Column(
      children: [
        BillingTopBar(
          title: l10n.datevExportTitle,
          subtitle: monthLabel,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadData,
            ),
          ],
        ),
        _buildMonthSelector(monthLabel),
        Expanded(child: _buildBody(monthLabel)),
      ],
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
              color: Theme.of(context).colorScheme.primary.withAlpha(15),
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

  Widget _buildBody(String monthLabel) {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(error, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    if (!_hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noDataForMonth(monthLabel),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
        ),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withAlpha(30),
          child: const Icon(Icons.trending_up, color: AppColors.success),
        ),
        title: Text(
          l10n.revenueSection,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(l10n.rowsCountLabel(_revenueRows)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fmtEur(_revenueAmount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: l10n.copyCsvTooltip,
              onPressed: () =>
                  _copyToClipboard(_revenueCsv, l10n.revenueCsvLabel),
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
        ),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.error.withAlpha(30),
          child: const Icon(Icons.trending_down, color: AppColors.error),
        ),
        title: Text(
          l10n.expensesSection,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(l10n.rowsCountLabel(_expensesRows)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fmtEur(_expensesAmount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: l10n.copyCsvTooltip,
              onPressed: () =>
                  _copyToClipboard(_expensesCsv, l10n.expensesCsvLabel),
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
        ),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.info.withAlpha(30),
          child: const Icon(Icons.summarize, color: AppColors.info),
        ),
        title: Text(
          l10n.summarySection,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          l10n.netIncomeResult(fmtEur(_netIncome)),
          style: TextStyle(
            color: _netIncome >= 0 ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: l10n.copySummaryCsvTooltip,
          onPressed: () => _copyToClipboard(_summaryCsv, l10n.summaryCsvLabel),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                for (final line in _summaryLines) _buildSummaryLine(line),
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
            fmtEur(amount),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNetIncomeLine() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.netIncomeLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_netIncome >= 0 ? AppColors.success : AppColors.error)
                  .withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fmtEur(_netIncome),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _netIncome >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Bar ---

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context)!;
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
            Row(
              children: [
                Expanded(
                  child: BillingOutlinedButton(
                    onPressed: _copyAll,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copy_all, size: 16),
                        const SizedBox(width: 6),
                        Text(l10n.copyAllButton),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: _isDownloading ? null : _downloadExtf,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download, size: 16),
                      label: Text(l10n.downloadCsvExtfButton),
                      style: AppStyles.accentButtonStyle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.datevExtfFormatInfo,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
