import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../modules/billing/pdf_download_stub.dart'
    if (dart.library.html) '../modules/billing/pdf_download_web.dart';
import '../modules/billing/pdf_preview_stub.dart'
    if (dart.library.html) '../modules/billing/pdf_preview_web.dart';
import '../modules/core/services/error_messages.dart';
import '../blocs/blocs.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../modules/billing/models/billable_ride.dart';
import '../modules/billing/models/client_company.dart';
import '../modules/billing/models/invoice.dart';
import '../modules/billing/services/client_company_service.dart';
import '../modules/billing/services/invoice_service.dart';
import '../utils/parse_amount.dart';
import '../dashboard/superadmin/widgets/billing_widgets.dart';

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
  Object? _error;

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
          _error = e;
        });
      }
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
      if (mounted) {
        setState(() {
          _rides = rides;
          _loadingRides = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingRides = false;
          _error = e;
        });
      }
    }
  }

  double get _selectedSubtotal => _rides
      .where((r) => _selectedRideIds.contains(r.rideId))
      .fold(0.0, (s, r) => s + r.price);

  double get _selectedTax => _selectedSubtotal * _taxRate / 100;

  Future<void> _createInvoice() async {
    final company = _selectedCompany;
    if (company == null || _selectedRideIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() => _creating = true);
    try {
      final selected = _rides
          .where((r) => _selectedRideIds.contains(r.rideId))
          .toList();
      // Period is required by the backend; derive it from the selected rides.
      final dates = selected.map((r) => r.pickupDatetime).toList()..sort();
      final invoice = await _invoiceService.createInvoice(
        CreateInvoiceRequest(
          clientCompanyId: company.id,
          periodFrom: DateTime(
            dates.first.year,
            dates.first.month,
            dates.first.day,
          ),
          periodTo: DateTime(dates.last.year, dates.last.month, dates.last.day),
          taxRate: _taxRate,
          currency: 'EUR',
        ),
      );
      final filled = await _invoiceService.fillFromRides(
        invoice.id,
        _selectedRideIds.toList(),
      );
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
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e, l10n))));
    }
  }

  void _showCreatedDialog(Invoice invoice) {
    final l10n = AppLocalizations.of(context)!;
    showAdaptiveDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.invoiceCreatedTitle),
        content: Text(
          l10n.invoiceCreatedMsg(
            invoice.number,
            invoice.items.length,
            invoice.totalAmount.toStringAsFixed(2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.closeButton),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _previewPdf(invoice);
            },
            icon: const Icon(Icons.visibility),
            label: Text(l10n.previewButton),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final btnL10n = AppLocalizations.of(context)!;
              Navigator.of(ctx).pop();
              try {
                final bytes = await _invoiceService.downloadPdf(invoice.id);
                triggerPdfDownload(bytes, 'invoice-${invoice.number}.pdf');
                messenger.showSnackBar(
                  SnackBar(content: Text(btnL10n.pdfDownloadSuccess)),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      btnL10n.pdfDownloadError(friendlyError(e, btnL10n)),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(l10n.downloadPdfButton),
          ),
        ],
      ),
    );
  }

  Future<void> _previewPdf(Invoice invoice) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    Uint8List bytes;
    try {
      bytes = await _invoiceService.downloadPdf(invoice.id);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.pdfDownloadError(friendlyError(e, l10n)))),
      );
      return;
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
                title: Text(ctxL10n.pdfPreviewTitle(invoice.number)),
                actions: [
                  IconButton(
                    tooltip: ctxL10n.downloadPdfTooltip,
                    icon: const Icon(Icons.download),
                    onPressed: () => triggerPdfDownload(
                      bytes,
                      'invoice-${invoice.number}.pdf',
                    ),
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

  // Single-ride Quittung: download the receipt PDF for one ride and preview it,
  // reusing the same dialog scaffold as the invoice preview.
  Future<void> _previewReceipt(BillableRide ride) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    Uint8List bytes;
    try {
      bytes = await _invoiceService.downloadRideReceipt(
        ride.rideId,
        taxRate: _taxRate,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.receiptDownloadError(friendlyError(e, l10n))),
        ),
      );
      return;
    }
    if (!mounted) return;
    final fileName = 'quittung-${ride.rideId}.pdf';
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
                title: Text(ctxL10n.receiptTitle),
                actions: [
                  IconButton(
                    tooltip: ctxL10n.downloadPdfTooltip,
                    icon: const Icon(Icons.download),
                    onPressed: () => triggerPdfDownload(bytes, fileName),
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
  void dispose() {
    _invoiceService.dispose();
    _companyService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selCount = _selectedRideIds.length;
    final subtitle = _selectedCompany == null
        ? l10n.selectRidesToBill
        : selCount > 0
        ? l10n.ridesBillingCountSelected(selCount)
        : l10n.ridesBillingCountAvailable(_rides.length);

    return Column(
      children: [
        BillingTopBar(
          title: l10n.unbilledRidesTitle,
          subtitle: subtitle,
          actions: selCount > 0
              ? [
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$selCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]
              : [],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _loadingCompanies
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<ClientCompany>(
                  initialValue: _selectedCompany,
                  decoration: InputDecoration(
                    labelText: l10n.companiesLabel,
                    prefixIcon: const Icon(Icons.business),
                  ),
                  items: _companies
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: _creating ? null : _onCompanySelected,
                ),
        ),
        Expanded(child: _buildBody()),
        if (_selectedCompany != null) _buildSummaryBar(),
      ],
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final error = _error == null ? null : friendlyError(_error, l10n);
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, style: TextStyle(color: colorScheme.error)),
        ),
      );
    }
    if (_selectedCompany == null) {
      return Center(
        child: Text(
          l10n.selectCompanyForBilling,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    if (_loadingRides) {
      return Center(child: CircularProgressIndicator.adaptive());
    }
    if (_rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: AppColors.success,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noBillableRides,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _rides.length,
      itemBuilder: (context, index) {
        final ride = _rides[index];
        final selected = _selectedRideIds.contains(ride.rideId);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariant)
                : (isDark ? AppColors.surfaceDark : AppColors.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withAlpha(80)
                  : (isDark ? AppColors.borderDark : AppColors.borderPrimary),
            ),
          ),
          child: CheckboxListTile(
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
            title: Text(
              '${ride.pickupAddress} → ${ride.dropoffAddress}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary)
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
              ),
            ),
            subtitle: Text(
              _fmtDateTime(ride.pickupDatetime),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            secondary: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmtEur(ride.price),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: selected
                        ? (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary)
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                  ),
                ),
                IconButton(
                  tooltip: l10n.receiptTooltip,
                  icon: const Icon(Icons.receipt_long),
                  onPressed: _creating ? null : () => _previewReceipt(ride),
                ),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        );
      },
    );
  }

  Widget _buildSummaryBar() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
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
                    count > 0
                        ? l10n.selectedRidesSummary(
                            fmtEur(_selectedSubtotal),
                            fmtEur(total),
                          )
                        : l10n.noRidesSelected,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: _taxRate.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.vatPercentLabel,
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _taxRate = parseAmount(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: BillingGraphiteButton(
                onPressed: (count == 0 || _creating) ? null : _createInvoice,
                child: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.createInvoiceButton),
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
