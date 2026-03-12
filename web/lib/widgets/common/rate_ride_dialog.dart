import 'package:flutter/material.dart';
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
    return AlertDialog(
      title: const Text('Rate Your Ride'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How was your experience?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: starIndex <= _rating ? Colors.amber : Colors.grey,
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
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                hintText: 'Tell us about your experience...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
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
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
