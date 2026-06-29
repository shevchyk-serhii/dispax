import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../modules/ride_management/models/external_driver.dart';
import '../../modules/ride_management/models/partner_company.dart';
import '../../modules/ride_management/services/ride_service.dart';

/// The dispatcher's confirmed hand-off choice, returned via [Navigator.pop] so
/// the caller — which owns the [RideBloc] — can dispatch the request. Keeping
/// the bloc out of the dialog avoids a `ProviderNotFoundException` from the
/// overlay context (see [HandOffRideDialog._confirm]).
class HandOffSelection {
  final String externalDriverId;
  final String partnerCompanyId;

  const HandOffSelection({
    required this.externalDriverId,
    required this.partnerCompanyId,
  });
}

/// Dialog that lets a dispatcher hand off a [Requested] ride to an external
/// driver + partner company.  Shows dropdowns backed by the tenant's
/// `/partner-companies` and `/external-drivers` directories and allows the
/// dispatcher to add a new entry inline without leaving the dialog.
class HandOffRideDialog extends StatefulWidget {
  final String rideId;
  final RideService rideService;

  const HandOffRideDialog({
    super.key,
    required this.rideId,
    required this.rideService,
  });

  @override
  State<HandOffRideDialog> createState() => _HandOffRideDialogState();
}

class _HandOffRideDialogState extends State<HandOffRideDialog> {
  List<PartnerCompany>? _companies;
  List<ExternalDriver>? _drivers;
  String? _loadError;

  /// Error from the most recent inline "Add new company/driver" attempt. Shown
  /// under the form so a failed create is not silently swallowed (which left
  /// the dispatcher staring at an unresponsive dialog).
  String? _createError;

  PartnerCompany? _selectedCompany;
  ExternalDriver? _selectedDriver;

  // Inline "add new" state
  bool _addingCompany = false;
  bool _addingDriver = false;

  final _companyNameCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final companies = await widget.rideService.listPartnerCompanies();
      final drivers = await widget.rideService.listExternalDrivers();
      if (mounted) {
        setState(() {
          _companies = companies;
          _drivers = drivers;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  Future<void> _createCompany() async {
    final name = _companyNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _submitting = true;
      _createError = null;
    });
    try {
      final created = await widget.rideService.createPartnerCompany(
        name: name,
        phone: _companyPhoneCtrl.text.trim().isNotEmpty
            ? _companyPhoneCtrl.text.trim()
            : null,
      );
      if (mounted) {
        setState(() {
          _companies = [...?_companies, created];
          _selectedCompany = created;
          _addingCompany = false;
          _companyNameCtrl.clear();
          _companyPhoneCtrl.clear();
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _createError = 'Failed to add company: $e';
        });
      }
    }
  }

  Future<void> _createDriver() async {
    final name = _driverNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _submitting = true;
      _createError = null;
    });
    try {
      final created = await widget.rideService.createExternalDriver(
        name: name,
        phone: _driverPhoneCtrl.text.trim().isNotEmpty
            ? _driverPhoneCtrl.text.trim()
            : null,
        partnerCompanyId: _selectedCompany?.id,
      );
      if (mounted) {
        setState(() {
          _drivers = [...?_drivers, created];
          _selectedDriver = created;
          _addingDriver = false;
          _driverNameCtrl.clear();
          _driverPhoneCtrl.clear();
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _createError = 'Failed to add driver: $e';
        });
      }
    }
  }

  /// Closes the dialog, returning the dispatcher's selection to the caller.
  ///
  /// The dialog deliberately does NOT read [RideBloc] from its own context:
  /// it is mounted in the navigator overlay, which does not inherit the
  /// dashboard's [BlocProvider], so `context.read<RideBloc>()` here would throw
  /// `ProviderNotFoundException` and the button would appear dead. Instead the
  /// caller (which has the bloc in scope) dispatches the hand-off — mirroring
  /// how [CancelRideDialog] hands its result back via the navigator pop value.
  void _confirm(BuildContext dialogCtx) {
    final driver = _selectedDriver;
    final company = _selectedCompany;
    if (driver == null || company == null) return;

    Navigator.of(dialogCtx).pop(
      HandOffSelection(
        externalDriverId: driver.id,
        partnerCompanyId: company.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz, color: AppColors.rideHandedOff),
          SizedBox(width: 8),
          Text('Hand Off Ride'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: _loadError != null
            ? Text(
                'Failed to load: $_loadError',
                style: const TextStyle(color: AppColors.error),
              )
            : _companies == null || _drivers == null
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _buildForm(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              (_selectedDriver != null &&
                  _selectedCompany != null &&
                  !_submitting)
              ? () => _confirm(context)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.rideHandedOff,
          ),
          child: const Text('Hand Off'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final companies = _companies ?? const <PartnerCompany>[];
    final drivers = _drivers ?? const <ExternalDriver>[];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_createError != null) ...[
            Padding(
              key: const Key('handOffCreateError'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _createError ?? '',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          ],
          // ── Partner Company ──
          _sectionLabel('Partner Company'),
          if (!_addingCompany) ...[
            DropdownButton<PartnerCompany>(
              value: _selectedCompany,
              isExpanded: true,
              hint: const Text('Select company'),
              items: companies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCompany = v),
            ),
            const SizedBox(height: 4),
            _addNewLink(
              label: '+ Add new company',
              onTap: () => setState(() => _addingCompany = true),
            ),
          ] else
            _inlineForm(
              fields: [
                _field(_companyNameCtrl, 'Company name *'),
                const SizedBox(height: 8),
                _field(_companyPhoneCtrl, 'Phone (optional)'),
              ],
              onSave: _createCompany,
              onCancel: () => setState(() {
                _addingCompany = false;
                _companyNameCtrl.clear();
                _companyPhoneCtrl.clear();
              }),
              submitting: _submitting,
            ),

          const SizedBox(height: 16),

          // ── External Driver ──
          _sectionLabel('External Driver'),
          if (!_addingDriver) ...[
            DropdownButton<ExternalDriver>(
              value: _selectedDriver,
              isExpanded: true,
              hint: const Text('Select driver'),
              items: drivers
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDriver = v),
            ),
            const SizedBox(height: 4),
            _addNewLink(
              label: '+ Add new driver',
              onTap: () => setState(() => _addingDriver = true),
            ),
          ] else
            _inlineForm(
              fields: [
                _field(_driverNameCtrl, 'Driver name *'),
                const SizedBox(height: 8),
                _field(_driverPhoneCtrl, 'Phone (optional)'),
              ],
              onSave: _createDriver,
              onCancel: () => setState(() {
                _addingDriver = false;
                _driverNameCtrl.clear();
                _driverPhoneCtrl.clear();
              }),
              submitting: _submitting,
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _addNewLink({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.accent,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _inlineForm({
    required List<Widget> fields,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    required bool submitting,
  }) {
    // Follow the active theme: a soft orange tint in light mode, a deep orange
    // surface in dark mode. Without this the inline form would render as a
    // light patch on the dark dialog (the AlertDialog itself is theme-aware via
    // dialogTheme, but this nested Container has to opt in explicitly).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const Key('handOffInlineForm'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.rideHandedOffBgDark
            : AppColors.rideHandedOffBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          // In dark mode the saturated status color doubles as a subtle
          // outline (mirrors RideStatusStyles.getStatusBorderColor).
          color: isDark
              ? AppColors.rideHandedOff.withValues(alpha: 0.4)
              : AppColors.rideHandedOffBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...fields,
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: submitting ? null : onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: submitting ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rideHandedOff,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
