import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_dimensions.dart';
import 'create_ride_basic_info_section.dart';
import 'create_ride_location_section.dart';
import 'create_ride_schedule_section.dart';
import 'create_ride_airport_section.dart';
import 'create_ride_notes_section.dart';
import 'create_ride_actions_section.dart';

class CreateRideFormSections extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  const CreateRideFormSections({
    super.key,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CreateRideBasicInfoSection(clientName: state.clientName),
            const SizedBox(height: AppDimensions.paddingMedium),
            CreateRideLocationSection(
              fromAddress: state.fromAddress,
              toAddress: state.toAddress,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            CreateRideScheduleSection(pickupDateTime: state.pickupDateTime),
            const SizedBox(height: AppDimensions.paddingMedium),
            CreateRideAirportSection(
              isAirportTransfer: state.isAirportTransfer,
              isArrival: state.isArrival,
              flightNumber: state.flightNumber,
              selectedGate: state.selectedGate,
              selectedTerminal: state.selectedTerminal,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            CreateRideNotesSection(
              notes: state.notes,
              specialRequirements: state.specialRequirements,
            ),
            const SizedBox(height: AppDimensions.paddingLarge),
            CreateRideActionsSection(formKey: formKey),
            const SizedBox(height: AppDimensions.paddingXLarge),
          ],
        );
      },
    );
  }
}
