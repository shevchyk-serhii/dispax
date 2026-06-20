import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../modules/driver_management/services/driver_availability_service.dart';

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
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    final service = DriverAvailabilityService(
      context.read<AuthBloc>().apiClient,
    );
    final available = await service.isAvailable(user.id.toString());
    if (mounted) {
      setState(() => _isAvailable = available);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    HapticFeedback.selectionClick();
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    setState(() => _isUpdating = true);

    try {
      final service = DriverAvailabilityService(
        context.read<AuthBloc>().apiClient,
      );
      final ok = await service.setAvailable(user.id.toString(), value);
      if (ok && mounted) {
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
