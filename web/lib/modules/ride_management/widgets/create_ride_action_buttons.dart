import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
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
                    ? const SizedBox(
                        width: AppDimensions.iconSmall,
                        height: AppDimensions.iconSmall,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(isSubmitting ? 'Creating Ride...' : 'Create Ride'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secretaryColor,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
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
                label: const Text('Clear Form'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secretaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
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