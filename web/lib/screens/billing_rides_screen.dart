import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../modules/billing/pdf_download_stub.dart'
    if (dart.library.html) '../modules/billing/pdf_download_web.dart';
import '../modules/billing/pdf_preview_stub.dart'
    if (dart.library.html) '../modules/billing/pdf_preview_web.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../modules/billing/models/billable_ride.dart';
import '../modules/billing/models/client_company.dart';
import '../modules/billing/models/invoice.dart';
import '../modules/billing/services/client_company_service.dart';
import '../modules/billing/services/invoice_service.dart';

/// Per-ride billing: pick a client company, select its completed unbilled rides,
/// and create a draft Rechnung from exactly those rides. The company dropdown
/// fixes the billing context, so rides of different companies can never be mixed.
class BillingRidesScreen extends StatefulWidget {
  const BillingRidesScreen({super.key});

  @override
  State<BillingRidesScreen> createState() => _BillingRidesScreenState();
}

class _BillingRidesScreenState extends State<BillingRidesScreen> {
  late InvoiceService _invoiceService;
  late ClientCompanyService _companyService;

  List<ClientCompany> _companies = [];
  ClientCompany? _selectedCompany;
  List<BillableRide> _rides = [];
  final Set<String> _selectedRideIds = {};
  double _taxRate = 19;

  bool _loadingCompanies = true;
  bool _loadingRides = false;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthBloc>().apiClient;
    _invoiceService = InvoiceService(apiClient: apiClient);
    _companyService = ClientCompanyService(apiClient: apiClient);
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _error = null;
    });
    try {
      final companies = await _companyService.getCompanies();
      if (mounted) setState(() { _companies = companies; _loadingCompanies = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingCompanies = false; _error = e.toString(); });
    }
  }

  Future<void> _onCompanySelected(ClientCompany? company) async {
    setState(() {
      _selectedCompany = company;
      _selectedRideIds.clear(); // changing company resets the selection
      _rides = [];
      _error = null;
    });
    if (company == null) return;
    setState(() => _loadingRides = true);
    try {
      final rides = await _invoiceService.getBillableRides(company.id);
      if (mounted) setState(() { _rides = rides; _loadingRides = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingRides = false; _error = e.toString(); });
    }
  }

  double get _selectedSubtotal =>
      _rides.where((r) => _selectedRideIds.contains(r.rideId)).fold(0.0, (s, r) => s + r.price);

  double get _selectedTax => _selectedSubtotal * _taxRate / 100;

  Future<void> _createInvoice() async {
    final company = _selectedCompany;
    if (company == null || _selectedRideIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _creating = true);
    try {
      final selected = _rides.where((r) => _selectedRideIds.contains(r.rideId)).toList();
      // Period is required by the backend; derive it from the selected rides.
      final dates = selected.map((r) => r.pickupDatetime).toList()..sort();
      final invoice = await _invoiceService.createInvoice(CreateInvoiceRequest(
        clientCompanyId: company.id,
        periodFrom: DateTime(dates.first.year, dates.first.month, dates.first.day),
        periodTo: DateTime(dates.last.year, dates.last.month, dates.last.day),
        taxRate: _taxRate,
        currency: 'EUR',
      ));
      final filled = await _invoiceService.fillFromRides(invoice.id, _selectedRideIds.toList());
      if (!mounted) return;
      setState(() {
        _selectedRideIds.clear();
        _creating = false;
      });
      // Billed rides are no longer unbilled — refresh the list.
      await _onCompanySelected(company);
      _showCreatedDialog(filled);
    } catch (e) {
      if (mounted) setState(() => _creating = false);
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  void _showCreatedDialog(Invoice invoice) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechnung erstellt'),
        content: Text(
          '${invoice.number} · ${invoice.items.length} Fahrten · '
          '€${invoice.totalAmount.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Schließen'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _previewPdf(invoice);
            },
            icon: const Icon(Icons.visibility),
            label: const Text('Vorschau'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              try {
                final bytes = await _invoiceService.downloadPdf(invoice.id);
                triggerPdfDownload(bytes, 'invoice-${invoice.number}.pdf');
                messenger.showSnackBar(const SnackBar(content: Text('PDF heruntergeladen')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('PDF-Fehler: $e')));
              }
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('PDF herunterladen'),
          ),
        ],
      ),
    );
  }

  Future<void> _previewPdf(Invoice invoice) async {
    final messenger = ScaffoldMessenger.of(context);
    Uint8List bytes;
    try {
      bytes = await _invoiceService.downloadPdf(invoice.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('PDF-Fehler: $e')));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: Text('Vorschau · ${invoice.number}'),
              actions: [
                IconButton(
                  tooltip: 'Herunterladen',
                  icon: const Icon(Icons.download),
                  onPressed: () => triggerPdfDownload(bytes, 'invoice-${invoice.number}.pdf'),
                ),
                IconButton(
                  tooltip: 'Schließen',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Expanded(child: buildPdfPreview(bytes)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _invoiceService.dispose();
    _companyService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _loadingCompanies
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<ClientCompany>(
                  initialValue: _selectedCompany,
                  decoration: const InputDecoration(
                    labelText: 'Unternehmen',
                    prefixIcon: Icon(Icons.business),
                  ),
                  items: _companies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: _creating ? null : _onCompanySelected,
                ),
        ),
        Expanded(child: _buildBody(colorScheme)),
        if (_selectedCompany != null) _buildSummaryBar(colorScheme),
      ],
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: colorScheme.error)),
        ),
      );
    }
    if (_selectedCompany == null) {
      return Center(
        child: Text(
          'Wählen Sie ein Unternehmen, um abrechenbare Fahrten zu sehen.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    if (_loadingRides) return const Center(child: CircularProgressIndicator());
    if (_rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: AppColors.success),
            const SizedBox(height: 12),
            Text(
              'Keine abrechenbaren Fahrten',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _rides.length,
      itemBuilder: (context, index) {
        final ride = _rides[index];
        final selected = _selectedRideIds.contains(ride.rideId);
        return CheckboxListTile(
          value: selected,
          onChanged: _creating
              ? null
              : (v) => setState(() {
                    if (v == true) {
                      _selectedRideIds.add(ride.rideId);
                    } else {
                      _selectedRideIds.remove(ride.rideId);
                    }
                  }),
          title: Text('${ride.pickupAddress} → ${ride.dropoffAddress}'),
          subtitle: Text(_fmtDateTime(ride.pickupDatetime)),
          secondary: Text(
            '€${ride.price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        );
      },
    );
  }

  Widget _buildSummaryBar(ColorScheme colorScheme) {
    final count = _selectedRideIds.length;
    final total = _selectedSubtotal + _selectedTax;
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$count Fahrten · Netto €${_selectedSubtotal.toStringAsFixed(2)} · '
                    'MwSt €${_selectedTax.toStringAsFixed(2)} · Gesamt €${total.toStringAsFixed(2)}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: _taxRate.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'MwSt %', isDense: true),
                    onChanged: (v) => setState(() => _taxRate = double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (count == 0 || _creating) ? null : _createInvoice,
                icon: _creating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.receipt_long),
                label: const Text('Rechnung erstellen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
