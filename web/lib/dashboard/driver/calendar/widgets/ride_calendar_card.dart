import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../modules/ride_management/models/ride.dart';
import '../../../../utils/ride_status_styles.dart';
import 'ride_badges.dart';

/// A visual ride card used in both [DayViewWidget] and [MultiColumnViewWidget].
///
/// The price block is tappable and opens a numeric input dialog that calls
/// [onPriceEdited] on confirm. When [showActions] is false (board view) the
/// Start/Complete action buttons are hidden.
///
/// When [compact] is true the card shows only the essentials — pickup time and
/// price — with reduced padding. The ride status is conveyed by the card's
/// border/background colour rather than a badge, and the client/location rows,
/// status chips and requirements are omitted entirely. Full details open on
/// tap. This prevents layout overflow in the narrow multi-column board view
/// where each column is only a fraction of the screen width.
class RideCalendarCard extends StatelessWidget {
  final Ride ride;

  /// Called when the card itself is tapped (open details).
  final VoidCallback? onTap;

  /// Called with the new price when the user confirms a price edit.
  final ValueChanged<double>? onPriceEdited;

  /// When true, renders the Start/Complete action buttons (day-view only).
  final bool showActions;

  /// Widget that renders the Start/Complete/phone/nav buttons.
  /// Supplied by the parent so this card has no direct dependency on RideBloc.
  final Widget? actionsWidget;

  /// When true, applies a compact layout for the narrow board view: reduced
  /// padding and only time + price (status as the card colour); client/location
  /// rows, chips and requirements are omitted. Defaults to false so the day-view
  /// is byte-for-byte unchanged.
  final bool compact;

  const RideCalendarCard({
    super.key,
    required this.ride,
    this.onTap,
    this.onPriceEdited,
    this.showActions = true,
    this.actionsWidget,
    this.compact = false,
  });

  static const double _avgCitySpeedKmh = 30;

  int? _estimatedTripMinutes() {
    final fromLat = ride.from.latitude;
    final fromLng = ride.from.longitude;
    final toLat = ride.to.latitude;
    final toLng = ride.to.longitude;
    if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
      return null;
    }
    final meters = geo.Geolocator.distanceBetween(
      fromLat,
      fromLng,
      toLat,
      toLng,
    );
    final minutes = (meters / 1000) / _avgCitySpeedKmh * 60;
    return minutes < 1 ? 1 : minutes.round();
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '~$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '~$h h' : '~$h h $m min';
  }

  void _showPriceDialog(BuildContext context) {
    if (onPriceEdited == null) return;
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: ride.price != null ? ride.price!.toStringAsFixed(2) : '',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.setRidePrice),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(prefixText: '€ ', hintText: '0.00'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                Navigator.of(ctx).pop();
                onPriceEdited!(value);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final statusColor = RideStatusStyles.getStatusColor(ride.status);
    final statusText = RideStatusStyles.getStatusLabel(ride.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(compact ? 8 : 16),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            border: Border.all(color: statusColor.withAlpha(77)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: full-width day-view uses a horizontal Row;
              // compact board view uses a stacked Column to avoid overflow.
              if (!compact)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          DateFormat.Hm().format(ride.pickupDateTime),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (_estimatedTripMinutes() case final mins?) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.timelapse,
                            size: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatDuration(mins),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        // Price block — tappable to open edit dialog.
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: onPriceEdited != null
                              ? () => _showPriceDialog(context)
                              : null,
                          child: ride.price != null
                              ? Text(
                                  '€${ride.price!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                    decoration: onPriceEdited != null
                                        ? TextDecoration.underline
                                        : null,
                                  ),
                                )
                              : onPriceEdited != null
                              ? Text(
                                  l10n.setPrice,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: colorScheme.onSurfaceVariant
                                        .withAlpha(153),
                                    decoration: TextDecoration.underline,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Compact body for the narrow board column: time (+ an airport
                // flag), price, the client name and the From → To route. Status
                // is still conveyed by the card's border/background colour. Rows
                // are kept terse (small font, single line, ellipsis) so the card
                // stays readable without overflowing the column.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DateFormat.Hm().format(ride.pickupDateTime),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        // Airport-transfer flag: the pickup may shift with the
                        // flight, so the dispatcher must spot it at a glance.
                        if (ride.isAirportTransfer) ...[
                          const SizedBox(width: 6),
                          Icon(
                            ride.flightIconData ?? Icons.flight,
                            size: 14,
                            color: AppColors.info,
                          ),
                        ],
                      ],
                    ),
                    if (ride.price != null || onPriceEdited != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onPriceEdited != null
                            ? () => _showPriceDialog(context)
                            : null,
                        child: ride.price != null
                            ? Text(
                                '€${ride.price!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                  decoration: onPriceEdited != null
                                      ? TextDecoration.underline
                                      : null,
                                ),
                              )
                            : Text(
                                l10n.setPrice,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurfaceVariant.withAlpha(
                                    153,
                                  ),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _compactInfoRow(
                      context,
                      Icons.person_outline,
                      ride.clientName,
                    ),
                    const SizedBox(height: 4),
                    _compactInfoRow(
                      context,
                      Icons.trip_origin,
                      ride.from.address,
                    ),
                    const SizedBox(height: 2),
                    _compactInfoRow(
                      context,
                      Icons.place_outlined,
                      ride.to.address,
                    ),
                  ],
                ),
              if (!compact) ...[
                RideBadges.chips(context, ride),
                const SizedBox(height: 12),
                _locationRow(context, Icons.person, 'Client', ride.clientName),
                const SizedBox(height: 8),
                _locationRow(
                  context,
                  Icons.location_on,
                  'From',
                  ride.from.address,
                ),
                const SizedBox(height: 8),
                _locationRow(context, Icons.flag, 'To', ride.to.address),
                RideBadges.requirements(context, ride),
              ],
              if (showActions && actionsWidget != null) ...[
                const SizedBox(height: 12),
                actionsWidget!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// A terse single-line icon + text row for the compact board card (client
  /// name, pickup, dropoff). Truncates with an ellipsis so a long address can
  /// never push the card past the column width.
  Widget _compactInfoRow(BuildContext context, IconData icon, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _locationRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
