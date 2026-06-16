import 'package:flutter/material.dart';
import '../../../constants/app_styles.dart';

class DelayPickupDialog extends StatefulWidget {
  const DelayPickupDialog({super.key});

  @override
  State<DelayPickupDialog> createState() => _DelayPickupDialogState();
}

class _DelayPickupDialogState extends State<DelayPickupDialog> {
  int _selectedDelay = 15;
  final List<int> _delayOptions = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text(
        'Delay by how long?',
        style: AppStyles.titleMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      content: RadioGroup<int>(
        groupValue: _selectedDelay,
        onChanged: (value) {
          if (value != null) setState(() => _selectedDelay = value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _delayOptions
              .map(
                (delay) => RadioListTile<int>(
                  title: Text(
                    '$delay minutes',
                    style: AppStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  value: delay,
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppStyles.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedDelay),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
