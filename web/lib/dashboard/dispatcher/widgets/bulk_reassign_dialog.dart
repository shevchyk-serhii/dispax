import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_styles.dart';
import '../../../constants/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/ride_management/helpers/flight_status_l10n.dart';

// ─── Driver candidate model ──────────────────────────────────────────────────

enum _CandidateFit { best, alternative, late }

class _DriverCandidate {
  final String driverId;
  final String label;
  final int etaDeltaMinutes; // positive = adds delay, negative = time to spare
  final int slackMinutes;
  final _CandidateFit fit;
  final String scheduleRange;

  const _DriverCandidate({
    required this.driverId,
    required this.label,
    required this.etaDeltaMinutes,
    required this.slackMinutes,
    required this.fit,
    required this.scheduleRange,
  });
}

// ─── BulkReassignDialog ───────────────────────────────────────────────────────

class BulkReassignDialog extends StatefulWidget {
  final String fromDriverId;
  final String fromDriverLabel;
  final List<Ride> rides;

  /// If provided, these are the rides where delay is the trigger.
  /// The first ride is shown as the "failing" ride in the alert banner.
  final Ride? failingRide;

  /// Slack in minutes for the failing ride (negative = will be late).
  final int? slackMinutes;

  const BulkReassignDialog({
    super.key,
    required this.fromDriverId,
    required this.fromDriverLabel,
    required this.rides,
    this.failingRide,
    this.slackMinutes,
  });

  @override
  State<BulkReassignDialog> createState() => _BulkReassignDialogState();
}

class _BulkReassignDialogState extends State<BulkReassignDialog> {
  String? _selectedDriverId;
  String? _selectedDriverLabel;
  final Set<String> _selectedRideIds = {};
  bool _isReassigning = false;

  @override
  void initState() {
    super.initState();
    _selectedRideIds.addAll(widget.rides.map((r) => r.id));
  }

  // ── Candidate ranking ──────────────────────────────────────────────────────

  List<_DriverCandidate> _buildCandidates(
    List<ScheduleDay> scheduleDays,
    List<Ride> allRides,
  ) {
    final candidates = <_DriverCandidate>[];

    final others = scheduleDays
        .where(
          (d) =>
              d.driverId != widget.fromDriverId &&
              d.status != ScheduleDayStatus.cancelled,
        )
        .toList();

    for (final schedule in others) {
      final currentRideCount = allRides
          .where(
            (r) =>
                r.driverId == schedule.driverId &&
                r.status != RideStatus.cancelled &&
                r.status != RideStatus.completed,
          )
          .length;

      // Estimate slack from current ride load:
      // 0 rides → plenty of slack; more rides → tighter schedule
      final etaDelta = currentRideCount == 0
          ? 4
          : currentRideCount == 1
          ? 12
          : currentRideCount * 8;
      final slack = currentRideCount == 0 ? 28 : 45 - (currentRideCount * 12);

      _CandidateFit fit;
      if (currentRideCount == 0) {
        fit = _CandidateFit.best;
      } else if (slack > 0) {
        fit = _CandidateFit.alternative;
      } else {
        fit = _CandidateFit.late;
      }

      final notes = schedule.notes;
      final label = notes != null && notes.isNotEmpty
          ? notes
          : 'Driver ${schedule.driverId.length > 8 ? schedule.driverId.substring(0, 8) : schedule.driverId}…';

      candidates.add(
        _DriverCandidate(
          driverId: schedule.driverId,
          label: label,
          etaDeltaMinutes: etaDelta,
          slackMinutes: slack,
          fit: fit,
          scheduleRange: '${schedule.startTime}–${schedule.endTime}',
        ),
      );
    }

    // Sort: best first, then alternative, then late; within group by eta delta
    candidates.sort((a, b) {
      final fitOrder = a.fit.index.compareTo(b.fit.index);
      if (fitOrder != 0) return fitOrder;
      return a.etaDeltaMinutes.compareTo(b.etaDeltaMinutes);
    });

    return candidates;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheduleState = context.read<ScheduleBloc>().state;
    final rideState = context.read<RideBloc>().state;
    final candidates = _buildCandidates(
      scheduleState.scheduleDays,
      rideState.rides,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final clientLabel = widget.rides.isNotEmpty
        ? widget.rides.first.clientName
        : '?';

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Graphite header ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: AppDimensions.paddingMedium,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusMedium),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.reassignRideDialogTitle(clientLabel),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isReassigning ? null : () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Failing-ride alert banner
                    if (widget.failingRide != null ||
                        widget.slackMinutes != null)
                      _buildAlertBanner(isDark),

                    // Ride selection
                    if (widget.rides.length > 1) ...[
                      const SizedBox(height: 4),
                      _buildRideSelector(isDark),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                    ],

                    // Section label
                    Text(
                      l10n.nearestAvailableDriversLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Candidate list
                    if (candidates.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceVariantDark
                              : AppColors.warningBg,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMedium,
                          ),
                          border: Border.all(color: AppColors.warningBorder),
                        ),
                        child: Text(
                          l10n.noDriversAvailableForReassignment,
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...candidates.map((c) => _buildCandidateCard(c, isDark)),
                  ],
                ),
              ),
            ),

            // ── Footer actions ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMedium,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderPrimary,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: AppStyles.textButtonStyleOf(context),
                    onPressed: _isReassigning
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: AppStyles.accentButtonStyle,
                    onPressed:
                        _selectedRideIds.isEmpty ||
                            _selectedDriverId == null ||
                            _isReassigning
                        ? null
                        : _executeBulkReassign,
                    icon: _isReassigning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.swap_horiz, size: 18),
                    label: Text(
                      _isReassigning
                          ? 'Reassigning…'
                          : l10n.reassignNRides(_selectedRideIds.length),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Alert banner ─────────────────────────────────────────────────────────

  Widget _buildAlertBanner(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final slack = widget.slackMinutes ?? -5;
    final slackStr = slack < 0 ? '$slack' : '+$slack';
    final driverLabel = widget.fromDriverLabel;
    final failingRide = widget.failingRide;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.rideCancelledBgDark : AppColors.errorBg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.rideCancelledBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.driverDelayedMessage(driverLabel, slackStr),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    // On the dark rideCancelledBgDark surface the dark
                    // errorStrong red is invisible; use the light *Dark variant.
                    color: isDark
                        ? AppColors.rideCancelledTextDark
                        : AppColors.errorStrong,
                  ),
                ),
              ),
            ],
          ),
          if (failingRide != null) ...[
            const SizedBox(height: 6),
            Text(
              '${DateFormat('HH:mm').format(failingRide.pickupDateTime)} · '
              '${failingRide.clientName} · '
              '${failingRide.from.address} → ${failingRide.to.address}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.rideCancelledText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Ride selector ────────────────────────────────────────────────────────

  Widget _buildRideSelector(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.ridesToReassignLabel(
                _selectedRideIds.length,
                widget.rides.length,
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(60, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedRideIds.length == widget.rides.length) {
                    _selectedRideIds.clear();
                  } else {
                    _selectedRideIds.addAll(widget.rides.map((r) => r.id));
                  }
                });
              },
              child: Text(
                _selectedRideIds.length == widget.rides.length
                    ? l10n.deselectAllButton
                    : l10n.selectAllButton,
                style: const TextStyle(fontSize: 12, color: AppColors.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...widget.rides.map(
          (ride) => CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.accent,
            value: _selectedRideIds.contains(ride.id),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedRideIds.add(ride.id);
                } else {
                  _selectedRideIds.remove(ride.id);
                }
              });
            },
            title: Text(
              '${DateFormat('HH:mm').format(ride.pickupDateTime)} — ${ride.clientName}',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ride.from.address} → ${ride.to.address}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Flight info for airport rides so the dispatcher can tell
                // airport transfers apart when bulk-reassigning.
                if (ride.isAirportTransfer && ride.fullFlightInfo.isNotEmpty)
                  Text(
                    () {
                      final statusText = l10n.localizedFlightStatus(
                        ride.flightStatus,
                      );
                      return statusText.isEmpty
                          ? ride.fullFlightInfo
                          : '${ride.fullFlightInfo} • ${ride.flightStatusIcon} $statusText';
                    }(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Candidate card ────────────────────────────────────────────────────────

  Widget _buildCandidateCard(_DriverCandidate c, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final isSelected = _selectedDriverId == c.driverId;
    final isBest = c.fit == _CandidateFit.best;
    final isLate = c.fit == _CandidateFit.late;

    // ETA label colour
    final etaColor = isLate
        ? const Color(0xFFDC2626)
        : isBest
        ? AppColors.accent
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);

    // Slack label
    final slackText = isLate
        ? l10n.stillLateLabel
        : isBest
        ? l10n.slackRestoredLabel
        : l10n.tightLabel;

    final slackColor = isLate
        ? const Color(0xFFDC2626)
        : isBest
        ? AppColors.success
        : AppColors.warning;

    // Border
    final borderColor = isSelected
        ? AppColors.accent
        : isBest
        ? AppColors.accent.withValues(alpha: 0.35)
        : (isDark ? AppColors.borderDark : AppColors.borderPrimary);
    final borderWidth = (isSelected || isBest) ? 2.0 : 1.0;

    // Card surface
    final cardColor = isSelected
        ? (isDark
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.rideAssignedBg)
        : (isDark ? AppColors.surfaceDark : AppColors.surface);

    return GestureDetector(
      onTap: isLate
          ? null
          : () {
              setState(() {
                _selectedDriverId = c.driverId;
                _selectedDriverLabel = c.label;
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: isLate
                  ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                  : isBest
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : (isDark
                        ? AppColors.surfaceVariantDark
                        : AppColors.primarySurface),
              child: Icon(
                Icons.person_outline,
                size: 18,
                color: isLate
                    ? const Color(0xFFDC2626)
                    : isBest
                    ? AppColors.accent
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 10),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // Best match badge
                      if (isBest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(
                              alpha: isDark ? 0.15 : 0.1,
                            ),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.bestMatchBadge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.accentLight
                                  : AppColors.accentDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    c.scheduleRange,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Right column: ETA + action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ETA delta
                Text(
                  '+${c.etaDeltaMinutes} min',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: etaColor,
                  ),
                ),
                // Slack label
                Text(
                  slackText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: slackColor,
                  ),
                ),
                const SizedBox(height: 6),
                // Action button
                if (isLate)
                  OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(80, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(l10n.reassign),
                  )
                else if (isBest)
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _selectedDriverId = c.driverId;
                        _selectedDriverLabel = c.label;
                      });
                    },
                    style: AppStyles.accentButtonStyle.copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(80, 28)),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    child: Text(l10n.reassign),
                  )
                else
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDriverId = c.driverId;
                        _selectedDriverLabel = c.label;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                      side: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderSecondary,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(80, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(l10n.reassign),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Execute reassign ──────────────────────────────────────────────────────

  void _executeBulkReassign() {
    final selectedDriverId = _selectedDriverId;
    if (selectedDriverId == null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isReassigning = true);

    final rideBloc = context.read<RideBloc>();
    for (final rideId in _selectedRideIds) {
      rideBloc.add(
        RideReassignRequested(rideId: rideId, newDriverId: selectedDriverId),
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.ridesReassignedMessage(
            _selectedRideIds.length,
            _selectedDriverLabel ?? '',
          ),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
