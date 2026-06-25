import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../modules/core/navigation_helper.dart';
import '../../utils/ride_status_styles.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import 'today_rides_screen.dart'
    show rideErrorMessageOrFallback, upcomingRidesFilter;

class UpcomingRidesScreen extends StatelessWidget {
  const UpcomingRidesScreen({super.key});

  void loadUpcomingRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  void refreshRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideRefreshRequested(user: authState.user!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: BlocListener<RideBloc, RideState>(
              listener: (context, state) {
                if (state.hasError) {
                  NavigationHelper.showSnackBar(
                    context,
                    rideErrorMessageOrFallback(state.errorMessage, context),
                    isError: true,
                  );
                }
              },
              child: BlocBuilder<RideBloc, RideState>(
                builder: (context, rideState) {
                  return buildBody(context, rideState);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Next 7 days',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => refreshRides(context),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────

  Widget buildBody(BuildContext context, RideState rideState) {
    if (rideState.status == RideStateStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => loadUpcomingRides(context),
      );
    }

    if (rideState.isLoading) {
      return const LoadingWidget();
    }

    if (rideState.hasError && rideState.rides.isEmpty) {
      return ErrorDisplayWidget(
        title: 'Failed to load upcoming rides',
        message: rideErrorMessageOrFallback(rideState.errorMessage, context),
        onRetry: () => refreshRides(context),
      );
    }

    final upcomingRides = getUpcomingRides(rideState.rides);
    final groupedRides = groupRidesByDate(upcomingRides);

    if (upcomingRides.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () async => refreshRides(context),
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.paddingMedium),
          ),
          ...groupedRides.entries.map((entry) {
            return SliverToBoxAdapter(
              child: _buildDateGroup(context, entry.key, entry.value),
            );
          }),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.paddingXLarge),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: AppDimensions.iconLogo,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppDimensions.paddingLarge),
          Text(
            'No upcoming rides',
            style: AppStyles.headlineSmall.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingSmall),
          Text(
            'All caught up for now!',
            style: AppStyles.bodyLarge.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Date group section ────────────────────────────────────────────────────

  Widget _buildDateGroup(
    BuildContext context,
    String dateKey,
    List<Ride> rides,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = DateTime.parse(dateKey);
    final isToday = isSameDay(date, DateTime.now());
    final isTomorrow = isSameDay(
      date,
      DateTime.now().add(const Duration(days: 1)),
    );

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isTomorrow) {
      dateLabel = 'Tomorrow';
    } else {
      dateLabel = DateFormat('EEE d MMMM').format(date);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingMedium,
            AppDimensions.paddingSmall,
            AppDimensions.paddingMedium,
            AppDimensions.paddingSmall,
          ),
          child: Text(
            dateLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMedium,
          ),
          child: Column(
            children: rides
                .map((ride) => _buildRideCard(context, ride))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ─── Ride card ─────────────────────────────────────────────────────────────

  Widget _buildRideCard(BuildContext context, Ride ride) {
    final colorScheme = Theme.of(context).colorScheme;

    // Build detail line: flight info, pax, ride type
    final detailParts = <String>[];
    if (ride.isAirportTransfer && ride.flightNumber != null) {
      detailParts.add('✈ ${ride.flightNumber}');
    }
    // specialRequirements as "pax" proxy if present
    if (ride.specialRequirements != null &&
        ride.specialRequirements!.isNotEmpty) {
      detailParts.add(ride.specialRequirements!);
    }
    if (ride.isVipRide) {
      detailParts.add('VIP');
    }
    final detailLine = detailParts.join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSmall),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSm,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: status badge + pickup time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RideStatusStyles.createStatusBadge(
                  ride.status,
                  context: context,
                  fontSize: 10,
                  iconSize: AppDimensions.iconSmall,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                ),
                Text(
                  DateFormat.Hm().format(ride.pickupDateTime),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Route
            Text(
              '${ride.from.address} → ${ride.to.address}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Detail line
            if (detailLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                detailLine,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Data helpers ──────────────────────────────────────────────────────────

  List<Ride> getUpcomingRides(List<Ride> rides) =>
      upcomingRidesFilter(rides, DateTime.now());

  Map<String, List<Ride>> groupRidesByDate(List<Ride> rides) {
    final grouped = <String, List<Ride>>{};

    for (final ride in rides) {
      final dateKey =
          '${ride.pickupDateTime.year}-${ride.pickupDateTime.month.toString().padLeft(2, '0')}-${ride.pickupDateTime.day.toString().padLeft(2, '0')}';

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(ride);
    }

    return grouped;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
