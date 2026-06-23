import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../constants/app_colors.dart';
import '../../modules/core/models/person.dart';

/// A single cancellation reason: the canonical wire value sent to the backend
/// (matching `CancellationReason.toWire`) plus its human-readable label.
class _CancelReason {
  final String value;
  final String label;
  const _CancelReason(this.value, this.label);
}

class CancelRideDialog extends StatefulWidget {
  /// The role of the user cancelling. Drives which reasons are offered and
  /// whether the optional cancellation-fee field is shown.
  final PersonRole role;

  const CancelRideDialog({super.key, required this.role});

  /// Whether this role may set a cancellation fee. Clients cannot fee
  /// themselves; only staff (dispatcher/secretary/admin/driver) can charge one.
  bool get _canSetFee => role != PersonRole.client;

  @override
  State<CancelRideDialog> createState() => _CancelRideDialogState();
}

class _CancelRideDialogState extends State<CancelRideDialog> {
  String? _selectedReason;
  final _feeController = TextEditingController();

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  List<_CancelReason> _buildClientReasons(AppLocalizations l10n) => [
    _CancelReason('client_request', l10n.cancellationReasonClientRequest),
    _CancelReason('weather', l10n.cancellationReasonWeather),
    _CancelReason('other', l10n.cancellationReasonOther),
  ];

  List<_CancelReason> _buildStaffReasons(AppLocalizations l10n) => [
    _CancelReason('client_no_show', l10n.cancellationReasonClientNoShow),
    _CancelReason('client_request', l10n.cancellationReasonClientRequest),
    _CancelReason(
      'driver_unavailable',
      l10n.cancellationReasonDriverUnavailable,
    ),
    _CancelReason('weather', l10n.cancellationReasonWeather),
    _CancelReason('vehicle_issue', l10n.cancellationReasonVehicleIssue),
    _CancelReason('other', l10n.cancellationReasonOther),
  ];

  List<_CancelReason> _buildReasons(AppLocalizations l10n) =>
      widget.role == PersonRole.client
      ? _buildClientReasons(l10n)
      : _buildStaffReasons(l10n);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reasons = _buildReasons(l10n);
    return AlertDialog(
      title: Text(l10n.cancelRideDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.selectCancellationReason),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: InputDecoration(
                labelText: l10n.cancellationReasonLabel,
                border: const OutlineInputBorder(),
              ),
              items: reasons
                  .map(
                    (r) =>
                        DropdownMenuItem(value: r.value, child: Text(r.label)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedReason = v),
            ),
            if (widget._canSetFee) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _feeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.cancellationFeeLabel,
                  prefixText: '€ ',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  final fee = double.tryParse(_feeController.text);
                  Navigator.of(
                    context,
                  ).pop({'reason': _selectedReason, 'fee': fee});
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.cancelRideDialogTitle),
        ),
      ],
    );
  }
}
