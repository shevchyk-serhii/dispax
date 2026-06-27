import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import '../create_ride_action_buttons.dart';

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
          if (formKey.currentState!.validate()) {
            context.read<CreateRideFormBloc>().add(const FormSubmitted());
          }
        },
        onClearForm: () {
          context.read<CreateRideFormBloc>().add(const FormCleared());
        },
      ),
    );
  }
}
