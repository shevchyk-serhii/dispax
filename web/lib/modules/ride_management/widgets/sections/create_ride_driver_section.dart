import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';

/// Opt-in "Assign to me" toggle shown to a driver creating a ride.
///
/// By default a driver-created ride goes into the dispatcher pool (no driver,
/// status Requested) and the dispatcher is notified as usual. The driver can
/// optionally take the ride themselves by turning this switch on, which sets the
/// request's driverId to the driver's own id. A driver does not pick *other*
/// drivers — that is the dispatcher's job.
class CreateRideDriverSection extends StatelessWidget {
  const CreateRideDriverSection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return const SizedBox.shrink();

    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      builder: (context, state) {
        final assignedToMe = state.selectedDriverId == user.id;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          elevation: 2,
          shadowColor: AppColors.shadowMedium,
          child: SwitchListTile(
            value: assignedToMe,
            onChanged: (on) => context.read<CreateRideFormBloc>().add(
              DriverSelected(on ? user.id : null),
            ),
            secondary: Icon(
              Icons.drive_eta,
              color: AppColors.infoStrong,
              size: 20,
            ),
            title: const Text(
              'Assign to me',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              assignedToMe
                  ? 'You will be assigned to this ride'
                  : 'Leave off to send this ride to the dispatcher pool',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            activeThumbColor: AppColors.infoStrong,
          ),
        );
      },
    );
  }
}
