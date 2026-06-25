import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_dimensions.dart';

class CreateRideActionButtons extends StatelessWidget {
  final VoidCallback onCreateRide;
  final VoidCallback onClearForm;

  const CreateRideActionButtons({
    super.key,
    required this.onCreateRide,
    required this.onClearForm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Drive button colors from the theme, NOT a hardcoded AppColors.primary
    // (graphite). These buttons sit inside a colorScheme.surface card (see
    // CreateRideActionsSection) so colorScheme.primary contrasts in both themes:
    // graphite-on-white in light, light-on-dark in dark. Placed bare on the
    // form's always-dark graphite gradient, the graphite primary would match the
    // background and the outlined "Clear Form" button would vanish.
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      builder: (context, state) {
        final isSubmitting = state.status == CreateRideFormStatus.submitting;
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeightLarge,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onCreateRide,
                icon: isSubmitting
                    ? SizedBox(
                        width: AppDimensions.iconSmall,
                        height: AppDimensions.iconSmall,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(
                  isSubmitting ? l10n.creatingRideLabel : l10n.createRideButton,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeightLarge,
              child: OutlinedButton.icon(
                onPressed: isSubmitting ? null : onClearForm,
                icon: const Icon(Icons.clear_all),
                label: Text(l10n.clearFormButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSmall,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
