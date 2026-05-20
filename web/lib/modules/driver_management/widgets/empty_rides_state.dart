import 'package:flutter/material.dart';

class EmptyRidesState extends StatelessWidget {
  const EmptyRidesState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.free_breakfast, size: 80, color: Colors.blue.shade300),
          const SizedBox(height: 24),
          Text(
            'No rides today!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enjoy your free day',
            style: TextStyle(fontSize: 16, color: Colors.blue.shade500),
          ),
        ],
      ),
    );
  }
}