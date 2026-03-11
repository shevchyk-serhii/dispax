import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../constants/app_colors.dart';

class BulkReassignDialog extends StatefulWidget {
  final String fromDriverId;
  final String fromDriverLabel;
  final List<Ride> rides;

  const BulkReassignDialog({
    super.key,
    required this.fromDriverId,
    required this.fromDriverLabel,
    required this.rides,
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

  @override
  Widget build(BuildContext context) {
    final scheduleState = context.read<ScheduleBloc>().state;
    final otherDrivers = scheduleState.scheduleDays
        .where((d) =>
            d.driverId != widget.fromDriverId &&
            d.status != ScheduleDayStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bulk Reassign Rides',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'From: ${widget.fromDriverLabel}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ride selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select rides to reassign (${_selectedRideIds.length}/${widget.rides.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedRideIds.length == widget.rides.length) {
                                _selectedRideIds.clear();
                              } else {
                                _selectedRideIds.addAll(widget.rides.map((r) => r.id));
                              }
                            });
                          },
                          child: Text(_selectedRideIds.length == widget.rides.length ? 'Deselect All' : 'Select All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.rides.map((ride) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
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
                      subtitle: Text(
                        '${ride.from.address} → ${ride.to.address}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Target driver selection
                    const Text(
                      'Reassign to:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    if (otherDrivers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Text(
                          'No other drivers available for reassignment.',
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      )
                    else
                      ...otherDrivers.map((schedule) {
                        final rideState = context.read<RideBloc>().state;
                        final rideCount = rideState.rides
                            .where((r) =>
                                r.driverId == schedule.driverId &&
                                r.status != RideStatus.cancelled &&
                                r.status != RideStatus.completed)
                            .length;
                        final loadColor = rideCount == 0
                            ? Colors.green
                            : rideCount <= 2
                                ? Colors.orange
                                : Colors.red;
                        final label = schedule.notes?.isNotEmpty == true
                            ? schedule.notes!
                            : 'Driver ${schedule.driverId.length > 8 ? schedule.driverId.substring(0, 8) : schedule.driverId}...';
                        final isSelected = _selectedDriverId == schedule.driverId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: isSelected
                                ? BorderSide(color: AppColors.primary, width: 2)
                                : BorderSide.none,
                          ),
                          color: isSelected ? AppColors.rideAssignedBg : null,
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: loadColor.withAlpha(40),
                              child: Icon(Icons.person, color: loadColor, size: 18),
                            ),
                            title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(
                              '$rideCount ride${rideCount == 1 ? '' : 's'} • ${schedule.startTime}–${schedule.endTime}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppColors.primary)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedDriverId = schedule.driverId;
                                _selectedDriverLabel = label;
                              });
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isReassigning ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _selectedRideIds.isEmpty || _selectedDriverId == null || _isReassigning
                        ? null
                        : _executeBulkReassign,
                    icon: _isReassigning
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.swap_horiz),
                    label: Text(
                      _isReassigning
                          ? 'Reassigning...'
                          : 'Reassign ${_selectedRideIds.length} ride${_selectedRideIds.length == 1 ? '' : 's'}',
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

  void _executeBulkReassign() {
    setState(() => _isReassigning = true);

    final rideBloc = context.read<RideBloc>();
    for (final rideId in _selectedRideIds) {
      rideBloc.add(RideReassignRequested(
        rideId: rideId,
        newDriverId: _selectedDriverId!,
      ));
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_selectedRideIds.length} ride${_selectedRideIds.length == 1 ? '' : 's'} reassigned to $_selectedDriverLabel',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
}
