import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../helpers/create_ride_form_helper.dart';
import '../airport_transfer_card.dart';

class CreateRideAirportSection extends StatelessWidget {
  final bool isAirportTransfer;
  final bool isArrival;
  final String flightNumber;
  final String? selectedGate;
  final String? selectedTerminal;

  const CreateRideAirportSection({
    super.key,
    required this.isAirportTransfer,
    required this.isArrival,
    required this.flightNumber,
    required this.selectedGate,
    required this.selectedTerminal,
  });

  @override
  Widget build(BuildContext context) {
    return AirportTransferCard(
      isAirportTransfer: isAirportTransfer,
      isArrival: isArrival,
      flightNumber: flightNumber,
      onFlightNumberChanged: (value) {
        context.read<CreateRideFormBloc>().add(FlightNumberChanged(value));
      },
      selectedGate: selectedGate,
      selectedTerminal: selectedTerminal,
      gates: CreateRideFormHelper.gates,
      terminals: CreateRideFormHelper.terminals,
      onAirportTransferChanged: (value) {
        context.read<CreateRideFormBloc>().add(AirportTransferToggled(value));
      },
      onArrivalChanged: (value) {
        context.read<CreateRideFormBloc>().add(ArrivalToggled(value));
      },
      onGateChanged: (value) {
        context.read<CreateRideFormBloc>().add(GateSelected(value));
      },
      onTerminalChanged: (value) {
        context.read<CreateRideFormBloc>().add(TerminalSelected(value));
      },
      flightNumberValidator: isAirportTransfer
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Flight number is required for airport transfers';
              }
              return null;
            }
          : null,
    );
  }
}
