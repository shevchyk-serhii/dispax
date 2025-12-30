import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../theme/app_theme.dart';

class BasicInfoCard extends StatelessWidget {
  final String clientName;
  final ValueChanged<String> onClientNameChanged;

  const BasicInfoCard({
    super.key,
    required this.clientName,
    required this.onClientNameChanged,
  });

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
                Icon(Icons.person, color: Colors.blue[600], size: 24),
                const SizedBox(width: AppDimensions.paddingSmall),
                const Text(
                  'Client Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingMedium),
            TextFormField(
              initialValue: clientName,
              decoration: InputDecoration(
                labelText: 'Client Name',
                hintText: 'Enter client name',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.secretaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Client name is required';
                }
                return null;
              },
              onChanged: onClientNameChanged,
            ),
          ],
        ),
      ),
    );
  }
}
