import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../../../modules/ride_management/models/ride.dart';
import '../../../../utils/ride_status_styles.dart';
import 'ride_badges.dart';

/// A visual ride card used in both [DayViewWidget] and [MultiColumnViewWidget].
///
/// The price block is tappable and opens a numeric input dialog that calls
/// [onPriceEdited] on confirm. When [showActions] is false (board view) the
/// Start/Complete action buttons are hidden.
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

  const RideCalendarCard({
    super.key,
    required this.ride,
    this.onTap,
    this.onPriceEdited,
    this.showActions = true,
    this.actionsWidget,
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
    final controller = TextEditingController(
      text: ride.price != null ? ride.price!.toStringAsFixed(2) : '',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set ride price'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(prefixText: '€ ', hintText: '0.00'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                Navigator.of(ctx).pop();
                onPriceEdited!(value);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = RideStatusStyles.getStatusColor(ride.status);
    final statusText = RideStatusStyles.getStatusLabel(ride.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(25),
            border: Border.all(color: statusColor.withAlpha(77)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: time/duration/price + status badge
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
                                'Set price',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: colorScheme.onSurfaceVariant.withAlpha(
                                    153,
                                  ),
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
              ),
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
