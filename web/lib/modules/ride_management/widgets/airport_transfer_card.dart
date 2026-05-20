import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';

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
    return Material(
      color: AppColors.surface,
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
                  color: Colors.purple[600],
                  size: 24
                ),
                const SizedBox(width: AppDimensions.paddingSmall),
                const Text(
                  'Airport Transfer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            SwitchListTile(
              title: const Text('Airport Transfer'),
              subtitle: const Text('Enable if this is an airport pickup/drop-off'),
              value: isAirportTransfer,
              onChanged: onAirportTransferChanged,
            ),
            if (isAirportTransfer) ...[
              const Divider(),
              const SizedBox(height: AppDimensions.paddingSmall),
              RadioGroup<bool>(
                groupValue: isArrival,
                onChanged: (v) { if (v != null) onArrivalChanged(v); },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flight_takeoff, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Flexible(child: Text('Departure', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        subtitle: const Text('To airport'),
                        value: false,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flight_land, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Flexible(child: Text('Arrival', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        subtitle: const Text('From airport'),
                        value: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                initialValue: flightNumber,
                decoration: InputDecoration(
                  labelText: 'Flight Number',
                  hintText: 'e.g. LH123, BA456',
                  prefixIcon: Icon(
                    isArrival ? Icons.flight_land : Icons.flight_takeoff,
                    color: AppColors.secretaryColor
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                  ),
                ),
                onChanged: onFlightNumberChanged,
                validator: flightNumberValidator ?? (isAirportTransfer ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Flight number is required for airport transfers';
                  }
                  return null;
                } : null),
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Gate',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      initialValue: selectedGate,
                      items: gates.map((gate) => DropdownMenuItem(
                        value: gate,
                        child: Text(gate),
                      )).toList(),
                      onChanged: onGateChanged,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingMedium),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Terminal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      initialValue: selectedTerminal,
                      items: terminals.map((terminal) => DropdownMenuItem(
                        value: terminal,
                        child: Text(terminal),
                      )).toList(),
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
}