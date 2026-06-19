import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';

class AvailabilityToggle extends StatefulWidget {
  const AvailabilityToggle({super.key});

  @override
  State<AvailabilityToggle> createState() => _AvailabilityToggleState();
}

class _AvailabilityToggleState extends State<AvailabilityToggle> {
  bool _isAvailable = false;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final user = context.read<AuthBloc>().state.user;
      if (user == null) return;

      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.get('/drivers/${user.id}/availability');

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _isAvailable = data['status'] == 'Available';
        });
      }
    } catch (_) {
      // Silently handle - default to offline
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    HapticFeedback.selectionClick();
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    setState(() => _isUpdating = true);

    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final response = await apiClient.put('/drivers/${user.id}/availability', {
        'status': value ? 'Available' : 'Offline',
      });

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _isAvailable = value;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isAvailable
                    ? AppColors.success
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAvailable ? 'Available' : 'Offline',
                    style: AppStyles.labelLarge.copyWith(
                      color: _isAvailable
                          ? AppColors.success
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _isAvailable
                        ? 'You are accepting rides'
                        : 'You are not accepting rides',
                    style: AppStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_isUpdating)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch.adaptive(
                value: _isAvailable,
                onChanged: _toggleAvailability,
                activeTrackColor: AppColors.accent,
                activeThumbColor: AppColors.success,
              ),
          ],
        ),
      ),
    );
  }
}
