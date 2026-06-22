import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../modules/core/models/person.dart';

/// A single cancellation reason: the canonical wire value sent to the backend
/// (matching `CancellationReason.toWire`) plus its human-readable label.
class _CancelReason {
  final String value;
  final String label;
  const _CancelReason(this.value, this.label);
}

/// Reasons a client may state when cancelling their own ride. Operational
/// reasons (client no-show, driver unavailable, vehicle issue) are staff-only:
/// a client cancelling because they "didn't show up" is nonsensical, so they
/// are hidden here and rejected by the backend if forged.
const List<_CancelReason> _clientReasons = [
  _CancelReason('client_request', 'Client Request'),
  _CancelReason('weather', 'Weather'),
  _CancelReason('other', 'Other'),
];

/// Full reason list available to staff (driver / dispatcher / secretary /
/// admin). Mirrors the backend `CancellationReason` enum.
const List<_CancelReason> _staffReasons = [
  _CancelReason('client_no_show', 'Client No-Show'),
  _CancelReason('client_request', 'Client Request'),
  _CancelReason('driver_unavailable', 'Driver Unavailable'),
  _CancelReason('weather', 'Weather'),
  _CancelReason('vehicle_issue', 'Vehicle Issue'),
  _CancelReason('other', 'Other'),
];

class CancelRideDialog extends StatefulWidget {
  /// The role of the user cancelling. Drives which reasons are offered and
  /// whether the optional cancellation-fee field is shown.
  final PersonRole role;

  const CancelRideDialog({super.key, required this.role});

  /// Whether this role may set a cancellation fee. Clients cannot fee
  /// themselves; only staff (dispatcher/secretary/admin/driver) can charge one.
  bool get _canSetFee => role != PersonRole.client;

  List<_CancelReason> get _reasons =>
      role == PersonRole.client ? _clientReasons : _staffReasons;

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

  @override
  Widget build(BuildContext context) {
    final reasons = widget._reasons;
    return AlertDialog(
      title: const Text('Cancel Ride'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please select a reason for cancellation:'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Cancellation Fee (optional)',
                  prefixText: '€ ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Back'),
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
          child: const Text('Cancel Ride'),
        ),
      ],
    );
  }
}
