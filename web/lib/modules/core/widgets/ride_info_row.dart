import 'package:flutter/material.dart';

import 'copy_icon_button.dart';

class RideInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final String label;

  /// When true, a compact copy icon is shown next to [text] so the operator/
  /// driver can copy the value (address, flight number, …). Off by default —
  /// only paste-worthy fields opt in; a formatted time or price reads oddly on
  /// the clipboard.
  final bool copyable;

  const RideInfoRow({
    super.key,
    required this.icon,
    required this.text,
    required this.label,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Pin the icon to the first line for values that wrap (long addresses).
        if (copyable)
          CopyIconButton(
            value: text,
            label: label,
            padding: const EdgeInsets.only(top: 8),
          ),
      ],
    );
  }
}
