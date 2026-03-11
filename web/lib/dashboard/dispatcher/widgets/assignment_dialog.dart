import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';

class AssignmentDialog extends StatelessWidget {
  final Ride ride;
  final String driverLabel;
  final String driverId;
  final List<Ride> conflicts;
  final VoidCallback onConfirm;

  const AssignmentDialog({
    super.key,
    required this.ride,
    required this.driverLabel,
    required this.driverId,
    required this.conflicts,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Ride'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Ride Details', [
              _buildRow('Client', ride.clientName),
              _buildRow('Time', DateFormat('dd.MM.yyyy HH:mm').format(ride.pickupDateTime)),
              _buildRow('From', ride.from.address),
              _buildRow('To', ride.to.address),
              if (ride.flightNumber != null)
                _buildRow('Flight', ride.flightNumber!),
            ]),
            const SizedBox(height: 16),
            _buildSection('Assign To', [
              _buildRow('Driver', driverLabel),
            ]),
            if (conflicts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rideCancelledBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.rideCancelledBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule Conflicts',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.rideCancelledText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...conflicts.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${DateFormat('HH:mm').format(c.pickupDateTime)} - ${c.from.address} -> ${c.to.address}',
                        style: TextStyle(fontSize: 13, color: AppColors.rideCancelledText),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: conflicts.isNotEmpty ? AppColors.warning : AppColors.primary,
          ),
          child: Text(
            conflicts.isNotEmpty ? 'Assign Anyway' : 'Assign',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text('$label:', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
