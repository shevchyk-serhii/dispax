import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../widgets/common/rate_ride_dialog.dart';
import '../../modules/core/date_utils.dart';
import '../../screens/ride_details_screen.dart';
import '../../theme/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../utils/ride_status_styles.dart';

enum _ClientPeriodFilter { today, week, month, all }

class ClientRideHistoryScreen extends StatefulWidget {
  const ClientRideHistoryScreen({super.key});

  @override
  State<ClientRideHistoryScreen> createState() =>
      _ClientRideHistoryScreenState();
}

class _ClientRideHistoryScreenState extends State<ClientRideHistoryScreen> {
  _ClientPeriodFilter _period = _ClientPeriodFilter.all;

  void loadRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  List<Ride> getClientCompletedRides(List<Ride> rides, String? clientId) {
    var filtered = rides
        .where(
          (ride) =>
              ride.clientId.toString() == clientId &&
              (ride.status == RideStatus.completed ||
                  ride.status == RideStatus.cancelled),
        )
        .toList();

    final now = DateTime.now();
    switch (_period) {
      case _ClientPeriodFilter.today:
        filtered = filtered
            .where(
              (r) =>
                  r.pickupDateTime.year == now.year &&
                  r.pickupDateTime.month == now.month &&
                  r.pickupDateTime.day == now.day,
            )
            .toList();
        break;
      case _ClientPeriodFilter.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        filtered = filtered
            .where((r) => r.pickupDateTime.isAfter(start))
            .toList();
        break;
      case _ClientPeriodFilter.month:
        final start = DateTime(now.year, now.month, 1);
        filtered = filtered
            .where((r) => r.pickupDateTime.isAfter(start))
            .toList();
        break;
      case _ClientPeriodFilter.all:
        break;
    }

    return filtered
      ..sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime));
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildGradientContainer(
      colors: AppColors.clientGradient,
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
              ? getClientCompletedRides(
                  rideState.rides,
                  authState.user!.id.toString(),
                )
              : <Ride>[];

          if (completedRides.isEmpty && _period == _ClientPeriodFilter.all) {
            return _buildEmptyState();
          }

          return _buildRideHistory(completedRides);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.paddingLarge),
        padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
        decoration: AppTheme.glassDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: AppDimensions.iconLogo,
              color: AppColors.clientColor.withAlpha(150),
            ),
            const SizedBox(height: AppDimensions.paddingLarge),
            Text(
              'No Ride History',
              style: AppStyles.headlineMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            Text(
              'Your completed rides will appear here',
              textAlign: TextAlign.center,
              style: AppStyles.bodyLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
      ),
      child: Row(
        children: [
          _buildPeriodChip('Today', _ClientPeriodFilter.today),
          const SizedBox(width: 8),
          _buildPeriodChip('Week', _ClientPeriodFilter.week),
          const SizedBox(width: 8),
          _buildPeriodChip('Month', _ClientPeriodFilter.month),
          const SizedBox(width: 8),
          _buildPeriodChip('All', _ClientPeriodFilter.all),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, _ClientPeriodFilter filter) {
    final selected = _period == filter;
    return GestureDetector(
      onTap: () => setState(() => _period = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withAlpha(40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withAlpha(80),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Colors.white.withAlpha(200),
          ),
        ),
      ),
    );
  }

  String _periodLabel() {
    switch (_period) {
      case _ClientPeriodFilter.today:
        return "Today's";
      case _ClientPeriodFilter.week:
        return "This Week's";
      case _ClientPeriodFilter.month:
        return "This Month's";
      case _ClientPeriodFilter.all:
        return 'My Ride';
    }
  }

  Widget _buildRideHistory(List<Ride> rides) {
    return RefreshIndicator(
      onRefresh: () async => loadRides(context),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.paddingLarge),
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              decoration: AppTheme.glassDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        color: AppColors.clientColor,
                        size: AppDimensions.iconMedium,
                      ),
                      const SizedBox(width: AppDimensions.paddingSmall),
                      Expanded(
                        child: Text(
                          '${_periodLabel()} History',
                          style: AppStyles.titleLarge.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.paddingMedium),
                  _buildStatsRow(rides),
                ],
              ),
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
                    color: AppColors.textOnPrimary.withAlpha(150),
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
                    if (showDateHeader) _buildDateHeader(ride.pickupDateTime),
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

  Widget _buildStatsRow(List<Ride> rides) {
    final completedCount = rides
        .where((r) => r.status == RideStatus.completed)
        .length;
    final cancelledCount = rides
        .where((r) => r.status == RideStatus.cancelled)
        .length;
    final totalSpent = rides
        .where((r) => r.status == RideStatus.completed)
        .map((r) => r.price ?? 0.0)
        .fold(0.0, (sum, price) => sum + price);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          icon: Icons.check_circle,
          value: completedCount.toString(),
          label: 'Completed',
          color: AppColors.rideCompleted,
        ),
        _buildStatItem(
          icon: Icons.cancel,
          value: cancelledCount.toString(),
          label: 'Cancelled',
          color: AppColors.rideCancelled,
        ),
        _buildStatItem(
          icon: Icons.euro,
          value: totalSpent.toStringAsFixed(0),
          label: 'Spent',
          color: AppColors.clientColor,
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDimensions.paddingSmall),
          decoration: BoxDecoration(
            color: color.withAlpha(50),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
          child: Icon(icon, color: color, size: AppDimensions.iconMedium),
        ),
        const SizedBox(height: AppDimensions.paddingSmall),
        Text(
          value,
          style: AppStyles.titleMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppStyles.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.paddingLarge,
        AppDimensions.paddingMedium,
        AppDimensions.paddingLarge,
        AppDimensions.paddingSmall,
      ),
      child: Row(
        children: [
          Container(
            height: 1,
            width: 30,
            color: AppColors.textOnPrimary.withAlpha(100),
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Text(
            AppDateUtils.formatDateHeader(date),
            style: AppStyles.labelMedium.copyWith(
              color: AppColors.textOnPrimary.withAlpha(200),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingMedium),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.textOnPrimary.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, Ride ride) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingSmall,
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    RideDetailsScreen(ride: ride, isClientView: true),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RideStatusStyles.createStatusBadge(
                      ride.status,
                      context: context,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingSmall,
                        vertical: AppDimensions.paddingXSmall,
                      ),
                      fontSize: 12,
                      iconSize: AppDimensions.iconSmall,
                    ),
                    Text(
                      AppDateUtils.formatTime(ride.pickupDateTime),
                      style: AppStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.paddingMedium),

                Row(
                  children: [
                    Icon(
                      Icons.route,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: AppDimensions.iconSmall,
                    ),
                    const SizedBox(width: AppDimensions.paddingSmall),
                    Expanded(
                      child: Text(
                        '${ride.from.address} → ${ride.to.address}',
                        style: AppStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.paddingSmall),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.drive_eta,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: AppDimensions.iconSmall,
                        ),
                        const SizedBox(width: AppDimensions.paddingSmall),
                        Text(
                          ride.driverName ?? 'Driver not assigned',
                          style: AppStyles.bodyMedium.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (ride.price != null &&
                        ride.status == RideStatus.completed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingSmall,
                          vertical: AppDimensions.paddingXSmall,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.clientColor.withAlpha(50),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusSmall,
                          ),
                        ),
                        child: Text(
                          '€${ride.price!.toStringAsFixed(2)}',
                          style: AppStyles.labelMedium.copyWith(
                            color: AppColors.clientColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                if (ride.isAirportTransfer &&
                    ride.fullFlightInfo.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.paddingSmall),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingSmall),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(100),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flight,
                          color: Theme.of(context).colorScheme.primary,
                          size: AppDimensions.iconSmall,
                        ),
                        const SizedBox(width: AppDimensions.paddingSmall),
                        Expanded(
                          child: Text(
                            ride.fullFlightInfo,
                            style: AppStyles.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Rating display or Rate button
                if (ride.status == RideStatus.completed) ...[
                  const SizedBox(height: AppDimensions.paddingSmall),
                  if (ride.rating != null)
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < ride.rating! ? Icons.star : Icons.star_border,
                            color: AppColors.warning,
                            size: 16,
                          ),
                        ),
                        if (ride.ratingComment != null &&
                            ride.ratingComment!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ride.ratingComment!,
                              style: AppStyles.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showRateDialog(context, ride),
                        icon: const Icon(Icons.star, size: 16),
                        label: const Text('Rate this ride'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRateDialog(BuildContext context, Ride ride) async {
    final apiClient = context.read<AuthBloc>().apiClient;
    final rideBloc = context.read<RideBloc>();
    final user = context.read<AuthBloc>().state.user;
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => RateRideDialog(rideId: ride.id),
    );

    if (result != null) {
      try {
        await apiClient.post('/rides/${ride.id}/rate', {
          'rating': result['rating'],
          'comment': result['comment'],
        });
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Thank you for your rating!'),
              backgroundColor: AppColors.success,
            ),
          );
          if (user != null) {
            rideBloc.add(RideLoadRequested(user: user));
          }
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to submit rating: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
