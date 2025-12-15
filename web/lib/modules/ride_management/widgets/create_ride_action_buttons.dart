import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../core/navigation_helper.dart';

class CreateRideActionButtons extends StatelessWidget {
  final VoidCallback onCreateRide;
  final VoidCallback onClearForm;

  const CreateRideActionButtons({
    Key? key,
    required this.onCreateRide,
    required this.onClearForm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RideBloc, RideState>(
      listener: (context, state) {
        if (state.hasError) {
          NavigationHelper.showSnackBar(
            context,
            state.errorMessage!,
            isError: true,
          );
        } else if (state.status == RideStateStatus.loaded && !state.isLoading) {

          NavigationHelper.showSnackBar(
            context,
            'Ride created successfully!',
            isError: false,
          );
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeightLarge,
              child: ElevatedButton.icon(
                onPressed: state.isLoading ? null : onCreateRide,
                icon: state.isLoading
                  ? const SizedBox(
                      width: AppDimensions.iconSmall,
                      height: AppDimensions.iconSmall,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Icon(Icons.add_circle_outline),
                label: Text(state.isLoading ? 'Creating Ride...' : 'Create Ride'),
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
                onPressed: onClearForm,
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