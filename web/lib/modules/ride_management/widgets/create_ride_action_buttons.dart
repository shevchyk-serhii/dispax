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
    // (graphite). In dark mode colorScheme.primary is the light foreground, so
    // the outlined "Clear Form" button's icon/label/border stay visible. The
    // old hardcoded graphite rendered the outlined button as a blank border on
    // the dark background (its content was the same near-black as the surface).
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
