import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../constants/app_colors.dart';
import '../../modules/ride_management/models/vehicle_class.dart';
import '../../modules/ride_management/services/ride_estimate_service.dart';
import '../../modules/ride_management/helpers/create_ride_form_helper.dart';
import '../../modules/ride_management/models/ride_estimate.dart';

/// Client-specific booking screen (Book tab).
/// Wraps the booking state in [CreateRideFormBloc] + [RideBloc].
class ClientBookScreen extends StatelessWidget {
  final CreateRideFormBloc formBloc;
  final RideBloc rideBloc;
  final VoidCallback? onCreated;

  const ClientBookScreen({
    super.key,
    required this.formBloc,
    required this.rideBloc,
    this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: formBloc),
        BlocProvider.value(value: rideBloc),
      ],
      child: _ClientBookScreenContent(onCreated: onCreated),
    );
  }
}

class _ClientBookScreenContent extends StatefulWidget {
  final VoidCallback? onCreated;

  const _ClientBookScreenContent({this.onCreated});

  @override
  State<_ClientBookScreenContent> createState() =>
      _ClientBookScreenContentState();
}

class _ClientBookScreenContentState extends State<_ClientBookScreenContent> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  RideEstimateService? _estimateService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _estimateService ??= RideEstimateService(
      apiClient: context.read<AuthBloc>().apiClient,
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _triggerEstimates(CreateRideFormState state) {
    final from = state.fromAddress.trim();
    final to = state.toAddress.trim();
    if (from.isEmpty || to.isEmpty || _estimateService == null) return;

    for (final vc in VehicleClass.values) {
      _estimateService!
          .estimate(
            RideEstimateRequest(
              fromAddress: from,
              toAddress: to,
              vehicleClass: vc,
              isAirportTransfer: state.isAirportTransfer,
            ),
          )
          .then((result) {
            if (mounted) {
              context.read<CreateRideFormBloc>().add(
                EstimateReceived(vehicleClass: vc, estimate: result),
              );
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CreateRideFormBloc, CreateRideFormState>(
          listenWhen: (prev, cur) =>
              prev.fromAddress != cur.fromAddress ||
              prev.toAddress != cur.toAddress ||
              prev.isAirportTransfer != cur.isAirportTransfer,
          listener: (ctx, state) => _triggerEstimates(state),
        ),
        BlocListener<CreateRideFormBloc, CreateRideFormState>(
          listenWhen: (prev, cur) => prev.status != cur.status,
          listener: (ctx, state) {
            if (state.status == CreateRideFormStatus.submitting) {
              CreateRideFormHelper.handleFormSubmission(ctx, state);
            }
          },
        ),
        BlocListener<RideBloc, RideState>(
          listenWhen: (prev, cur) => prev.status != cur.status,
          listener: (ctx, state) {
            if (state.status == RideStateStatus.created) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Ride booked successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
              widget.onCreated?.call();
            } else if (state.status == RideStateStatus.error) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Failed to create ride'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 8),
                ),
              );
            }
          },
        ),
      ],
      child: Column(
        children: [
          _BookHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
                builder: (ctx, state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RouteCard(
                        fromController: _fromController,
                        toController: _toController,
                        fromAddress: state.fromAddress,
                        toAddress: state.toAddress,
                      ),
                      const SizedBox(height: 12),
                      _WhenToggle(
                        isScheduled: state.isScheduled,
                        pickupDateTime:
                            state.manualPickupDateTime ??
                            DateTime.now().add(const Duration(hours: 1)),
                      ),
                      const SizedBox(height: 16),
                      _VehicleClassSection(state: state),
                      const SizedBox(height: 16),
                      _Footer(state: state),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _BookHeader extends StatelessWidget {
  const _BookHeader();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Book a ride',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Route Card ──────────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final TextEditingController fromController;
  final TextEditingController toController;
  final String fromAddress;
  final String toAddress;

  const _RouteCard({
    required this.fromController,
    required this.toController,
    required this.fromAddress,
    required this.toAddress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowXs,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Column(
        children: [
          // FROM row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                // Accent ring dot (no fill)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2.5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FROM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => _showAddressPicker(
                          context,
                          isFrom: true,
                          current: fromAddress,
                        ),
                        child: Text(
                          fromAddress.isEmpty
                              ? 'Pick up location'
                              : fromAddress,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: fromAddress.isEmpty
                                ? AppColors.textLight
                                : cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
            thickness: 1,
          ),
          // TO row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                // Graphite square
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => _showAddressPicker(
                          context,
                          isFrom: false,
                          current: toAddress,
                        ),
                        child: Text(
                          toAddress.isEmpty ? 'Drop-off location' : toAddress,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: toAddress.isEmpty
                                ? AppColors.textLight
                                : cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddressPicker(
    BuildContext context, {
    required bool isFrom,
    required String current,
  }) async {
    final savedState = context.read<SavedPlacesBloc>().state;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddressPickerSheet(
        isFrom: isFrom,
        current: current,
        savedPlaces: savedState.places
            .map((p) => p.address)
            .where((a) => a.isNotEmpty)
            .toList(),
      ),
    );

    if (result != null && context.mounted) {
      if (isFrom) {
        context.read<CreateRideFormBloc>().add(FromAddressChanged(result));
      } else {
        context.read<CreateRideFormBloc>().add(ToAddressChanged(result));
      }
    }
  }
}

// ─── Address picker bottom sheet ─────────────────────────────────────────────

class _AddressPickerSheet extends StatefulWidget {
  final bool isFrom;
  final String current;
  final List<String> savedPlaces;

  const _AddressPickerSheet({
    required this.isFrom,
    required this.current,
    required this.savedPlaces,
  });

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vp = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: vp),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.isFrom
                      ? 'Enter pick-up address'
                      : 'Enter drop-off address',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.borderPrimary,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
                },
              ),
            ),
            if (widget.savedPlaces.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Saved places',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ),
              ...widget.savedPlaces.map(
                (p) => ListTile(
                  leading: const Icon(
                    Icons.bookmark_outline,
                    color: AppColors.accent,
                  ),
                  title: Text(p),
                  onTap: () => Navigator.of(context).pop(p),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: Builder(
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return ElevatedButton(
                      onPressed: () {
                        final v = _ctrl.text.trim();
                        if (v.isNotEmpty) Navigator.of(context).pop(v);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirm'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── When Toggle ─────────────────────────────────────────────────────────────

class _WhenToggle extends StatelessWidget {
  final bool isScheduled;
  final DateTime pickupDateTime;

  const _WhenToggle({required this.isScheduled, required this.pickupDateTime});

  String _formattedDateTime() {
    final d = pickupDateTime;
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final dayLabel = isToday
        ? 'Today'
        : '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$dayLabel $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<CreateRideFormBloc>().add(
                const ScheduleModeToggled(scheduled: true),
              );
              if (isScheduled) {
                CreateRideFormHelper.selectDateTime(context, pickupDateTime);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isScheduled
                      ? AppColors.accent
                      : AppColors.borderPrimary,
                  width: isScheduled ? 2 : 1,
                ),
                boxShadow: isScheduled
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCHEDULED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isScheduled
                          ? AppColors.accentDark
                          : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formattedDateTime(),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isScheduled
                          ? cs.onSurface
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<CreateRideFormBloc>().add(
                const ScheduleModeToggled(scheduled: false),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !isScheduled
                      ? AppColors.accent
                      : AppColors.borderPrimary,
                  width: !isScheduled ? 2 : 1,
                ),
                boxShadow: !isScheduled
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: !isScheduled
                          ? AppColors.accentDark
                          : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ASAP',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: !isScheduled
                          ? cs.onSurface
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Vehicle Class Section ───────────────────────────────────────────────────

class _VehicleClassSection extends StatelessWidget {
  final CreateRideFormState state;

  const _VehicleClassSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VEHICLE CLASS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowXs,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
          child: Column(
            children: [
              _VehicleClassRow(
                vc: VehicleClass.business,
                isSelected: state.selectedVehicleClass == VehicleClass.business,
                estimate: state.estimateBusiness,
                showDivider: true,
              ),
              _VehicleClassRow(
                vc: VehicleClass.van,
                isSelected: state.selectedVehicleClass == VehicleClass.van,
                estimate: state.estimateVan,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleClassRow extends StatelessWidget {
  final VehicleClass vc;
  final bool isSelected;
  final RideEstimate? estimate;
  final bool showDivider;

  const _VehicleClassRow({
    required this.vc,
    required this.isSelected,
    this.estimate,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final priceText = estimate != null
        ? '€${estimate!.estimatedPrice.toStringAsFixed(0)}'
        : '—';

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            context.read<CreateRideFormBloc>().add(VehicleClassSelected(vc));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(
                  vc == VehicleClass.van
                      ? Icons.airport_shuttle_outlined
                      : Icons.directions_car_outlined,
                  size: 26,
                  color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vc.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vc.capacityLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  priceText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
            thickness: 1,
          ),
      ],
    );
  }
}

// ─── Footer ──────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final CreateRideFormState state;

  const _Footer({required this.state});

  @override
  Widget build(BuildContext context) {
    final estimate = state.activeEstimate;
    final total = estimate != null
        ? '€${estimate.estimatedPrice.toStringAsFixed(2)}'
        : '—';
    final showEstimateHint =
        estimate == null &&
        state.estimateUnavailable &&
        state.fromAddress.trim().isNotEmpty &&
        state.toAddress.trim().isNotEmpty;

    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated total',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              Text(
                total,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          if (showEstimateHint) ...[
            const SizedBox(height: 6),
            Text(
              "We couldn't estimate the price for this address. "
              'You can still book — the fare will be confirmed afterwards.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: Builder(
              builder: (context) {
                final cs = Theme.of(context).colorScheme;
                return ElevatedButton(
                  onPressed: state.isValid
                      ? () => context.read<CreateRideFormBloc>().add(
                          const FormSubmitted(),
                        )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Confirm booking',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
