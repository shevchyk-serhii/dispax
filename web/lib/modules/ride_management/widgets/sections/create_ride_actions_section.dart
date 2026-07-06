import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import '../create_ride_action_buttons.dart';

/// Maps an unmet form requirement to a localized "what's missing" message so the
/// user learns exactly which field to fill instead of the submit silently doing
/// nothing.
String missingRequirementMessage(
  CreateRideRequirement requirement,
  AppLocalizations l10n,
) {
  switch (requirement) {
    case CreateRideRequirement.client:
      return l10n.selectOrCreateClientError;
    case CreateRideRequirement.fromAddress:
      return l10n.enterFromAddressError;
    case CreateRideRequirement.toAddress:
      return l10n.enterToAddressError;
    case CreateRideRequirement.flightNumber:
      return l10n.flightNumberRequired;
    case CreateRideRequirement.addressesEqual:
      return l10n.addressesMustDifferError;
    case CreateRideRequirement.pickupTime:
      return l10n.selectPickupTimeError;
    case CreateRideRequirement.flightDepartureTime:
      return l10n.selectFlightDepartureError;
  }
}

class CreateRideActionsSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  const CreateRideActionsSection({super.key, required this.formKey});

  @override
  Widget build(BuildContext context) {
    // The form body sits on an always-dark graphite gradient, and every other
    // section wraps its content in a colorScheme.surface card. The action
    // buttons must do the same: bare on the dark gradient, the "Clear Form"
    // OutlinedButton (foreground/border = colorScheme.primary) renders graphite
    // on graphite in light mode and disappears. On a surface card the primary
    // colors contrast in both themes, so the buttons stay visible and the block
    // matches the rest of the form.
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppDimensions.formCardPadding),
      child: CreateRideActionButtons(
        onCreateRide: () {
          // Run the text-field validators (from/to addresses) first.
          if (!(formKey.currentState?.validate() ?? false)) return;
          // The Create button stays tappable even when non-text controls (client,
          // pickup time, flight number) are unset, and the submit handler no-ops
          // when !isValid — which used to swallow the tap with no feedback. Surface
          // the first missing requirement so the user knows exactly what to fix.
          final missing = context
              .read<CreateRideFormBloc>()
              .state
              .firstMissingRequirement;
          if (missing != null) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(missingRequirementMessage(missing, l10n)),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          context.read<CreateRideFormBloc>().add(const FormSubmitted());
        },
        onClearForm: () {
          context.read<CreateRideFormBloc>().add(const FormCleared());
        },
      ),
    );
  }
}
