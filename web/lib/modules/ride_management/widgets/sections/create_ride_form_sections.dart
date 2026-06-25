import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../modules/core/models/person.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import 'create_ride_basic_info_section.dart';
import 'create_ride_location_section.dart';
import 'create_ride_schedule_section.dart';
import 'create_ride_airport_section.dart';
import 'create_ride_notes_section.dart';
import 'create_ride_actions_section.dart';
import 'create_ride_driver_section.dart';

class CreateRideFormSections extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  const CreateRideFormSections({super.key, required this.formKey});

  @override
  Widget build(BuildContext context) {
    final isDriver =
        context.read<AuthBloc>().state.user?.role == PersonRole.driver;

    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CreateRideBasicInfoSection(),
            const SizedBox(height: AppDimensions.paddingMedium),
            const CreateRideLocationSection(),
            if (isDriver) ...[
              const SizedBox(height: AppDimensions.paddingMedium),
              const CreateRideDriverSection(),
            ],
            const SizedBox(height: AppDimensions.paddingMedium),
            // For departure rides the pickup time is computed from the flight
            // departure; a separate picker is shown inside the airport section.
            // For all other rides the operator must set the pickup time manually.
            if (!state.isDepartureAutoCompute)
              CreateRideScheduleSection(
                pickupDateTime:
                    state.manualPickupDateTime ??
                    DateTime.now().add(const Duration(hours: 1)),
              ),
            const SizedBox(height: AppDimensions.paddingMedium),
            CreateRideAirportSection(
              isAirportTransfer: state.isAirportTransfer,
              isArrival: state.isArrival,
              flightNumber: state.flightNumber,
              selectedGate: state.selectedGate,
              selectedTerminal: state.selectedTerminal,
              isDepartureAutoCompute: state.isDepartureAutoCompute,
              flightDepartureTime: state.flightDepartureTime,
              manualPickupDateTime: state.manualPickupDateTime,
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            _NotesSectionToggle(state: state),
            const SizedBox(height: AppDimensions.paddingLarge),
            CreateRideActionsSection(formKey: formKey),
            const SizedBox(height: AppDimensions.paddingXLarge),
          ],
        );
      },
    );
  }
}

class _NotesSectionToggle extends StatelessWidget {
  final CreateRideFormState state;

  const _NotesSectionToggle({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          elevation: 2,
          shadowColor: AppColors.shadowMedium,
          child: SwitchListTile(
            value: state.showNotes,
            onChanged: (_) =>
                context.read<CreateRideFormBloc>().add(const NotesToggled()),
            secondary: Icon(
              Icons.note_alt,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            title: const Text(
              'Notes & Special Requirements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            activeThumbColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: state.showNotes
              ? Padding(
                  padding: const EdgeInsets.only(
                    top: AppDimensions.paddingMedium,
                  ),
                  child: CreateRideNotesSection(
                    notes: state.notes,
                    specialRequirements: state.specialRequirements,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
