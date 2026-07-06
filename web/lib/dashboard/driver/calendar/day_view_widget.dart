import 'package:flutter/material.dart';
import '../../../modules/core/services/error_messages.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/ride_management/services/ride_service.dart';
import '../../../modules/core/navigation_utils.dart';
import '../../../modules/core/navigation_helper.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../utils/ride_status_styles.dart';
import 'day_timeline.dart';
import 'widgets/ride_calendar_card.dart';

class DayViewWidget extends StatelessWidget {
  final DateTime selectedDay;
  final Function(Ride) onRideSelected;

  /// When set, only rides assigned to this driver are shown. Null shows all
  /// rides (back-compat). Follows the schedule screen's driver dropdown.
  final String? driverIdFilter;

  /// When non-null, the calendar renders exactly this list instead of the
  /// shared RideBloc's rides. The dispatcher calendar uses it to show the
  /// selected driver's rides (loaded on demand) without touching the shared
  /// RideBloc that feeds the other dashboard tabs. The list is assumed to be
  /// already scoped to the chosen driver, so [driverIdFilter] is a no-op for it.
  final List<Ride>? ridesOverride;

  /// The displayed driver's work shifts; the ones falling on [selectedDay]
  /// render as availability chips under the day header. Cancelled shifts must
  /// be filtered out by the caller.
  final List<ScheduleDay> shifts;

  /// Invoked after an in-card mutation (e.g. a price edit) that the RideBloc
  /// refresh alone can't surface. When the calendar is driven by [ridesOverride]
  /// (a selected colleague's rides), that list is owned by the parent and is not
  /// refetched by the RideBloc reload, so the parent must re-load it here.
  final VoidCallback? onRidesChanged;

  const DayViewWidget({
    super.key,
    required this.selectedDay,
    required this.onRideSelected,
    this.driverIdFilter,
    this.ridesOverride,
    this.shifts = const [],
    this.onRidesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final override = ridesOverride;
    if (override != null) {
      return _buildBody(context, colorScheme, override);
    }
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) =>
          _buildBody(context, colorScheme, rideState.rides),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colorScheme,
    List<Ride> rides,
  ) {
    final dayRides = getRidesForDay(rides, selectedDay);
    dayRides.sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
    final dayShifts = shiftsForSelectedDay();
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildDayHeader(context),
          buildShiftRow(context),
          Expanded(
            child: dayRides.isEmpty && dayShifts.isEmpty
                ? buildEmptyState(context)
                // Hour-scale timeline on the left (shift availability regions
                // + ride blocks, like the week view), ride cards on the right.
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 110,
                        child: buildDayTimeline(context, dayRides, dayShifts),
                      ),
                      Expanded(
                        child: dayRides.isEmpty
                            ? buildEmptyState(context)
                            : buildRidesList(context, dayRides),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// The displayed driver's shifts falling on [selectedDay], sorted by start.
  List<ScheduleDay> shiftsForSelectedDay() =>
      shifts
          .where(
            (s) =>
                s.date.year == selectedDay.year &&
                s.date.month == selectedDay.month &&
                s.date.day == selectedDay.day,
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// The vertical hour-scale timeline on the left of the day card: shift
  /// availability regions with the ride blocks on top, like the week view.
  Widget buildDayTimeline(
    BuildContext context,
    List<Ride> dayRides,
    List<ScheduleDay> dayShifts,
  ) {
    return DayTimeline(
      shiftRegions: dayShifts
          .map(
            (shift) => TimelineShiftRegion(
              keyValue: 'day-tl-shift-${shift.id}',
              startTime: shift.startTime,
              endTime: shift.endTime,
            ),
          )
          .toList(),
      blocks: [
        for (final ride in dayRides)
          TimelineBlock(
            keyValue: 'day-tl-ride-${ride.id}',
            startHour:
                ride.pickupDateTime.hour + ride.pickupDateTime.minute / 60.0,
            endHour:
                ride.pickupDateTime.hour +
                ride.pickupDateTime.minute / 60.0 +
                // Rides carry no duration; use the week view's nominal 1.5 h.
                1.5,
            color: RideStatusStyles.getStatusColor(ride.status).withAlpha(204),
            borderColor: RideStatusStyles.getStatusColor(ride.status),
            onTap: () => onRideSelected(ride),
            content: Text(
              DateFormat.Hm().format(ride.pickupDateTime),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  /// Availability chips for the selected day's work shifts, right under the
  /// header. Collapses to nothing when the day has no shifts.
  Widget buildShiftRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayShifts = shiftsForSelectedDay();
    if (dayShifts.isEmpty) return const SizedBox.shrink();

    String hhmm(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: dayShifts
            .map(
              (shift) => Container(
                key: ValueKey('day-shift-${shift.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 14, color: AppColors.success),
                    const SizedBox(width: 5),
                    Text(
                      '${l10n.sharedCalendarShift} ${hhmm(shift.startTime)}–${hhmm(shift.endTime)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget buildDayHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(60),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.EEEE().format(selectedDay),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                DateFormat.yMMMd().format(selectedDay),
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (isSameDay(selectedDay, DateTime.now()))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.today,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noRidesScheduled,
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.enjoyYourFreeDay,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget buildRidesList(BuildContext context, List<Ride> rides) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length + getTravelTimeSlots(rides).length,
      itemBuilder: (context, index) {
        final items = buildTimelineItems(context, rides);
        if (index >= items.length) return const SizedBox.shrink();
        return items[index];
      },
    );
  }

  List<Widget> buildTimelineItems(BuildContext context, List<Ride> rides) {
    final items = <Widget>[];

    for (int i = 0; i < rides.length; i++) {
      final ride = rides[i];
      items.add(buildRideCard(context, ride, i == rides.length - 1));

      if (i < rides.length - 1) {
        final nextRide = rides[i + 1];
        final travelTime = nextRide.pickupDateTime
            .difference(ride.pickupDateTime)
            .inMinutes;
        items.add(buildTravelTimeIndicator(context, travelTime));
      }
    }

    return items;
  }

  Widget buildRideCard(BuildContext context, Ride ride, bool isLast) {
    return RideCalendarCard(
      ride: ride,
      onTap: () => onRideSelected(ride),
      onPriceEdited: (newPrice) => _handlePriceEdited(context, ride, newPrice),
      showActions: true,
      actionsWidget: buildActionButtons(context, ride),
    );
  }

  void _handlePriceEdited(BuildContext context, Ride ride, double newPrice) {
    final apiClient = context.read<AuthBloc>().apiClient;
    final rideService = RideService(apiClient: apiClient);
    rideService
        .setRidePrice(ride.id, newPrice)
        .then((_) {
          rideService.dispose();
          if (context.mounted) {
            final user = context.read<AuthBloc>().state.user;
            if (user != null) {
              context.read<RideBloc>().add(RideLoadRequested(user: user));
            }
            // When a colleague's schedule is shown, the card renders from the
            // parent-owned [ridesOverride], which the RideBloc reload above does
            // not touch — ask the parent to refetch it so the new price shows.
            onRidesChanged?.call();
          }
        })
        .catchError((Object e) {
          rideService.dispose();
          if (context.mounted) {
            NavigationHelper.showSnackBar(
              context,
              AppLocalizations.of(context)!.failedToSetPrice(
                friendlyError(e, AppLocalizations.of(context)!),
              ),
              isError: true,
            );
          }
        });
  }

  Widget buildActionButtons(BuildContext context, Ride ride) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _handleCall(context, ride),
                icon: const Icon(Icons.phone, color: AppColors.success),
                tooltip: l10n.callClient,
              ),
              IconButton(
                onPressed: () =>
                    NavigationUtils.showNavigateToDialog(context, ride),
                icon: const Icon(Icons.navigation, color: AppColors.info),
                tooltip: l10n.startNavigation,
              ),
            ],
          ),
        ),
        if (ride.status == RideStatus.assigned)
          Flexible(
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<RideBloc>().add(
                  RideStatusUpdateRequested(
                    rideId: ride.id,
                    status: RideStatus.inProgress,
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(l10n.start),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          )
        else if (ride.status == RideStatus.inProgress)
          Flexible(
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<RideBloc>().add(
                  RideStatusUpdateRequested(
                    rideId: ride.id,
                    status: RideStatus.completed,
                  ),
                );
              },
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.completeRideButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  void _handleCall(BuildContext context, Ride ride) {
    final phone = ride.client.phone;
    if (phone == null || phone.isEmpty) {
      NavigationHelper.showSnackBar(
        context,
        'No phone number available',
        isError: true,
      );
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.success),
              title: Text(l10n.call),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('tel:$phone'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.message, color: AppColors.info),
              title: Text(l10n.sms),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('sms:$phone'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTravelTimeIndicator(BuildContext context, int minutes) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 30,
            color: colorScheme.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Icon(
            Icons.directions_car,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.travelTimeMinutes(minutes),
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  List<Ride> getRidesForDay(List<Ride> rides, DateTime day) {
    return rides.where((ride) {
      if (driverIdFilter != null && ride.driverId != driverIdFilter) {
        return false;
      }
      final rideDate = DateTime(
        ride.pickupDateTime.year,
        ride.pickupDateTime.month,
        ride.pickupDateTime.day,
      );
      final targetDate = DateTime(day.year, day.month, day.day);
      return rideDate == targetDate;
    }).toList();
  }

  List<int> getTravelTimeSlots(List<Ride> rides) {
    final travelTimes = <int>[];
    for (int i = 0; i < rides.length - 1; i++) {
      final currentRide = rides[i];
      final nextRide = rides[i + 1];
      final travelTime = nextRide.pickupDateTime
          .difference(currentRide.pickupDateTime)
          .inMinutes;
      travelTimes.add(travelTime);
    }
    return travelTimes;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
