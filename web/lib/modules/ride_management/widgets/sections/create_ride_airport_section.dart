import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';
import '../../helpers/create_ride_form_helper.dart';
import '../airport_transfer_card.dart';

class CreateRideAirportSection extends StatelessWidget {
  final bool isAirportTransfer;
  final bool isArrival;
  final String flightNumber;
  final String? selectedGate;
  final String? selectedTerminal;

  /// True when the departure auto-compute path is active (airport transfer,
  /// isArrival = false). Controls whether the departure pickers are shown.
  final bool isDepartureAutoCompute;

  /// Current flight departure date-time (departure rides only).
  final DateTime? flightDepartureTime;

  /// Current manual pickup override (optional for departure rides).
  final DateTime? manualPickupDateTime;

  const CreateRideAirportSection({
    super.key,
    required this.isAirportTransfer,
    required this.isArrival,
    required this.flightNumber,
    required this.selectedGate,
    required this.selectedTerminal,
    this.isDepartureAutoCompute = false,
    this.flightDepartureTime,
    this.manualPickupDateTime,
  });

  // ─── Flight departure date-time picker ──────────────────────────────────────

  Future<void> _selectFlightDepartureTime(BuildContext context) async {
    final initial =
        flightDepartureTime ?? DateTime.now().add(const Duration(hours: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    final initialTime = TimeOfDay.fromDateTime(initial);
    final roundedInitial = TimeOfDay(
      hour: initialTime.hour,
      minute: (initialTime.minute / 5).round() * 5 % 60,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: roundedInitial,
    );
    if (time == null || !context.mounted) return;

    final roundedMinute = (time.minute / 5).round() * 5;
    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour + (roundedMinute == 60 ? 1 : 0),
      roundedMinute == 60 ? 0 : roundedMinute,
    );
    context.read<CreateRideFormBloc>().add(
      FlightDepartureTimeChanged(newDateTime),
    );
  }

  // ─── Manual pickup date-time picker (optional override for departures) ──────

  Future<void> _selectManualPickupTime(BuildContext context) async {
    final initial =
        manualPickupDateTime ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    final initialTime = TimeOfDay.fromDateTime(initial);
    final roundedInitial = TimeOfDay(
      hour: initialTime.hour,
      minute: (initialTime.minute / 5).round() * 5 % 60,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: roundedInitial,
    );
    if (time == null || !context.mounted) return;

    final roundedMinute = (time.minute / 5).round() * 5;
    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour + (roundedMinute == 60 ? 1 : 0),
      roundedMinute == 60 ? 0 : roundedMinute,
    );
    context.read<CreateRideFormBloc>().add(
      ManualPickupTimeChanged(newDateTime),
    );
  }

  // ─── Widget ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AirportTransferCard(
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
            context.read<CreateRideFormBloc>().add(
              AirportTransferToggled(value),
            );
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
        ),
        // Departure pickers are shown only for airport departure rides.
        // For arrival rides and non-airport rides the schedule section above
        // already provides the (required) manual pickup time.
        if (isDepartureAutoCompute) ...[
          const SizedBox(height: AppDimensions.paddingMedium),
          _DeparturePickers(
            flightDepartureTime: flightDepartureTime,
            manualPickupDateTime: manualPickupDateTime,
            onSelectFlightDeparture: () => _selectFlightDepartureTime(context),
            onSelectManualPickup: () => _selectManualPickupTime(context),
            onClearManualPickup: () => context.read<CreateRideFormBloc>().add(
              const ManualPickupTimeChanged(null),
            ),
          ),
        ],
        // For airport ARRIVAL rides the pickup is set in the schedule section above;
        // this optional picker captures the flight ARRIVAL time, which the backend uses
        // to compute the recommended terminal-entry time ("Einfahrt um"). Reuses the same
        // flightDepartureTime field (sent as flightTime → scheduledTime); it never touches pickup.
        if (isAirportTransfer && isArrival) ...[
          const SizedBox(height: AppDimensions.paddingMedium),
          _ArrivalFlightTimePicker(
            flightArrivalTime: flightDepartureTime,
            onSelectFlightArrival: () => _selectFlightDepartureTime(context),
            onClearFlightArrival: () => context.read<CreateRideFormBloc>().add(
              const FlightDepartureTimeChanged(null),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Departure pickers card ───────────────────────────────────────────────────

class _DeparturePickers extends StatelessWidget {
  final DateTime? flightDepartureTime;
  final DateTime? manualPickupDateTime;
  final VoidCallback onSelectFlightDeparture;
  final VoidCallback onSelectManualPickup;
  final VoidCallback onClearManualPickup;

  const _DeparturePickers({
    required this.flightDepartureTime,
    required this.manualPickupDateTime,
    required this.onSelectFlightDeparture,
    required this.onSelectManualPickup,
    required this.onClearManualPickup,
  });

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        'at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final flightDepartureTime = this.flightDepartureTime;
    final manualPickupDateTime = this.manualPickupDateTime;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      elevation: 2,
      shadowColor: AppColors.shadowMedium,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.formCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flight_takeoff, color: AppColors.info, size: 24),
                const SizedBox(width: AppDimensions.paddingSmall),
                const Text(
                  'Departure Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),

            // ── Required: flight departure date-time ─────────────────────────
            InkWell(
              onTap: onSelectFlightDeparture,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: flightDepartureTime == null
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: flightDepartureTime == null
                          ? Theme.of(context).colorScheme.error
                          : AppColors.info,
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flight departure time *',
                            style: TextStyle(
                              fontSize: 12,
                              color: flightDepartureTime == null
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            flightDepartureTime != null
                                ? _formatDateTime(flightDepartureTime)
                                : 'Tap to select flight departure time',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: flightDepartureTime == null
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.paddingMedium),

            // ── Optional: manual pickup override ────────────────────────────
            InkWell(
              onTap: onSelectManualPickup,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: manualPickupDateTime != null
                          ? AppColors.warningStrong
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup time (optional — computed if blank)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            manualPickupDateTime != null
                                ? _formatDateTime(manualPickupDateTime)
                                : 'Computed automatically from flight departure',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: manualPickupDateTime == null
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (manualPickupDateTime != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Clear — revert to automatic computation',
                        onPressed: onClearManualPickup,
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Arrival flight-time picker (optional) ─────────────────────────────────────
//
// For an airport ARRIVAL the pickup time is set in the schedule section; this captures
// the flight ARRIVAL time so the backend can compute the recommended terminal-entry
// time. Optional — if blank, the card simply omits the "Einfahrt um" line.

class _ArrivalFlightTimePicker extends StatelessWidget {
  final DateTime? flightArrivalTime;
  final VoidCallback onSelectFlightArrival;
  final VoidCallback onClearFlightArrival;

  const _ArrivalFlightTimePicker({
    required this.flightArrivalTime,
    required this.onSelectFlightArrival,
    required this.onClearFlightArrival,
  });

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        'at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final flightArrivalTime = this.flightArrivalTime;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      elevation: 2,
      shadowColor: AppColors.shadowMedium,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.formCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flight_land, color: AppColors.info, size: 24),
                const SizedBox(width: AppDimensions.paddingSmall),
                const Text(
                  'Arrival Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            InkWell(
              onTap: onSelectFlightArrival,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: flightArrivalTime != null
                          ? AppColors.info
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flight arrival time (optional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            flightArrivalTime != null
                                ? _formatDateTime(flightArrivalTime)
                                : 'Tap to set — enables the terminal-entry time',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: flightArrivalTime == null
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (flightArrivalTime != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Clear flight arrival time',
                        onPressed: onClearFlightArrival,
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
