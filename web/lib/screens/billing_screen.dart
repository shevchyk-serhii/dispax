import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../modules/billing/models/client_company.dart';
import '../modules/billing/models/invoice.dart';
import '../modules/billing/services/client_company_service.dart';
import '../modules/billing/services/invoice_service.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> with SingleTickerProviderStateMixin {
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
    _tabController = TabController(length: 2, vsync: this);
    final apiClient = context.read<AuthBloc>().apiClient;
    _invoiceService = InvoiceService(apiClient: apiClient);
    _companyService = ClientCompanyService(apiClient: apiClient);
    _loadInvoices();
    _loadCompanies();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _loadingInvoices = true;
      _invoiceError = null;
    });
    try {
      final invoices = await _invoiceService.getInvoices(status: _statusFilter);
      if (mounted) setState(() { _invoices = invoices; _loadingInvoices = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingInvoices = false; _invoiceError = e.toString(); });
    }
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _companyError = null;
    });
    try {
      final companies = await _companyService.getCompanies();
      if (mounted) setState(() { _companies = companies; _loadingCompanies = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingCompanies = false; _companyError = e.toString(); });
    }
  }

  void _setFilter(InvoiceStatus? status) {
    setState(() => _statusFilter = status);
    _loadInvoices();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Rechnungen'),
            Tab(icon: Icon(Icons.business, size: 18), text: 'Unternehmen'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInvoicesTab(),
              _buildCompaniesTab(),
            ],
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
                'Abrechnung',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: () { _loadInvoices(); _loadCompanies(); },
            ),
          ],
        ),
      ),
    );
  }

  // ─── INVOICES TAB ────────────────────────────────────────────────────────────

  Widget _buildInvoicesTab() {
    return Column(
      children: [
        _buildStatusFilters(),
        Expanded(
          child: _loadingInvoices
              ? const Center(child: CircularProgressIndicator())
              : _invoiceError != null
                  ? _buildError(_invoiceError!, _loadInvoices)
                  : _invoices.isEmpty
                      ? _buildEmpty('Keine Rechnungen', Icons.receipt)
                      : RefreshIndicator(
                          onRefresh: _loadInvoices,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _invoices.length,
                            itemBuilder: (_, i) => _buildInvoiceCard(_invoices[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildStatusFilters() {
    final filters = [null, InvoiceStatus.draft, InvoiceStatus.sent, InvoiceStatus.paid];
    final labels = ['Alle', 'Entwurf', 'Gesendet', 'Bezahlt'];
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
              selectedColor: AppColors.primary.withAlpha(30),
              checkmarkColor: AppColors.primary,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final statusColor = _statusColor(invoice.status);
    final company = _companies.where((c) => c.id == invoice.clientCompanyId).firstOrNull;
    final companyName = company?.name ?? invoice.clientCompanyId.substring(0, 8);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_statusIcon(invoice.status), color: statusColor, size: 20),
        ),
        title: Text(invoice.number, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(companyName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            Text(
              '${_fmtDate(invoice.periodFrom)} – ${_fmtDate(invoice.periodTo)}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '€${invoice.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                invoice.status.displayName,
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        onTap: () => _showInvoiceDetail(invoice),
      ),
    );
  }

  void _showInvoiceDetail(Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _InvoiceDetailSheet(
        invoice: invoice,
        invoiceService: _invoiceService,
        onRefresh: _loadInvoices,
      ),
    );
  }

  // ─── COMPANIES TAB ───────────────────────────────────────────────────────────

  Widget _buildCompaniesTab() {
    return Stack(
      children: [
        _loadingCompanies
            ? const Center(child: CircularProgressIndicator())
            : _companyError != null
                ? _buildError(_companyError!, _loadCompanies)
                : _companies.isEmpty
                    ? _buildEmpty('Keine Unternehmen', Icons.business)
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
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyCard(ClientCompany company) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(30),
          child: Text(
            company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: company.email != null ? Text(company.email!, style: const TextStyle(fontSize: 12)) : null,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') _showEditCompanyDialog(company);
            if (action == 'delete') _confirmDeleteCompany(company);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Bearbeiten'))),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Löschen', style: TextStyle(color: Colors.red)))),
          ],
        ),
      ),
    );
  }

  void _showAddCompanyDialog() => _showCompanyDialog(null);
  void _showEditCompanyDialog(ClientCompany company) => _showCompanyDialog(company);

  void _showCompanyDialog(ClientCompany? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Unternehmen hinzufügen' : 'Unternehmen bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'E-Mail')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon')),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Adresse')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final req = CreateClientCompanyRequest(
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
              );
              try {
                if (existing == null) {
                  await _companyService.createCompany(req);
                } else {
                  await _companyService.updateCompany(existing.id, req);
                }
                await _loadCompanies();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
              }
            },
            child: Text(existing == null ? 'Hinzufügen' : 'Speichern'),
          ),
        ],
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
    });
  }

  void _confirmDeleteCompany(ClientCompany company) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unternehmen löschen?'),
        content: Text('${company.name} wird gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _companyService.deleteCompany(company.id);
                await _loadCompanies();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
              }
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────────

  Color _statusColor(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => Colors.grey,
        InvoiceStatus.sent => AppColors.warning,
        InvoiceStatus.paid => AppColors.success,
        InvoiceStatus.cancelled => AppColors.error,
      };

  IconData _statusIcon(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => Icons.edit_note,
        InvoiceStatus.sent => Icons.send,
        InvoiceStatus.paid => Icons.check_circle,
        InvoiceStatus.cancelled => Icons.cancel,
      };

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Widget _buildEmpty(String msg, IconData icon) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(msg, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _buildError(String msg, VoidCallback retry) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            ElevatedButton(onPressed: retry, child: const Text('Wiederholen')),
          ],
        ),
      );

  @override
  void dispose() {
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
    try {
      await fn();
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _triggerBrowserDownload(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final inv = _invoice;
    final isDraft = inv.status == InvoiceStatus.draft;
    final isSent = inv.status == InvoiceStatus.sent;

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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv.number, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${_fmtDate(inv.periodFrom)} – ${_fmtDate(inv.periodTo)}',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                _StatusBadge(inv.status),
              ],
            ),
            const Divider(height: 24),
            if (inv.items.isNotEmpty) ...[
              const Text('Positionen', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...inv.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.description, style: const TextStyle(fontSize: 13))),
                        Text('€${item.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  )),
              const Divider(),
            ],
            _TotalRow('Zwischensumme', inv.subtotalAmount),
            if (inv.taxRate > 0) _TotalRow('MwSt. ${inv.taxRate.toStringAsFixed(0)}%', inv.taxAmount),
            _TotalRow('Gesamt (${inv.currency})', inv.totalAmount, bold: true),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator())
            else Column(
              children: [
                if (isDraft) ...[
                  OutlinedButton.icon(
                    onPressed: () => _action(() => widget.invoiceService.autoFill(inv.id)),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Fahrten automatisch laden'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _action(() => widget.invoiceService.sendInvoice(inv.id)),
                    icon: const Icon(Icons.send),
                    label: const Text('Rechnung senden'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _action(() => widget.invoiceService.deleteInvoice(inv.id)),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Löschen', style: TextStyle(color: Colors.red)),
                  ),
                ],
                if (isSent) ...[
                  ElevatedButton.icon(
                    onPressed: () => _action(() => widget.invoiceService.markPaid(inv.id)),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Als bezahlt markieren'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _loading = true);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final bytes = await widget.invoiceService.downloadPdf(inv.id);
                      _triggerBrowserDownload(bytes, 'invoice-${inv.number}.pdf');
                      messenger.showSnackBar(const SnackBar(content: Text('PDF heruntergeladen')));
                    } catch (e) {
                      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF herunterladen'),
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

  Color get _color => switch (status) {
        InvoiceStatus.draft => Colors.grey,
        InvoiceStatus.sent => AppColors.warning,
        InvoiceStatus.paid => AppColors.success,
        InvoiceStatus.cancelled => AppColors.error,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withAlpha(80)),
        ),
        child: Text(status.displayName, style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontSize: 12)),
      );
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
            Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
            Text('€${amount.toStringAsFixed(2)}',
                style: bold
                    ? const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)
                    : null),
          ],
        ),
      );
}
