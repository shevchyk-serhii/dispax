// Client-facing Payment screen (presentational stub).
//
// Payment processing is not yet implemented in the backend (see billing module).
// This screen shows the client's saved payment methods and is purely a UI stub.
// TODO: Wire into client account settings or ride-details screen once the
//       billing module exposes a client payment-method endpoint.
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';

class ClientPaymentScreen extends StatelessWidget {
  const ClientPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _GraphiteHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FeaturedCardWidget(),
                    const SizedBox(height: 24),
                    _buildSectionLabel(
                      context,
                      l10n.paymentMethodsSectionLabel,
                    ),
                    const SizedBox(height: 10),
                    _PaymentMethodsList(),
                    const SizedBox(height: 16),
                    _AddPaymentMethodButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.06 * 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────────

class _GraphiteHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Text(
                l10n.clientPaymentTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Featured card ─────────────────────────────────────────────────────────────

class _FeaturedCardWidget extends StatelessWidget {
  const _FeaturedCardWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF27272A), // brand700
            Color(0xFF09090B), // brand900/primaryDark
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Accent radial glow top-right
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chip + VISA row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // EMV chip simulation
                    Container(
                      width: 38,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFC0932A)],
                        ),
                      ),
                    ),
                    // VISA text
                    const Text(
                      'VISA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Card number
                const Text(
                  '•••• •••• •••• 4821',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.14 * 17,
                  ),
                ),

                const SizedBox(height: 12),

                // Cardholder + expiry row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CARDHOLDER',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'M. KELLER',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '08/28',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment methods list ─────────────────────────────────────────────────────

class _PaymentMethodsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark ? AppColors.borderDark : AppColors.borderPrimary;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // VISA row (selected)
          _buildVisaRow(context, cs, isDark),

          Divider(height: 1, color: borderColor),

          // Corporate invoice row
          _buildInvoiceRow(context, cs, isDark),
        ],
      ),
    );
  }

  Widget _buildVisaRow(BuildContext context, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // VISA badge
          Container(
            width: 36,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F71),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: const Text(
              'VISA',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              '•••• 4821',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),

          // Selected indicator
          Icon(Icons.check_circle, color: AppColors.accent, size: 20),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(BuildContext context, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),

          const SizedBox(width: 12),

          Text(
            AppLocalizations.of(context)!.corporateInvoiceLabel,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add payment method button ────────────────────────────────────────────────

class _AddPaymentMethodButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: () {
          // TODO: implement add-payment-method flow
        },
        icon: const Icon(Icons.add, size: 18),
        label: Text(
          AppLocalizations.of(context)!.addPaymentMethodButton,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: const BorderSide(color: Color(0xFFD4D4D8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
