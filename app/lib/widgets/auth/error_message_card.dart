import 'package:flutter/material.dart';

class ErrorMessageCard extends StatelessWidget {
  final String message;
  final VoidCallback? onClose;

  const ErrorMessageCard({super.key, required this.message, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
            if (onClose != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }
}
