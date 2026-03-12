import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class CancelRideDialog extends StatefulWidget {
  final bool isDispatcher;

  const CancelRideDialog({super.key, this.isDispatcher = false});

  @override
  State<CancelRideDialog> createState() => _CancelRideDialogState();
}

class _CancelRideDialogState extends State<CancelRideDialog> {
  String? _selectedReason;
  final _feeController = TextEditingController();

  static const List<String> _reasons = [
    'Client No-Show',
    'Client Request',
    'Driver Unavailable',
    'Weather',
    'Vehicle Issue',
    'Other',
  ];

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              value: _selectedReason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: _reasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedReason = v),
            ),
            if (widget.isDispatcher) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _feeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cancellation Fee (optional)',
                  prefixText: '\u20AC ',
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
                  Navigator.of(context).pop({
                    'reason': _selectedReason,
                    'fee': fee,
                  });
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
