import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
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
            const CreateRideBasicInfoSection(),
            const SizedBox(height: AppDimensions.paddingMedium),
            const CreateRideLocationSection(),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          elevation: 2,
          shadowColor: AppColors.shadowMedium,
          child: SwitchListTile(
            value: state.showNotes,
            onChanged: (_) => context.read<CreateRideFormBloc>().add(const NotesToggled()),
            secondary: Icon(Icons.note_alt, color: AppColors.secretaryColor, size: 20),
            title: const Text(
              'Notes & Special Requirements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            activeThumbColor: AppColors.secretaryColor,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: state.showNotes
              ? Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.paddingMedium),
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
