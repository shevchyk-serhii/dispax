import 'package:flutter/material.dart';

class QuickLoginButtons extends StatelessWidget {
  final Function(String email) onQuickLogin;

  const QuickLoginButtons({super.key, required this.onQuickLogin});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Quick Test Login:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onQuickLogin('driver@test.com'),
                icon: const Icon(Icons.drive_eta, size: 18),
                label: const Text('Driver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100],
                  foregroundColor: Colors.blue[800],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onQuickLogin('client@test.com'),
                icon: const Icon(Icons.person, size: 18),
                label: const Text('Client'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[100],
                  foregroundColor: Colors.green[800],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onQuickLogin('secretary@test.com'),
                icon: const Icon(Icons.admin_panel_settings, size: 18),
                label: const Text('Secretary'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[100],
                  foregroundColor: Colors.orange[800],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => onQuickLogin('dispatcher@test.com'),
                icon: const Icon(Icons.assignment_ind, size: 18),
                label: const Text('Dispatcher'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[100],
                  foregroundColor: Colors.purple[800],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
