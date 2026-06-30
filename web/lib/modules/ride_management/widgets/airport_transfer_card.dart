import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../helpers/flight_number_input.dart';
import 'clearable_text_field.dart';

class AirportTransferCard extends StatelessWidget {
  final bool isAirportTransfer;
  final bool isArrival;
  final String flightNumber;
  final ValueChanged<String>? onFlightNumberChanged;
  final String? selectedGate;
  final String? selectedTerminal;
  final List<String> gates;
  final List<String> terminals;
  final ValueChanged<bool> onAirportTransferChanged;
  final ValueChanged<bool> onArrivalChanged;
  final ValueChanged<String?> onGateChanged;
  final ValueChanged<String?> onTerminalChanged;
  final String? Function(String?)? flightNumberValidator;

  const AirportTransferCard({
    super.key,
    required this.isAirportTransfer,
    required this.isArrival,
    required this.flightNumber,
    this.onFlightNumberChanged,
    required this.selectedGate,
    required this.selectedTerminal,
    required this.gates,
    required this.terminals,
    required this.onAirportTransferChanged,
    required this.onArrivalChanged,
    required this.onGateChanged,
    required this.onTerminalChanged,
    this.flightNumberValidator,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      elevation: 2,
      shadowColor: AppColors.shadowMedium,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAirportTransfer
                      ? (isArrival ? Icons.flight_land : Icons.flight_takeoff)
                      : Icons.flight,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                Text(
                  l10n.airportTransferLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            SwitchListTile(
              title: Text(l10n.airportTransferLabel),
              subtitle: Text(l10n.airportTransferHint),
              value: isAirportTransfer,
              onChanged: onAirportTransferChanged,
            ),
            if (isAirportTransfer) ...[
              const Divider(),
              const SizedBox(height: AppDimensions.paddingSmall),
              RadioGroup<bool>(
                groupValue: isArrival,
                onChanged: (v) {
                  if (v != null) onArrivalChanged(v);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flight_takeoff,
                              size: 16,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.airportDepartureLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(l10n.airportDepartureHint),
                        value: false,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flight_land,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.airportArrivalLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(l10n.airportArrivalHint),
                        value: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              ClearableTextField(
                value: flightNumber,
                labelText: l10n.flightNumberLabel,
                hintText: l10n.flightNumberHint,
                prefixIconData: isArrival
                    ? Icons.flight_land
                    : Icons.flight_takeoff,
                prefixIconColor: AppColors.secretaryColor,
                // Always upper-case as the user types (LH429, not lh429).
                inputFormatters: const [UpperCaseTextFormatter()],
                onChanged: onFlightNumberChanged ?? (_) {},
                validator:
                    flightNumberValidator ??
                    _defaultFlightNumberValidator(l10n),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: l10n.gateLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      // Only seed the dropdown with a value that is actually in
                      // the option list; an off-list value (e.g. a real airport
                      // gate like "K14" copied from a tracked ride) would trip
                      // DropdownButtonFormField's "exactly one item" assertion.
                      initialValue: gates.contains(selectedGate)
                          ? selectedGate
                          : null,
                      items: gates
                          .map(
                            (gate) => DropdownMenuItem(
                              value: gate,
                              child: Text(gate),
                            ),
                          )
                          .toList(),
                      onChanged: onGateChanged,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingMedium),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: l10n.terminalLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      initialValue: terminals.contains(selectedTerminal)
                          ? selectedTerminal
                          : null,
                      items: terminals
                          .map(
                            (terminal) => DropdownMenuItem(
                              value: terminal,
                              child: Text(terminal),
                            ),
                          )
                          .toList(),
                      onChanged: onTerminalChanged,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Default validator when no [flightNumberValidator] is supplied: the number is
  /// optional (empty passes — an airport transfer can be booked before the flight
  /// is known), but a non-empty value must look like a real flight number.
  String? Function(String?) _defaultFlightNumberValidator(
    AppLocalizations l10n,
  ) {
    return (value) {
      final raw = value?.trim() ?? '';
      if (raw.isEmpty) return null;
      return FlightNumber.isValid(raw) ? null : l10n.flightNumberInvalidFormat;
    };
  }
}
