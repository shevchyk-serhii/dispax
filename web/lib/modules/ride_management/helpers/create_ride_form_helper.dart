import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/models/location.dart';
import '../models/create_ride_request.dart';
import '../../../constants/app_colors.dart';

class CreateRideFormHelper {
  // Note: Gates and terminals are kept in UI for future backend support
  // Currently, backend doesn't use these fields in CreateRideRequest.toDomain()
  static const List<String> gates = [
    'A1',
    'A2',
    'A3',
    'A4',
    'A5',
    'A6',
    'A7',
    'A8',
    'A9',
    'A10',
    'B1',
    'B2',
    'B3',
    'B4',
    'B5',
    'B6',
    'B7',
    'B8',
    'B9',
    'B10',
    'C1',
    'C2',
    'C3',
    'C4',
    'C5',
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
      final initialTime = TimeOfDay.fromDateTime(currentDateTime);
      final roundedInitial = TimeOfDay(
        hour: initialTime.hour,
        minute: (initialTime.minute / 5).round() * 5 % 60,
      );
      final time = await showTimePicker(
        context: context,
        initialTime: roundedInitial,
      );

      if (time != null && context.mounted) {
        final roundedMinute = (time.minute / 5).round() * 5;
        final newDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour + (roundedMinute == 60 ? 1 : 0),
          roundedMinute == 60 ? 0 : roundedMinute,
        );
        context.read<CreateRideFormBloc>().add(
          PickupDateTimeChanged(newDateTime),
        );
      }
    }
  }

  static void handleFormSubmission(
    BuildContext context,
    CreateRideFormState formState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated || authState.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.authenticationRequiredError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!formState.isNewClient && formState.selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.selectOrCreateClientError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (formState.isNewClient && formState.clientName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.enterClientNameError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // For a new client we use the current user's ID as a placeholder —
    // for the DRIVER role the backend can override clientId anyway
    final clientId = formState.selectedClientId ?? authState.user!.id;

    final createRequest = CreateRideRequest(
      clientId: clientId,
      creatorId: authState.user!.id,
      companyId: authState.user!.companyId ?? '',
      // manualPickupDateTime: null for departure rides without an explicit override
      // signals "compute automatically" to the backend. For all other ride types
      // it carries the operator-selected pickup time.
      manualPickupDateTime: formState.manualPickupDateTime,
      flightDepartureTime: formState.flightDepartureTime,
      from: Location(address: formState.fromAddress.trim()),
      to: Location(address: formState.toAddress.trim()),
      clientName: formState.clientName.trim(),
      newClientPhone: formState.isNewClient
          ? formState.newClientPhone.trim()
          : null,
      flightNumber:
          formState.isAirportTransfer && formState.flightNumber.isNotEmpty
          ? formState.flightNumber.trim()
          : null,
      isAirportTransfer: formState.isAirportTransfer,
      isArrival: formState.isArrival,
      notes: formState.notes.trim().isNotEmpty ? formState.notes.trim() : null,
      specialRequirements: formState.specialRequirements.isNotEmpty
          ? formState.specialRequirements
          : null,
      tags: formState.tags.isNotEmpty ? formState.tags : null,
      driverId: formState.selectedDriverId,
      vehicleClass: formState.selectedVehicleClass,
      paymentMethod: formState.selectedPaymentMethod,
      price: formState.price,
    );

    context.read<RideBloc>().add(RideCreateRequested(request: createRequest));
  }
}
