import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../constants/app_colors.dart';

class RateRideDialog extends StatefulWidget {
  final String rideId;

  const RateRideDialog({super.key, required this.rideId});

  @override
  State<RateRideDialog> createState() => _RateRideDialogState();
}

class _RateRideDialogState extends State<RateRideDialog> {
  int _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.rateThisRide),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.rateRideExperienceQuestion),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: starIndex <= _rating
                        ? AppColors.warning
                        : Theme.of(context).colorScheme.outlineVariant,
                    size: 36,
                  ),
                  onPressed: () => setState(() => _rating = starIndex),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.rateRideCommentLabel,
                hintText: l10n.rateRideCommentHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _rating == 0
              ? null
              : () {
                  Navigator.of(context).pop({
                    'rating': _rating,
                    'comment': _commentController.text.isEmpty
                        ? null
                        : _commentController.text,
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
