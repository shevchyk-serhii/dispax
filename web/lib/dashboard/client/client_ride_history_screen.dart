import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../modules/core/date_utils.dart';
import '../../screens/ride_details_screen.dart';
import '../../theme/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../utils/ride_status_styles.dart';

class ClientRideHistoryScreen extends StatelessWidget {
  const ClientRideHistoryScreen({super.key});

  void loadRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  List<Ride> getClientCompletedRides(List<Ride> rides, String? clientId) {
    return rides.where((ride) => 
      ride.clientId.toString() == clientId && 
      (ride.status == RideStatus.completed || ride.status == RideStatus.cancelled)
    ).toList()..sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime)); // Most recent first
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildGradientContainer(
      colors: AppColors.clientGradient,
      child: BlocBuilder<RideBloc, RideState>(
        builder: (context, rideState) {
          final authState = context.read<AuthBloc>().state;
          
          // Load rides on first build if not loaded yet
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
            ? getClientCompletedRides(rideState.rides, authState.user!.id.toString())
            : <Ride>[];

          if (completedRides.isEmpty) {
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
                color: AppColors.textOnPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingSmall),
            Text(
              'Your completed rides will appear here',
              textAlign: TextAlign.center,
              style: AppStyles.bodyLarge.copyWith(
                color: AppColors.textOnPrimary.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideHistory(List<Ride> rides) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh will be handled by the bloc listener
      },
      child: CustomScrollView(
        slivers: [
          // Header with title and stats
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
                      Text(
                        'My Ride History',
                        style: AppStyles.titleLarge.copyWith(
                          color: AppColors.textOnPrimary,
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

          // Ride list grouped by date
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ride = rides[index];
                final showDateHeader = index == 0 || 
                  !_isSameDay(rides[index - 1].pickupDateTime, ride.pickupDateTime);
                
                return Column(
                  children: [
                    if (showDateHeader) _buildDateHeader(ride.pickupDateTime),
                    _buildRideCard(context, ride),
                  ],
                );
              },
              childCount: rides.length,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.paddingXLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<Ride> rides) {
    final completedCount = rides.where((r) => r.status == RideStatus.completed).length;
    final cancelledCount = rides.where((r) => r.status == RideStatus.cancelled).length;
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
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppStyles.labelSmall.copyWith(
            color: AppColors.textOnPrimary.withAlpha(180),
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
                builder: (context) => RideDetailsScreen(
                  ride: ride,
                  isClientView: true,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status and time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RideStatusStyles.createStatusBadge(
                      ride.status,
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
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppDimensions.paddingMedium),

                // Route information
                Row(
                  children: [
                    Icon(
                      Icons.route,
                      color: AppColors.textSecondary,
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

                // Driver and price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.drive_eta,
                          color: AppColors.textSecondary,
                          size: AppDimensions.iconSmall,
                        ),
                        const SizedBox(width: AppDimensions.paddingSmall),
                        Text(
                          ride.driverName ?? 'Driver not assigned',
                          style: AppStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (ride.price != null && ride.status == RideStatus.completed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingSmall,
                          vertical: AppDimensions.paddingXSmall,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.clientColor.withAlpha(50),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
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

                // Flight info for airport transfers
                if (ride.isAirportTransfer && ride.fullFlightInfo.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.paddingSmall),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingSmall),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(100),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flight,
                          color: AppColors.primary,
                          size: AppDimensions.iconSmall,
                        ),
                        const SizedBox(width: AppDimensions.paddingSmall),
                        Expanded(
                          child: Text(
                            ride.fullFlightInfo,
                            style: AppStyles.bodySmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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


  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}