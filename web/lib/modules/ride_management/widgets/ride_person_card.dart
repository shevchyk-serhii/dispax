import 'package:flutter/material.dart';
import '../../core/models/person.dart';
import '../../../constants/app_colors.dart';

class RidePersonCard extends StatelessWidget {
  final Person person;
  final bool isDriver;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  const RidePersonCard({
    Key? key,
    required this.person,
    this.isDriver = false,
    this.onCall,
    this.onMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDriver ? Colors.blue[100] : Colors.green[100],
                  child: Icon(
                    isDriver ? Icons.drive_eta : Icons.person,
                    color: isDriver ? Colors.blue[700] : Colors.green[700],
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDriver ? 'Driver' : 'Client',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (person.phone?.isNotEmpty == true)
                        Text(
                          person.phone!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (isDriver && person.vehicleInfo != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildVehicleInfo(context),
            ],

            if (person.phone?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onCall != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (onCall != null && onMessage != null)
                    const SizedBox(width: 12),
                  if (onMessage != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onMessage,
                        icon: const Icon(Icons.message, size: 18),
                        label: const Text('Message'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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

  Widget _buildVehicleInfo(BuildContext context) {
    final vehicle = person.vehicleInfo!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Information',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Icon(Icons.directions_car, color: Colors.grey[600], size: 18),
            const SizedBox(width: 8),
            Text(
              '${vehicle.make} ${vehicle.model}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        if (vehicle.color?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.palette, color: Colors.grey[600], size: 18),
              const SizedBox(width: 8),
              Text(
                vehicle.color!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],

        if (vehicle.licensePlate?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.confirmation_number, color: Colors.grey[600], size: 18),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Text(
                  vehicle.licensePlate!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}