import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';

class AirportTransferCard extends StatelessWidget {
  final bool isAirportTransfer;
  final bool isArrival;
  final TextEditingController flightNumberController;
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
    Key? key,
    required this.isAirportTransfer,
    required this.isArrival,
    required this.flightNumberController,
    required this.selectedGate,
    required this.selectedTerminal,
    required this.gates,
    required this.terminals,
    required this.onAirportTransferChanged,
    required this.onArrivalChanged,
    required this.onGateChanged,
    required this.onTerminalChanged,
    this.flightNumberValidator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
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
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flight_takeoff, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          const Text('Departure'),
                        ],
                      ),
                      subtitle: const Text('To airport'),
                      value: false,
                      groupValue: isArrival,
                      onChanged: (value) => onArrivalChanged(value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flight_land, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          const Text('Arrival'),
                        ],
                      ),
                      subtitle: const Text('From airport'),
                      value: true,
                      groupValue: isArrival,
                      onChanged: (value) => onArrivalChanged(value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingMedium),
              TextFormField(
                controller: flightNumberController,
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
                      ),
                      value: selectedGate,
                      items: gates.map((gate) => DropdownMenuItem(
                        value: gate,
                        child: Text('Gate $gate'),
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
                      ),
                      value: selectedTerminal,
                      items: terminals.map((terminal) => DropdownMenuItem(
                        value: terminal,
                        child: Text('Terminal $terminal'),
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