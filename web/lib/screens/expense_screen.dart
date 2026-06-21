import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../modules/core/models/expense.dart';
import '../modules/core/services/expense_service.dart';
import '../dashboard/superadmin/widgets/billing_widgets.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String? _error;
  late ExpenseService _expenseService;

  /// Current month label derived at build time.
  String get _monthLabel {
    final now = DateTime.now();
    const months = [
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
    return '${months[now.month - 1]} ${now.year}';
  }

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthBloc>().apiClient;
    _expenseService = ExpenseService(apiClient: apiClient);
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final expenses = await _expenseService.getExpenses();
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showCreateExpenseDialog() async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    ExpenseCategory selectedCategory = ExpenseCategory.fuel;

    final result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ausgabe erfassen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie',
                    border: OutlineInputBorder(),
                  ),
                  items: ExpenseCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(
                            _categoryIcon(cat),
                            size: 20,
                            color: _categoryColor(cat),
                          ),
                          const SizedBox(width: 8),
                          Text(cat.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (cat) {
                    if (cat != null) {
                      setDialogState(() => selectedCategory = cat);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Betrag (EUR)',
                    border: OutlineInputBorder(),
                    prefixText: '€ ',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bitte gültigen Betrag eingeben'),
                    ),
                  );
                  return;
                }

                try {
                  await _expenseService.createExpense(
                    CreateExpenseRequest(
                      category:
                          selectedCategory.name.substring(0, 1).toUpperCase() +
                          selectedCategory.name.substring(1),
                      amount: amount,
                      description: descriptionController.text.isNotEmpty
                          ? descriptionController.text
                          : null,
                    ),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                  }
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadExpenses();
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ausgabe löschen?'),
        content: Text(
          '${expense.category.label} · €${expense.amount.toStringAsFixed(2)} wird gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _expenseService.deleteExpense(expense.id);
        _loadExpenses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }

  double get _totalAmount => _expenses.fold<double>(0, (s, e) => s + e.amount);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BillingTopBar(
          title: 'Ausgaben · $_monthLabel',
          subtitle: _isLoading
              ? null
              : _expenses.isEmpty
              ? null
              : fmtEur(_totalAmount),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 24),
              onPressed: _showCreateExpenseDialog,
              tooltip: 'Ausgabe erfassen',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _loadExpenses,
            ),
          ],
        ),
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
                      ElevatedButton(
                        onPressed: _loadExpenses,
                        child: const Text('Wiederholen'),
                      ),
                    ],
                  ),
                )
              : _expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Keine Ausgaben',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadExpenses,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) =>
                        _buildExpenseRow(_expenses[index]),
                  ),
                ),
        ),
        if (!_isLoading && _error == null && _expenses.isNotEmpty)
          _buildTotalFooter(),
      ],
    );
  }

  Widget _buildExpenseRow(Expense expense) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = _categoryColor(expense.category);
    final hasMissingReceipt = expense.receiptUrl == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Category icon box — amber-tinted when receipt is missing
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasMissingReceipt
                    ? AppColors.warningBg
                    : catColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasMissingReceipt
                      ? AppColors.warningBorder
                      : catColor.withAlpha(60),
                ),
              ),
              child: Icon(
                _categoryIcon(expense.category),
                size: 20,
                color: hasMissingReceipt ? AppColors.warningStrong : catColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.category.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expense.description ??
                        '${expense.createdAt.day.toString().padLeft(2, '0')}.'
                            '${expense.createdAt.month.toString().padLeft(2, '0')}.'
                            '${expense.createdAt.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (hasMissingReceipt)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Kein Beleg',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.warningStrong,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              fmtEur(expense.amount),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: () => _deleteExpense(expense),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Gesamt',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          Text(
            fmtEur(_totalAmount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.fuel:
        return Icons.local_gas_station;
      case ExpenseCategory.parking:
        return Icons.local_parking;
      case ExpenseCategory.tolls:
        return Icons.toll;
      case ExpenseCategory.cleaning:
        return Icons.cleaning_services;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  Color _categoryColor(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.fuel:
        return AppColors.warning;
      case ExpenseCategory.parking:
        return AppColors.info;
      case ExpenseCategory.tolls:
        return Theme.of(context).colorScheme.primary;
      case ExpenseCategory.cleaning:
        return AppColors.accent;
      case ExpenseCategory.maintenance:
        return Theme.of(context).colorScheme.primary;
      case ExpenseCategory.other:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  void dispose() {
    _expenseService.dispose();
    super.dispose();
  }
}
