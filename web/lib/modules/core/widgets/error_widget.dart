import 'package:flutter/material.dart';

class ErrorDisplayWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  /// Label for the retry button. Optional so callers can localize it; falls back
  /// to "Try again" for the (few) existing call sites that don't pass one.
  final String? retryLabel;
  final IconData? icon;

  const ErrorDisplayWidget({
    super.key,
    this.title = 'Error loading data',
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(retryLabel ?? 'Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
