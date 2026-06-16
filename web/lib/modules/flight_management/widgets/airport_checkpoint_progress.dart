import 'package:flutter/material.dart';
import '../muc_checkpoints.dart';

/// Horizontal step indicator showing the client's current checkpoint in the terminal chain.
/// Completed steps are green, the current/active step is amber, future steps are grey.
class AirportCheckpointProgress extends StatelessWidget {
  final String?
  currentCheckpoint; // "landed" | "arrivals_hall" | "terminal_exit" | null

  const AirportCheckpointProgress({super.key, required this.currentCheckpoint});

  @override
  Widget build(BuildContext context) {
    final currentOrdinal = MucCheckpoints.ordinal(currentCheckpoint);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terminal Progress',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int i = 0; i < MucCheckpoints.chain.length; i++) ...[
                  _buildStep(context, i, currentOrdinal),
                  if (i < MucCheckpoints.chain.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < currentOrdinal
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[300],
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, int index, int currentOrdinal) {
    final Color color;
    if (index < currentOrdinal) {
      color = const Color(0xFF4CAF50); // completed - green
    } else if (index == currentOrdinal) {
      color = const Color(0xFFFF9800); // active - amber
    } else {
      color = const Color(0xFF9E9E9E); // pending - grey
    }

    final label = _stepLabel(index);

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(
            index <= currentOrdinal
                ? Icons.check
                : Icons.radio_button_unchecked,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _stepLabel(int index) {
    switch (index) {
      case 0:
        return 'Landed';
      case 1:
        return 'Arrivals';
      case 2:
        return 'Exit';
      default:
        return '';
    }
  }
}
