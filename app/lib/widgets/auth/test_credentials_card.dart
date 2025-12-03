import 'package:flutter/material.dart';

class TestCredentialsCard extends StatelessWidget {
  final Function(String email, String password) onCredentialTap;

  const TestCredentialsCard({super.key, required this.onCredentialTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Accounts:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            buildCredentialRow('Driver', 'driver@test.com'),
            buildCredentialRow('Client', 'client@test.com'),
            buildCredentialRow('Secretary', 'secretary@test.com'),
            buildCredentialRow('Dispatcher', 'dispatcher@test.com'),
            const SizedBox(height: 8),
            Text(
              'Password for all: test123',
              style: TextStyle(fontSize: 12, color: Colors.blue[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCredentialRow(String role, String email) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: () => onCredentialTap(email, 'test123'),
        child: Text(
          '$role: $email',
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[700],
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
