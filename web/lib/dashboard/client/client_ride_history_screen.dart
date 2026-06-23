import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../widgets/widgets.dart';
import '../../widgets/common/rate_ride_dialog.dart';
import '../../modules/core/date_utils.dart';
import '../../screens/ride_details_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../utils/ride_status_styles.dart';
import 'calendar/client_calendar_view.dart';

enum _ClientPeriodFilter { today, week, month, all }

enum _ClientRidesView { list, calendar }

class ClientRideHistoryScreen extends StatefulWidget {
  const ClientRideHistoryScreen({super.key});

  @override
  State<ClientRideHistoryScreen> createState() =>
      _ClientRideHistoryScreenState();
}

class _ClientRideHistoryScreenState extends State<ClientRideHistoryScreen> {
  _ClientPeriodFilter _period = _ClientPeriodFilter.all;
  _ClientRidesView _view = _ClientRidesView.list;

  void _loadRides(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideLoadRequested(user: authState.user!));
    }
  }

  /// Rides that are in progress or upcoming (not completed/cancelled).
  List<Ride> _upcomingRides(List<Ride> rides, String? clientId) {
    return rides
        .where(
          (ride) =>
              ride.clientId.toString() == clientId &&
              (ride.status == RideStatus.assigned ||
                  ride.status == RideStatus.inProgress ||
                  ride.status == RideStatus.requested),
        )
        .toList()
      ..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
  }

  /// Completed or cancelled rides, optionally filtered by period.
  List<Ride> _pastRides(List<Ride> rides, String? clientId) {
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<RideBloc, RideState>(
        builder: (context, rideState) {
          final authState = context.read<AuthBloc>().state;

          if (rideState.status == RideStateStatus.initial) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _loadRides(context),
            );
          }

          if (rideState.isLoading) {
            return const LoadingWidget();
          }

          if (rideState.hasError && rideState.rides.isEmpty) {
            return ErrorDisplayWidget(
              title: 'Failed to load ride history',
              message: rideState.errorMessage!,
              onRetry: () => _loadRides(context),
            );
          }

          // Calendar view: show header + full-screen calendar.
          if (_view == _ClientRidesView.calendar) {
            return Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ClientCalendarView(
                    onRideSelected: (ride) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            RideDetailsScreen(ride: ride, isClientView: true),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final clientId = authState.user?.id.toString();
          final upcoming = clientId != null
              ? _upcomingRides(rideState.rides, clientId)
              : <Ride>[];
          final past = clientId != null
              ? _pastRides(rideState.rides, clientId)
              : <Ride>[];

          if (upcoming.isEmpty &&
              past.isEmpty &&
              _period == _ClientPeriodFilter.all) {
            return _buildEmptyState();
          }

          return _buildBody(upcoming, past);
        },
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          // The "My Rides" title already lives in the top app bar, so the
          // graphite header only carries the centered List / Calendar toggle.
          child: Center(
            child: SegmentedButton<_ClientRidesView>(
              segments: const [
                ButtonSegment(
                  value: _ClientRidesView.list,
                  label: Text('List'),
                  icon: Icon(Icons.list),
                ),
                ButtonSegment(
                  value: _ClientRidesView.calendar,
                  label: Text('Calendar'),
                  icon: Icon(Icons.calendar_month),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (selection) {
                setState(() => _view = selection.first);
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : Colors.white70,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : Colors.transparent,
                ),
                side: WidgetStateProperty.all(
                  const BorderSide(color: Colors.white54),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Empty state ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history,
                  size: AppDimensions.iconLogo,
                  color: Theme.of(context).colorScheme.outlineVariant,
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
        ),
      ],
    );
  }

  // ─── Period selector ─────────────────────────────────────────────────────────

  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
        ),
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
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _period = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? cs.primary : cs.outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ─── Main body ───────────────────────────────────────────────────────────────

  Widget _buildBody(List<Ride> upcoming, List<Ride> past) {
    return RefreshIndicator(
      onRefresh: () async => _loadRides(context),
      child: CustomScrollView(
        slivers: [
          // Graphite header
          SliverToBoxAdapter(child: _buildHeader(context)),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.paddingMedium),
          ),

          // Period filter
          SliverToBoxAdapter(child: _buildPeriodSelector()),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.paddingMedium),
          ),

          // UPCOMING section
          if (upcoming.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionLabel('UPCOMING')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildUpcomingCard(context, upcoming[index]),
                childCount: upcoming.length,
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppDimensions.paddingMedium),
            ),
          ],

          // PAST section
          if (past.isNotEmpty) ...[
            SliverToBoxAdapter(child: _buildSectionLabel('PAST')),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildPastCard(context, past[index]),
                childCount: past.length,
              ),
            ),
          ] else if (upcoming.isEmpty) ...[
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
            ),
          ],

          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.paddingXLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingMedium,
        0,
        AppDimensions.paddingMedium,
        10,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.06 * 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // ─── Upcoming card ────────────────────────────────────────────────────────────

  /// Card for rides that are assigned / in-progress / requested.
  Widget _buildUpcomingCard(BuildContext context, Ride ride) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Status pill using RideStatusStyles for assigned/inProgress;
    // for "Confirmed" (assigned) we match the spec colors.
    final isPillConfirmed = ride.status == RideStatus.assigned;
    final pillBg = isDark ? AppColors.rideAssignedBgDark : AppColors.infoBg;
    final pillBorder = isDark
        ? AppColors.rideAssignedBorder.withValues(alpha: 0.4)
        : const Color(0xFF93C5FD);
    final dotColor = AppColors.rideAssigned; // #3B82F6
    final pillText = isPillConfirmed ? 'Confirmed' : ride.status.displayName;
    final pillTextColor = isDark
        ? AppColors.rideAssignedTextDark
        : AppColors.infoStrong; // #1E40AF

    final timeLabel = _formatPickupTime(ride.pickupDateTime);
    final route = '${ride.from.address} → ${ride.to.address}';

    // Detail line: ✈ <flight> · <vehicleClass> · €<price>
    final detailParts = <String>[];
    if (ride.flightNumber != null && ride.flightNumber!.isNotEmpty) {
      detailParts.add('✈ ${ride.flightNumber!}');
    }
    // vehicleClass not yet on model — omit gracefully
    if (ride.price != null) {
      detailParts.add('€${ride.price!.toStringAsFixed(0)}');
    }
    final detailLine = detailParts.join(' · ');

    final cardDecoration = BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowXs,
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideDetailsScreen(ride: ride, isClientView: true),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppDimensions.paddingMedium,
          0,
          AppDimensions.paddingMedium,
          10,
        ),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: status pill + time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isPillConfirmed
                        ? pillBg
                        : RideStatusStyles.getStatusBackgroundColor(
                            ride.status,
                            brightness: brightness,
                          ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isPillConfirmed
                          ? pillBorder
                          : RideStatusStyles.getStatusBorderColor(
                              ride.status,
                              brightness: brightness,
                            ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isPillConfirmed
                              ? dotColor
                              : RideStatusStyles.getStatusColor(ride.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        pillText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPillConfirmed
                              ? pillTextColor
                              : RideStatusStyles.getStatusTextColor(
                                  ride.status,
                                  brightness: brightness,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Time
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // Route
            const SizedBox(height: 10),
            Text(
              route,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Detail line
            if (detailLine.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                detailLine,
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Past card ────────────────────────────────────────────────────────────────

  /// Row card for completed / cancelled rides.
  Widget _buildPastCard(BuildContext context, Ride ride) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final route = '${ride.from.address} → ${ride.to.address}';
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
    final dt = ride.pickupDateTime;
    final dateStr = '${dt.day} ${months[dt.month - 1]}';
    final driverStr = ride.driverName ?? 'Unknown driver';
    final ratingStr = ride.rating != null ? '${ride.rating}★' : '';
    final subParts = [dateStr, driverStr, if (ratingStr.isNotEmpty) ratingStr];
    final subLine = subParts.join(' · ');

    // Status label color
    final isCompleted = ride.status == RideStatus.completed;
    final statusLabel = isCompleted ? 'Completed' : 'Cancelled';
    final statusColor = isCompleted
        ? (isDark
              ? AppColors.rideCompletedTextDark
              : AppColors.rideCompletedText)
        : (isDark
              ? AppColors.rideCancelledTextDark
              : AppColors.rideCancelledText);

    final cardDecoration = BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowXs,
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideDetailsScreen(ride: ride, isClientView: true),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppDimensions.paddingMedium,
          0,
          AppDimensions.paddingMedium,
          10,
        ),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: route + subline
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLine,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),

                  // Rate button for completed unrated rides
                  if (ride.status == RideStatus.completed &&
                      ride.rating == null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _showRateDialog(context, ride),
                      child: Text(
                        'Rate this ride',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: cs.secondary,
                        ),
                      ),
                    ),
                  ],

                  // Cancellation reason for cancelled rides
                  if (ride.status == RideStatus.cancelled &&
                      ride.cancellationReason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${ride.cancellationReason}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.rideCancelledTextDark
                            : AppColors.rideCancelledText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right column: price + status label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (ride.price != null)
                  Text(
                    '€${ride.price!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _formatPickupTime(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final time = AppDateUtils.formatTime(dt);
    return isToday ? 'Today $time' : AppDateUtils.formatDateTime(dt);
  }

  Future<void> _showRateDialog(BuildContext context, Ride ride) async {
    final apiClient = context.read<AuthBloc>().apiClient;
    final rideBloc = context.read<RideBloc>();
    final user = context.read<AuthBloc>().state.user;
    final messenger = ScaffoldMessenger.of(context);

    final result = await showAdaptiveDialog<Map<String, dynamic>?>(
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
}
