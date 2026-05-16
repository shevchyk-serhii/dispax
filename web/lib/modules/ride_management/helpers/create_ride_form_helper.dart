import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/models/location.dart';
import '../models/create_ride_request.dart';

class CreateRideFormHelper {
  // Note: Gates and terminals are kept in UI for future backend support
  // Currently, backend doesn't use these fields in CreateRideRequest.toDomain()
  static const List<String> gates = [
    'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'A10',
    'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8', 'B9', 'B10',
    'C1', 'C2', 'C3', 'C4', 'C5',
  ];

  static const List<String> terminals = ['1', '2', '3'];

  static Future<void> selectDateTime(
    BuildContext context,
    DateTime currentDateTime,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: currentDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentDateTime),
      );

      if (time != null && context.mounted) {
        final newDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        context.read<CreateRideFormBloc>().add(PickupDateTimeChanged(newDateTime));
      }
    }
  }

  static void handleFormSubmission(
    BuildContext context,
    CreateRideFormState formState,
  ) {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated || authState.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (formState.selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a client'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final createRequest = CreateRideRequest(
      clientId: formState.selectedClientId!,
      creatorId: authState.user!.id,
      companyId: authState.user!.companyId ?? '',
      pickupDateTime: formState.pickupDateTime,
      from: Location(address: formState.fromAddress.trim()),
      to: Location(address: formState.toAddress.trim()),
      clientName: formState.clientName.trim(),
      flightNumber: formState.isAirportTransfer && formState.flightNumber.isNotEmpty
          ? formState.flightNumber.trim()
          : null,
      isAirportTransfer: formState.isAirportTransfer,
      notes: formState.notes.trim().isNotEmpty ? formState.notes.trim() : null,
      specialRequirements: formState.specialRequirements.isNotEmpty
          ? formState.specialRequirements
          : null,
    );

    context.read<RideBloc>().add(RideCreateRequested(request: createRequest));
    context.read<CreateRideFormBloc>().add(const FormCleared());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ride created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
