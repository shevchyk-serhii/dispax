import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
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
      backgroundColor: AppColors.surface,
      title: Text(
        'Delay by how long?',
        style: AppStyles.titleMedium.copyWith(color: AppColors.textPrimary),
      ),
      content: RadioGroup<int>(
        groupValue: _selectedDelay,
        onChanged: (value) {
          if (value != null) setState(() => _selectedDelay = value);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _delayOptions.map((delay) => RadioListTile<int>(
            title: Text(
              '$delay minutes',
              style: AppStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            ),
            value: delay,
          )).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppStyles.labelMedium.copyWith(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedDelay),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}