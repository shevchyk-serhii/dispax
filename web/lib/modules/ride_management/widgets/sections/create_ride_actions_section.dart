import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../create_ride_action_buttons.dart';

class CreateRideActionsSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  const CreateRideActionsSection({super.key, required this.formKey});

  @override
  Widget build(BuildContext context) {
    return CreateRideActionButtons(
      onCreateRide: () {
        if (formKey.currentState!.validate()) {
          context.read<CreateRideFormBloc>().add(const FormSubmitted());
        }
      },
      onClearForm: () {
        context.read<CreateRideFormBloc>().add(const FormCleared());
      },
    );
  }
}
