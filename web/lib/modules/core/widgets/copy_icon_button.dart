import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dispax/l10n/app_localizations.dart';

/// A small, compact "copy to clipboard" icon that sits next to a value (address,
/// flight number, phone, …). Tapping it copies [value] and shows a brief
/// "{label} copied" SnackBar so it's clear the copy worked. The [label] names
/// the field in the toast (e.g. "Pickup", "Flight number") and doubles as the
/// tooltip context.
///
/// Renders nothing when there is nothing to copy (blank [value]) — an icon that
/// copies an empty string is worse than no icon.
///
/// This is the shared idiom for copyable ride data; add it beside any value the
/// operator/driver may need to paste elsewhere.
class CopyIconButton extends StatelessWidget {
  final String value;
  final String label;

  /// Vertical alignment of the icon within its row. Values that wrap to several
  /// lines (long addresses) look best pinning the icon to the first line, so the
  /// caller can pass a top padding via [padding].
  final EdgeInsetsGeometry padding;

  const CopyIconButton({
    super.key,
    required this.value,
    required this.label,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: padding,
      child: IconButton(
        icon: const Icon(Icons.copy, size: 18),
        tooltip: l10n.copyTooltip,
        // Keep the tap target compact: a default IconButton is 48×48 with
        // padding and would blow up these dense label+value rows (and this repo
        // has a history of ride-card overflow at narrow widths).
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.copiedToClipboard(label)),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
