import 'package:flutter/material.dart';

class LocationField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final IconData prefixIcon;
  final VoidCallback? onChanged;

  const LocationField({
    super.key,
    required this.controller,
    required this.hint,
    this.validator,
    this.prefixIcon = Icons.location_on,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(prefixIcon),
          ),
          validator: validator ?? _defaultValidator,
          maxLines: 2,
          minLines: 1,
          onChanged: onChanged != null ? (value) => onChanged!() : null,
        ),
      ),
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an address';
    }
    return null;
  }
}
