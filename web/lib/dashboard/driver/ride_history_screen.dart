import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../modules/core/date_utils.dart';
import '../../screens/ride_details_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../utils/ride_status_styles.dart';

enum _PeriodFilter { today, week, month, all }

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  _PeriodFilter _period = _PeriodFilter.all;

  void loadRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  List<Ride> getCompletedRides(List<Ride> rides, String? driverId) {
    var filtered = rides
        .where(
          (ride) =>
              ride.driverId?.toString() == driverId &&
              (ride.status == RideStatus.completed ||
                  ride.status == RideStatus.cancelled),
        )
        .toList();

    final now = DateTime.now();
    switch (_period) {
      case _PeriodFilter.today:
        filtered = filtered
            .where(
              (r) =>
                  r.pickupDateTime.year == now.year &&
                  r.pickupDateTime.month == now.month &&
                  r.pickupDateTime.day == now.day,
            )
            .toList();
      case _PeriodFilter.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        filtered = filtered
            .where((r) => r.pickupDateTime.isAfter(start))
            .toList();
      case _PeriodFilter.month:
        final start = DateTime(now.year, now.month, 1);
        filtered = filtered
            .where((r) => r.pickupDateTime.isAfter(start))
            .toList();
      case _PeriodFilter.all:
        break;
    }

    return filtered
      ..sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: BlocBuilder<RideBloc, RideState>(
              builder: (context, rideState) {
                final authState = context.read<AuthBloc>().state;

                if (rideState.status == RideStateStatus.initial) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => loadRides(context),
                  );
                }

                if (rideState.isLoading) {
                  return const LoadingWidget();
                }

                if (rideState.hasError && rideState.rides.isEmpty) {
                  return ErrorDisplayWidget(
                    title: 'Failed to load ride history',
                    message: rideState.errorMessage!,
                    onRetry: () => loadRides(context),
                  );
                }

                final completedRides = authState.user != null
                    ? getCompletedRides(
                        rideState.rides,
                        authState.user!.id.toString(),
                      )
                    : <Ride>[];

                if (completedRides.isEmpty && _period == _PeriodFilter.all) {
                  return _buildEmptyState(context);
                }

                return _buildRideHistory(context, completedRides);
              },
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'History',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _periodSubtitle(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _periodSubtitle() {
    switch (_period) {
      case _PeriodFilter.today:
        return 'Today';
      case _PeriodFilter.week:
        return 'This week';
      case _PeriodFilter.month:
        return 'This month';
      case _PeriodFilter.all:
        return 'All time';
    }
  }

  // ─── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: AppDimensions.iconLogo,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimensions.paddingLarge),
            Text(
              'No Ride History',
              style: AppStyles.headlineSmall.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            Text(
              'Your completed rides will appear here',
              textAlign: TextAlign.center,
              style: AppStyles.bodyLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Period selector chips ─────────────────────────────────────────────────

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingMedium,
        AppDimensions.paddingMedium,
        AppDimensions.paddingMedium,
        0,
      ),
      child: Row(
        children: [
          _periodChip('Today', _PeriodFilter.today),
          const SizedBox(width: 8),
          _periodChip('Week', _PeriodFilter.week),
          const SizedBox(width: 8),
          _periodChip('Month', _PeriodFilter.month),
          const SizedBox(width: 8),
          _periodChip('All', _PeriodFilter.all),
        ],
      ),
    );
  }

  Widget _periodChip(String label, _PeriodFilter filter) {
    final selected = _period == filter;
    return GestureDetector(
      onTap: () => setState(() => _period = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primarySurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderPrimary,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ─── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(BuildContext context, List<Ride> rides) {
    final colorScheme = Theme.of(context).colorScheme;
    final completedCount = rides
        .where((r) => r.status == RideStatus.completed)
        .length;
    final totalEarnings = rides
        .where((r) => r.status == RideStatus.completed)
        .map((r) => r.price ?? 0.0)
        .fold(0.0, (sum, price) => sum + price);
    final avgRating = _averageRating(
      rides.where((r) => r.status == RideStatus.completed).toList(),
    );

    return Row(
      children: [
        // Completed tile — graphite bg
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            ),
            child: Column(
              children: [
                Text(
                  completedCount.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Earned tile — surface variant bg
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            ),
            child: Column(
              children: [
                Text(
                  '€${totalEarnings.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Earned',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Rating tile — surface variant bg
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            ),
            child: Column(
              children: [
                Text(
                  avgRating != null ? avgRating.toStringAsFixed(1) : '—',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rating',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double? _averageRating(List<Ride> rides) {
    final rated = rides.where((r) => r.rating != null).toList();
    if (rated.isEmpty) return null;
    final sum = rated.fold<int>(0, (acc, r) => acc + r.rating!);
    return sum / rated.length;
  }

  // ─── History list ──────────────────────────────────────────────────────────

  Widget _buildRideHistory(BuildContext context, List<Ride> rides) {
    return RefreshIndicator(
      onRefresh: () async => loadRides(context),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              child: _buildStatsRow(context, rides),
            ),
          ),
          SliverToBoxAdapter(child: _buildPeriodSelector()),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.paddingMedium),
          ),
          if (rides.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No rides for this period',
                  style: AppStyles.bodyLarge.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final ride = rides[index];
                final showDateHeader =
                    index == 0 ||
                    !_isSameDay(
                      rides[index - 1].pickupDateTime,
                      ride.pickupDateTime,
                    );
                return Column(
                  children: [
                    if (showDateHeader)
                      _buildDateHeader(context, ride.pickupDateTime),
                    _buildRideCard(context, ride),
                  ],
                );
              }, childCount: rides.length),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.paddingXLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingMedium,
        AppDimensions.paddingMedium,
        AppDimensions.paddingMedium,
        AppDimensions.paddingSmall,
      ),
      child: Row(
        children: [
          Container(height: 1, width: 24, color: colorScheme.outline),
          const SizedBox(width: AppDimensions.paddingSmall),
          Text(
            AppDateUtils.formatDateHeader(date),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingSmall),
          Expanded(child: Container(height: 1, color: colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, Ride ride) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCancelled = ride.status == RideStatus.cancelled;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingXSmall,
      ),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  RideDetailsScreen(ride: ride, isClientView: false),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: route info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ride.from.address} → ${ride.to.address}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _rideDetail(ride),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: fare + status badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isCancelled
                        ? '€0.00'
                        : (ride.price != null
                              ? '€${ride.price!.toStringAsFixed(2)}'
                              : '—'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCancelled
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _rideDetail(Ride ride) {
    final time = AppDateUtils.formatTime(ride.pickupDateTime);
    return time;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
