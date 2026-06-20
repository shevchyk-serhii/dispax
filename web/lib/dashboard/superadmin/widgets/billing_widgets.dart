// Shared billing UI widgets, used by the billing/expense/DATEV screens
// (web/lib/screens/billing_*.dart, expense_screen.dart) and superadmin views.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

// ─── EUR Number Formatter ────────────────────────────────────────────────────

final _eurFmt = NumberFormat.currency(locale: 'de_DE', symbol: '€');

/// Formats [amount] as a German-locale EUR string (e.g. "€ 1.234,56").
String fmtEur(double amount) => _eurFmt.format(amount);

// ─── Graphite Top Bar ────────────────────────────────────────────────────────

/// Graphite (#18181B) top bar with title + optional subtitle.
/// Always white-on-graphite regardless of theme brightness.
class BillingTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const BillingTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.primary, // #18181B graphite
          border: Border(
            bottom: BorderSide(color: Color(0xFF27272A), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: SafeArea(
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA), // textLight on graphite
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Tile ───────────────────────────────────────────────────────────────

enum StatTileVariant { dark, light }

/// Summary stat tile.
/// [variant] == dark → graphite tile (Outstanding); light → theme surface.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final StatTileVariant variant;
  final Color?
  valueColor; // null = default (white for dark, onSurface for light)

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.variant = StatTileVariant.light,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = variant == StatTileVariant.dark;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? AppColors
              .primary // always graphite regardless of theme
        : (isDarkTheme
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariant);

    final labelColor = isDark
        ? const Color(0xFFA1A1AA)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    final defaultValueColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final resolvedValueColor = valueColor ?? defaultValueColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: isDark
            ? const Border.fromBorderSide(BorderSide(color: Color(0xFF27272A)))
            : Border.all(
                color: isDarkTheme
                    ? AppColors.borderDark
                    : AppColors.borderPrimary,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: resolvedValueColor,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge (pill) ─────────────────────────────────────────────────────

// Internal badge kind — encoded as int so that the private type does not leak
// into the public API of BillingStatusBadge.
// 0=paid  1=pending  2=overdue  3=draft
const int _kBadgePaid = 0;
const int _kBadgePending = 1;
const int _kBadgeOverdue = 2;
const int _kBadgeDraft = 3;

/// Pill badge for invoice/billing status.
class BillingStatusBadge extends StatelessWidget {
  final String label;
  final int _kind;

  const BillingStatusBadge.paid({super.key, required this.label})
    : _kind = _kBadgePaid;

  const BillingStatusBadge.pending({super.key, required this.label})
    : _kind = _kBadgePending;

  const BillingStatusBadge.overdue({super.key, required this.label})
    : _kind = _kBadgeOverdue;

  const BillingStatusBadge.draft({super.key, required this.label})
    : _kind = _kBadgeDraft;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, border, fg) = _colors(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  (Color, Color, Color) _colors(bool isDark) {
    // (background, border, foreground). Dark variants reuse the ride-status
    // dark tokens (same hues) so badges stay legible on a dark surface.
    if (_kind == _kBadgePaid) {
      return isDark
          ? (
              AppColors.rideCompletedBgDark,
              AppColors.rideCompletedBgDark,
              AppColors.rideCompletedTextDark,
            )
          : (
              const Color(0xFFF0FDF4),
              const Color(0xFF86EFAC),
              const Color(0xFF166534),
            );
    }
    if (_kind == _kBadgePending) {
      return isDark
          ? (
              AppColors.rideRequestedBgDark,
              AppColors.rideRequestedBgDark,
              AppColors.rideRequestedTextDark,
            )
          : (
              const Color(0xFFFFFBEB),
              const Color(0xFFFCD34D),
              const Color(0xFF92400E),
            );
    }
    if (_kind == _kBadgeOverdue) {
      return isDark
          ? (
              AppColors.rideCancelledBgDark,
              AppColors.rideCancelledBgDark,
              AppColors.rideCancelledTextDark,
            )
          : (
              const Color(0xFFFEF2F2),
              const Color(0xFFFCA5A5),
              const Color(0xFF991B1B),
            );
    }
    // draft
    return (
      isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      isDark ? AppColors.borderDark : AppColors.borderSecondary,
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
    );
  }
}

// ─── Outlined Button (Export DATEV style) ────────────────────────────────────

/// Small outlined button — border #D4D4D8, h38, radius10.
class BillingOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const BillingOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
          side: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFD4D4D8),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: child,
      ),
    );
  }
}

/// Graphite filled button — #18181B background, white text, h38, radius10.
class BillingGraphiteButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const BillingGraphiteButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: child,
      ),
    );
  }
}
