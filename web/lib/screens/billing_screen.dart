import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modules/billing/pdf_download_stub.dart'
    if (dart.library.html) '../modules/billing/pdf_download_web.dart';
import '../modules/billing/pdf_preview_stub.dart'
    if (dart.library.html) '../modules/billing/pdf_preview_web.dart';
import '../modules/core/services/error_messages.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/lucide_compat.dart';
import '../l10n/app_localizations.dart';
import '../modules/billing/models/client_company.dart';
import '../modules/billing/models/invoice.dart';
import '../modules/billing/services/client_company_service.dart';
import '../modules/billing/services/invoice_service.dart';
import '../dashboard/superadmin/widgets/billing_widgets.dart';
import 'billing_rides_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late InvoiceService _invoiceService;
  late ClientCompanyService _companyService;

  List<Invoice> _invoices = [];
  List<ClientCompany> _companies = [];
  bool _loadingInvoices = true;
  bool _loadingCompanies = true;
  String? _invoiceError;
  String? _companyError;
  InvoiceStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    final apiClient = context.read<AuthBloc>().apiClient;
    _invoiceService = InvoiceService(apiClient: apiClient);
    _companyService = ClientCompanyService(apiClient: apiClient);
    _loadInvoices();
    _loadCompanies();
  }

  void _onTabChanged() {
    // Rebuild so the desktop layout reflects the new index when the rail
    // or a programmatic animation completes.
    if (!_tabController.indexIsChanging) setState(() {});
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _loadingInvoices = true;
      _invoiceError = null;
    });
    try {
      final invoices = await _invoiceService.getInvoices(status: _statusFilter);
      if (mounted) {
        setState(() {
          _invoices = invoices;
          _loadingInvoices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingInvoices = false;
          _invoiceError = e.toString();
        });
      }
    }
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _companyError = null;
    });
    try {
      final companies = await _companyService.getCompanies();
      if (mounted) {
        setState(() {
          _companies = companies;
          _loadingCompanies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCompanies = false;
          _companyError = e.toString();
        });
      }
    }
  }

  void _setFilter(InvoiceStatus? status) {
    setState(() => _statusFilter = status);
    _loadInvoices();
  }

  // ─── COMPUTED STATS ───────────────────────────────────────────────────────────

  double get _outstanding => _invoices
      .where((i) => i.status == InvoiceStatus.sent)
      .fold(0.0, (s, i) => s + i.totalAmount);

  double get _paidThisMonth {
    final now = DateTime.now();
    return _invoices
        .where(
          (i) =>
              i.status == InvoiceStatus.paid &&
              i.paidAt?.year == now.year &&
              i.paidAt?.month == now.month,
        )
        .fold(0.0, (s, i) => s + i.totalAmount);
  }

  double get _overdue {
    final now = DateTime.now();
    return _invoices
        .where(
          (i) =>
              i.status == InvoiceStatus.sent &&
              (i.dueDate?.isBefore(now) ?? false),
        )
        .fold(0.0, (s, i) => s + i.totalAmount);
  }

  /// Collection rate: paid / (paid + sent) * 100, clamped to [0, 100].
  /// Cancelled invoices are excluded — they are neither collected nor pending.
  String get _collectionRate {
    final paid = _invoices.where((i) => i.status == InvoiceStatus.paid).length;
    final total = _invoices
        .where(
          (i) =>
              i.status == InvoiceStatus.paid || i.status == InvoiceStatus.sent,
        )
        .length;
    if (total == 0) return '—';
    return '${((paid / total) * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppDimensions.breakpointDesktop) {
          return _buildDesktopLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  /// Desktop: header on top, NavigationRail on the left, tab content on the right.
  Widget _buildDesktopLayout(BuildContext context) {
    final tabContent = [
      _buildInvoicesTab(),
      _buildCompaniesTab(),
      const BillingRidesScreen(),
    ];
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Row(
            children: [
              _BillingNavRail(
                selectedIndex: _tabController.index,
                onDestinationSelected: (i) =>
                    setState(() => _tabController.index = i),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: tabContent[_tabController.index]),
            ],
          ),
        ),
      ],
    );
  }

  /// Mobile: existing header + TabBar + TabBarView.
  Widget _buildMobileLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildHeader(),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: Theme.of(context).colorScheme.primary,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.receipt_long, size: 18),
              text: l10n.invoicesTab,
            ),
            Tab(
              icon: const Icon(Icons.business, size: 18),
              text: l10n.companiesTab,
            ),
            Tab(
              icon: const Icon(Icons.playlist_add_check, size: 18),
              text: l10n.billingRidesTab,
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInvoicesTab(),
              _buildCompaniesTab(),
              const BillingRidesScreen(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
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
    final monthLabel = '${monthNames[now.month - 1]} ${now.year}';
    final subtitle = _loadingInvoices
        ? monthLabel
        : l10n.invoicesCountSubtitle(monthLabel, _invoices.length);

    return BillingTopBar(
      title: l10n.billingScreenTitle,
      subtitle: subtitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
          onPressed: () {
            _loadInvoices();
            _loadCompanies();
          },
        ),
      ],
    );
  }

  // ─── INVOICES TAB ────────────────────────────────────────────────────────────

  Widget _buildInvoicesTab() {
    final l10n = AppLocalizations.of(context)!;
    final invoiceError = _invoiceError;
    return Column(
      children: [
        if (!_loadingInvoices && invoiceError == null && _invoices.isNotEmpty)
          _buildStatTiles(),
        _buildTopActions(),
        _buildStatusFilters(),
        Expanded(
          child: _loadingInvoices
              ? Center(child: CircularProgressIndicator.adaptive())
              : invoiceError != null
              ? _buildError(invoiceError, _loadInvoices)
              : _invoices.isEmpty
              ? _buildEmpty(l10n.noInvoices, Icons.receipt)
              : _buildInvoiceTable(),
        ),
        _buildGoBDFooter(),
      ],
    );
  }

  Widget _buildStatTiles() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          final tiles = [
            StatTile(
              label: l10n.outstandingInvoices,
              value: fmtEur(_outstanding),
              variant: StatTileVariant.dark,
            ),
            StatTile(label: l10n.paidThisMonth, value: fmtEur(_paidThisMonth)),
            StatTile(
              label: l10n.overdueInvoices,
              value: fmtEur(_overdue),
              valueColor: const Color(0xFFDC2626),
            ),
            StatTile(label: l10n.collectionRate, value: _collectionRate),
          ];
          if (isWide) {
            return Row(
              children: tiles
                  .map(
                    (t) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: t,
                      ),
                    ),
                  )
                  .toList(),
            );
          }
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: tiles,
          );
        },
      ),
    );
  }

  Widget _buildTopActions() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          BillingOutlinedButton(
            onPressed: _showDatevExport,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download, size: 16),
                const SizedBox(width: 6),
                Text(l10n.exportDatevButton),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BillingGraphiteButton(
            onPressed: _showNewInvoiceDialog,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 16),
                const SizedBox(width: 6),
                Text(l10n.createNewInvoiceButton),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDatevExport() {
    final l10n = AppLocalizations.of(context)!;
    // Navigate to the DATEV export tab if available, or show snackbar.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.datevExportOpening)));
  }

  void _showNewInvoiceDialog() {
    final l10n = AppLocalizations.of(context)!;
    if (_companies.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.createCompanyFirst)));
      return;
    }
    String? selectedCompanyId = _companies.first.id;
    final messenger = ScaffoldMessenger.of(context);
    showAdaptiveDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(l10n.newInvoiceTitle),
          content: DropdownButtonFormField<String>(
            initialValue: selectedCompanyId,
            decoration: InputDecoration(labelText: l10n.companiesLabel),
            items: _companies
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setDlg(() => selectedCompanyId = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final companyId = selectedCompanyId;
                if (companyId == null) return;
                Navigator.pop(ctx);
                final now = DateTime.now();
                try {
                  await _invoiceService.createInvoice(
                    CreateInvoiceRequest(
                      clientCompanyId: companyId,
                      periodFrom: DateTime(now.year, now.month, 1),
                      periodTo: DateTime(now.year, now.month + 1, 0),
                      taxRate: 19,
                      currency: 'EUR',
                    ),
                  );
                  await _loadInvoices();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(friendlyError(e, l10n))),
                  );
                }
              },
              child: Text(l10n.createInvoiceButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    final l10n = AppLocalizations.of(context)!;
    final filters = [
      null,
      InvoiceStatus.draft,
      InvoiceStatus.sent,
      InvoiceStatus.paid,
    ];
    final labels = [
      l10n.allInvoicesFilter,
      l10n.draftStatusFilter,
      l10n.sentStatusFilter,
      l10n.paidStatusFilter,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = _statusFilter == filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (_) => _setFilter(filters[i]),
              selectedColor: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(30),
              checkmarkColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }),
      ),
    );
  }

  /// Invoice table with themed card, header row, and per-row entries.
  Widget _buildInvoiceTable() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
              ),
            ),
            child: Column(
              children: [
                // Header row
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark
                        : AppColors.surfaceVariant,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          l10n.invoiceTableHeaderNumber,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          l10n.invoiceTableHeaderClient,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          l10n.invoiceTableHeaderAmount,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const SizedBox(width: 90, child: SizedBox.shrink()),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                // Invoice rows
                ...List.generate(_invoices.length, (i) {
                  final invoice = _invoices[i];
                  final isLast = i == _invoices.length - 1;
                  return _buildInvoiceTableRow(invoice, isLast);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTableRow(Invoice invoice, bool isLast) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final company = _companies
        .where((c) => c.id == invoice.clientCompanyId)
        .firstOrNull;
    final companyName =
        company?.name ?? invoice.clientCompanyId.substring(0, 8);

    Widget statusBadge;
    switch (invoice.status) {
      case InvoiceStatus.paid:
        statusBadge = BillingStatusBadge.paid(
          label: invoice.status.displayName,
        );
        break;
      case InvoiceStatus.sent:
        // Sent = pending (not yet paid)
        statusBadge = BillingStatusBadge.pending(
          label: invoice.status.displayName,
        );
        break;
      case InvoiceStatus.draft:
        statusBadge = BillingStatusBadge.draft(
          label: invoice.status.displayName,
        );
        break;
      case InvoiceStatus.cancelled:
        statusBadge = BillingStatusBadge.overdue(
          label: invoice.status.displayName,
        );
        break;
    }

    // Check if overdue (sent + dueDate in past)
    if (invoice.status == InvoiceStatus.sent &&
        (invoice.dueDate?.isBefore(DateTime.now()) ?? false)) {
      statusBadge = BillingStatusBadge.overdue(label: l10n.overdueStatus);
    }

    return InkWell(
      onTap: () => _showInvoiceDetail(invoice),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderPrimary,
                  ),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      invoice.number,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (invoice.reminderSentAt != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.paymentReminderSent,
                      child: Icon(
                        Icons.notifications_active,
                        size: 14,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                companyName,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                fmtEur(invoice.totalAmount),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 90, child: statusBadge),
            SizedBox(
              width: 32,
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                onSelected: (action) {
                  if (action == 'detail') _showInvoiceDetail(invoice);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'detail',
                    child: ListTile(
                      leading: const Icon(Icons.open_in_new),
                      title: Text(l10n.viewDetailsMenu),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoBDFooter() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.gobdCompliant,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetail(Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _InvoiceDetailSheet(
        invoice: invoice,
        invoiceService: _invoiceService,
        onRefresh: _loadInvoices,
      ),
    );
  }

  // ─── COMPANIES TAB ───────────────────────────────────────────────────────────

  Widget _buildCompaniesTab() {
    final l10n = AppLocalizations.of(context)!;
    final companyError = _companyError;
    return Stack(
      children: [
        _loadingCompanies
            ? Center(child: CircularProgressIndicator.adaptive())
            : companyError != null
            ? _buildError(companyError, _loadCompanies)
            : _companies.isEmpty
            ? _buildEmpty(l10n.noCompanies, Icons.business)
            : RefreshIndicator(
                onRefresh: _loadCompanies,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _companies.length,
                  itemBuilder: (_, i) => _buildCompanyCard(_companies[i]),
                ),
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showAddCompanyDialog,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyCard(ClientCompany company) {
    final l10n = AppLocalizations.of(context)!;
    final email = company.email;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(30),
          child: Text(
            company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        title: Text(
          company.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: email != null
            ? Text(email, style: const TextStyle(fontSize: 12))
            : null,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') _showEditCompanyDialog(company);
            if (action == 'delete') _confirmDeleteCompany(company);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.editCompanyMenu),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: Text(
                  l10n.deleteCompanyMenu,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCompanyDialog() => _showCompanyDialog(null);
  void _showEditCompanyDialog(ClientCompany company) =>
      _showCompanyDialog(company);

  void _showCompanyDialog(ClientCompany? existing) {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final vatIdCtrl = TextEditingController(text: existing?.vatId ?? '');
    String? selectedLanguage = existing?.preferredLanguage;
    final messenger = ScaffoldMessenger.of(context);

    showAdaptiveDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? l10n.addCompanyTitle : l10n.editCompanyTitle,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.companyNameLabel),
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.companyEmailLabel,
                  ),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.companyPhoneLabel,
                  ),
                ),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.companyAddressLabel,
                  ),
                ),
                TextField(
                  controller: vatIdCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.companyVatIdLabel,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: selectedLanguage,
                  decoration: InputDecoration(
                    labelText: l10n.invoiceLanguageLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.languageStandard),
                    ),
                    DropdownMenuItem(
                      value: 'de',
                      child: Text(l10n.languageGerman),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(l10n.languageEnglish),
                    ),
                    DropdownMenuItem(
                      value: 'uk',
                      child: Text(l10n.languageUkrainian),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedLanguage = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final req = CreateClientCompanyRequest(
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty
                      ? null
                      : emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty
                      ? null
                      : addressCtrl.text.trim(),
                  preferredLanguage: selectedLanguage,
                  vatId: vatIdCtrl.text.trim().isEmpty
                      ? null
                      : vatIdCtrl.text.trim(),
                );
                try {
                  if (existing == null) {
                    await _companyService.createCompany(req);
                  } else {
                    await _companyService.updateCompany(existing.id, req);
                  }
                  await _loadCompanies();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(friendlyError(e, l10n))),
                  );
                }
              },
              child: Text(existing == null ? l10n.addCompanyButton : l10n.save),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
      vatIdCtrl.dispose();
    });
  }

  void _confirmDeleteCompany(ClientCompany company) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCompanyConfirmTitle),
        content: Text(l10n.deleteCompanyConfirmMsg(company.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _companyService.deleteCompany(company.id);
                await _loadCompanies();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(friendlyError(e, l10n))),
                );
              }
            },
            child: Text(
              l10n.delete,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  Widget _buildEmpty(String msg, IconData icon) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 64,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        Text(
          msg,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _buildError(String msg, VoidCallback retry) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center),
          ElevatedButton(onPressed: retry, child: Text(l10n.retry)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _invoiceService.dispose();
    _companyService.dispose();
    super.dispose();
  }
}

// ─── INVOICE DETAIL BOTTOM SHEET ─────────────────────────────────────────────

class _InvoiceDetailSheet extends StatefulWidget {
  final Invoice invoice;
  final InvoiceService invoiceService;
  final VoidCallback onRefresh;

  const _InvoiceDetailSheet({
    required this.invoice,
    required this.invoiceService,
    required this.onRefresh,
  });

  @override
  State<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<_InvoiceDetailSheet> {
  late Invoice _invoice;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _reloadDetail();
  }

  Future<void> _reloadDetail() async {
    try {
      final full = await widget.invoiceService.getInvoice(_invoice.id);
      if (mounted) setState(() => _invoice = full);
    } catch (e) {
      debugPrint('Failed to reload invoice detail: $e');
    }
  }

  Future<void> _action(Future<dynamic> Function() fn) async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await fn();
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, l10n))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _previewPdf(Invoice inv) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    Uint8List bytes;
    try {
      bytes = await widget.invoiceService.downloadPdf(inv.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, l10n))));
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    await showAdaptiveDialog<void>(
      context: context,
      builder: (ctx) {
        final ctxL10n = AppLocalizations.of(ctx)!;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: Text(ctxL10n.pdfPreviewTitle(inv.number)),
                actions: [
                  IconButton(
                    tooltip: ctxL10n.downloadPdfTooltip,
                    icon: const Icon(Icons.download),
                    onPressed: () =>
                        triggerPdfDownload(bytes, 'invoice-${inv.number}.pdf'),
                  ),
                  IconButton(
                    tooltip: ctxL10n.closeTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              Expanded(child: buildPdfPreview(bytes)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inv = _invoice;
    final isDraft = inv.status == InvoiceStatus.draft;
    final isSent = inv.status == InvoiceStatus.sent;
    final reminderSentAt = inv.reminderSentAt;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.number,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_fmtDate(inv.periodFrom)} – ${_fmtDate(inv.periodTo)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    _StatusBadge(inv.status),
                    if (reminderSentAt != null)
                      _ReminderBadge(
                        label: l10n.reminderBadgeLabel(
                          _fmtDate(reminderSentAt),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            if (inv.items.isNotEmpty) ...[
              Text(
                l10n.invoiceLineItems,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...inv.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.description,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '€${item.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
            ],
            _TotalRow(l10n.subtotalLabel, inv.subtotalAmount),
            if (inv.taxRate > 0)
              _TotalRow(
                l10n.vatLineLabel(inv.taxRate.toStringAsFixed(0)),
                inv.taxAmount,
              ),
            _TotalRow(
              l10n.totalLabel(inv.currency),
              inv.totalAmount,
              bold: true,
            ),
            const SizedBox(height: 16),
            if (_loading)
              Center(child: CircularProgressIndicator.adaptive())
            else
              Column(
                children: [
                  if (isDraft) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          _action(() => widget.invoiceService.autoFill(inv.id)),
                      icon: const Icon(Icons.auto_fix_high),
                      label: Text(l10n.autoFillRidesButton),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _action(
                        () => widget.invoiceService.sendInvoice(inv.id),
                      ),
                      icon: const Icon(Icons.send),
                      label: Text(l10n.sendInvoiceButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _action(
                        () => widget.invoiceService.deleteInvoice(inv.id),
                      ),
                      icon: const Icon(Icons.delete, color: AppColors.error),
                      label: Text(
                        l10n.delete,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                  if (isSent) ...[
                    ElevatedButton.icon(
                      onPressed: () =>
                          _action(() => widget.invoiceService.markPaid(inv.id)),
                      icon: const Icon(Icons.check_circle),
                      label: Text(l10n.markAsPaidButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      setState(() => _loading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final btnL10n = AppLocalizations.of(context)!;
                      try {
                        final bytes = await widget.invoiceService.downloadPdf(
                          inv.id,
                        );
                        triggerPdfDownload(bytes, 'invoice-${inv.number}.pdf');
                        messenger.showSnackBar(
                          SnackBar(content: Text(btnL10n.pdfDownloadSuccess)),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(friendlyError(e, btnL10n))),
                        );
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(l10n.downloadPdfButton),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _previewPdf(inv),
                    icon: const Icon(Icons.visibility),
                    label: Text(l10n.previewButton),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  const _StatusBadge(this.status);

  Color _color(BuildContext context) => switch (status) {
    InvoiceStatus.draft => Theme.of(context).colorScheme.onSurfaceVariant,
    InvoiceStatus.sent => AppColors.warning,
    InvoiceStatus.paid => AppColors.success,
    InvoiceStatus.cancelled => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Shown next to the status badge once a payment reminder has been emailed for a
/// sent-but-overdue invoice; carries the pre-localized label string.
class _ReminderBadge extends StatelessWidget {
  final String label;
  const _ReminderBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_active, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  const _TotalRow(this.label, this.amount, {this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
        Text(
          '€${amount.toStringAsFixed(2)}',
          style: bold
              ? TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                )
              : null,
        ),
      ],
    ),
  );
}

/// Desktop navigation rail for the Billing screen.
/// Replaces the mobile [TabBar] at >= [AppDimensions.breakpointDesktop].
class _BillingNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _BillingNavRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  TextStyle _labelStyle(Color color) =>
      TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return NavigationRail(
      backgroundColor: AppColors.primary,
      indicatorColor: AppColors.accent.withValues(alpha: 0.2),
      selectedIconTheme: const IconThemeData(color: AppColors.accent),
      unselectedIconTheme: const IconThemeData(color: AppColors.textOnPrimary),
      selectedLabelTextStyle: _labelStyle(AppColors.accent),
      unselectedLabelTextStyle: _labelStyle(AppColors.textOnPrimary),
      labelType: NavigationRailLabelType.all,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(LucideCompat.receipt),
          label: Text(l10n.invoicesRailLabel),
        ),
        NavigationRailDestination(
          icon: const Icon(LucideCompat.building2),
          label: Text(l10n.clientsRailLabel),
        ),
        NavigationRailDestination(
          icon: const Icon(LucideCompat.download),
          label: Text(l10n.datevRailLabel),
        ),
      ],
    );
  }
}
