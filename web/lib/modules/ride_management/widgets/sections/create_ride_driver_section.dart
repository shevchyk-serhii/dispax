import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import '../../../../modules/core/models/person.dart';
import '../../../../modules/core/services/user_service.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';

class CreateRideDriverSection extends StatefulWidget {
  const CreateRideDriverSection({super.key});

  @override
  State<CreateRideDriverSection> createState() =>
      _CreateRideDriverSectionState();
}

class _CreateRideDriverSectionState extends State<CreateRideDriverSection> {
  late final UserService _userService;
  List<Person> _drivers = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthBloc>();
    _userService = UserService(apiClient: authBloc.apiClient);

    // Initial preselect of self; the driver can clear it via the × button
    // and it will not be re-applied automatically.
    _preselectSelf();

    _loadDrivers();
  }

  void _preselectSelf() {
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CreateRideFormBloc>().add(DriverPreselected(user.id));
      });
    }
  }

  @override
  void dispose() {
    _userService.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      final drivers = await _userService.getDrivers();
      if (mounted)
        setState(() {
          _drivers = drivers;
          _loading = false;
          _errorMessage = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _errorMessage = 'Could not load drivers';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      buildWhen: (prev, curr) => prev.selectedDriverId != curr.selectedDriverId,
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: AppColors.infoStrong, size: 24),
                    const SizedBox(width: AppDimensions.paddingSmall),
                    const Text(
                      'Driver',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingMedium),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: AppColors.warningStrong,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.warningStrong),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _errorMessage = null;
                          });
                          _loadDrivers();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else if (_drivers.isEmpty)
                  Text(
                    'No drivers found in your company',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: state.selectedDriverId,
                    decoration: InputDecoration(
                      labelText: 'Assigned driver',
                      prefixIcon: Icon(
                        Icons.drive_eta,
                        color: AppColors.infoStrong,
                      ),
                      suffixIcon: state.selectedDriverId != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: AppColors.textSecondary,
                              tooltip: 'Clear',
                              splashRadius: 18,
                              onPressed: () => context
                                  .read<CreateRideFormBloc>()
                                  .add(const DriverSelected(null)),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall,
                        ),
                      ),
                    ),
                    items: _drivers.map((driver) {
                      final isSelf =
                          driver.id == context.read<AuthBloc>().state.user?.id;
                      return DropdownMenuItem(
                        value: driver.id,
                        child: Row(
                          children: [
                            Text(driver.name),
                            if (isSelf) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.infoBorder,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'me',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.infoStrong,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      context.read<CreateRideFormBloc>().add(
                        DriverSelected(value),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
