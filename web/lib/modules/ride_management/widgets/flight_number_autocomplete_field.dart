import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_dimensions.dart';
import '../../flight_management/models/muc_flight.dart';
import '../../flight_management/services/arrivals_board_service.dart';
import '../helpers/flight_number_input.dart';

/// Flight-number input with autosuggestions from the MUC flights board.
///
/// The day's board for ([flightDate], [isArrival]) is fetched lazily on the
/// FIRST focus (zero network for non-airport rides) and cached per
/// (date, direction) key; changing the date or the arrival/departure toggle
/// drops the cache so the next focus refetches. Suggestions are filtered
/// locally by normalized contains-match and capped at 5.
///
/// Degrades gracefully to a plain text field (no suggestions, no crash) when
/// no [service] is passed and the [ArrivalsBoardService] singleton is not
/// configured, when the request fails, or when the board has no data for the
/// date (MUC only serves roughly ±2 weeks around today).
class FlightNumberAutocompleteField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String labelText;
  final String hintText;
  final IconData prefixIconData;
  final Color? prefixIconColor;
  final String? Function(String?)? validator;

  /// Direction of the flight — part of the board cache key.
  final bool isArrival;

  /// Date the suggestions are fetched for; defaults to today when null.
  final DateTime? flightDate;

  /// Board service override for tests; falls back to
  /// [ArrivalsBoardService.instanceOrNull] (null → suggestions disabled).
  final ArrivalsBoardService? service;

  const FlightNumberAutocompleteField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelText,
    required this.hintText,
    required this.prefixIconData,
    required this.isArrival,
    this.prefixIconColor,
    this.validator,
    this.flightDate,
    this.service,
  });

  @override
  State<FlightNumberAutocompleteField> createState() =>
      _FlightNumberAutocompleteFieldState();
}

class _FlightNumberAutocompleteFieldState
    extends State<FlightNumberAutocompleteField> {
  // We own the controller and focus node so we can sync the displayed text on
  // external changes (form clear, edit-ride prefill) WITHOUT rebuilding
  // Autocomplete — rebuilding would drop focus (see AddressAutocompleteField).
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  List<MucFlight> _flights = const [];
  String? _loadedKey;
  bool _loading = false;

  String get _cacheKey {
    final date = widget.flightDate ?? DateTime.now();
    return '${DateFormat('yyyy-MM-dd').format(date)}|${widget.isArrival}';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(FlightNumberAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync the field text only on EXTERNAL changes — i.e. when this field is
    // not focused. While the user is typing here, its own onChanged already
    // drives the value, so touching the controller would move the caret.
    if (oldWidget.value != widget.value &&
        widget.value != _controller.text &&
        !_focusNode.hasFocus) {
      _syncControllerText(widget.value);
    }
    // Date or direction changed → the cached board is stale; the next focus
    // (or the current one, below) refetches for the new key.
    if (_loadedKey != null && _loadedKey != _cacheKey) {
      _flights = const [];
      _loadedKey = null;
      if (_focusNode.hasFocus) _ensureLoaded();
    }
  }

  /// Writes [next] into the controller, deferring to the next frame when
  /// called mid-build (setting controller.text notifies Form listeners, and a
  /// setState during build throws). Mirrors AddressAutocompleteField.
  void _syncControllerText(String next) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final midFrame =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!midFrame) {
      _controller.text = next;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (next != _controller.text && !_focusNode.hasFocus) {
        _controller.text = next;
      }
    });
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (_loading || _loadedKey == _cacheKey) return;
    final service = widget.service ?? ArrivalsBoardService.instanceOrNull;
    if (service == null) return;

    final key = _cacheKey;
    final parts = key.split('|');
    _loading = true;
    try {
      final flights = await service.getArrivals(
        date: parts[0],
        isArrival: parts[1] == 'true',
      );
      if (!mounted || key != _cacheKey) return; // stale response
      setState(() {
        _flights = flights;
        _loadedKey = key;
      });
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<MucFlight> _getFiltered(String query) {
    if (query.isEmpty) return _flights.take(5).toList();
    final normalized = FlightNumber.normalize(query);
    if (normalized.isEmpty) return _flights.take(5).toList();
    return _flights
        .where(
          (f) => FlightNumber.normalize(f.flightNumber).contains(normalized),
        )
        .take(5)
        .toList();
  }

  String? _timeLabel(MucFlight flight) {
    final time = flight.estimatedTime ?? flight.scheduledTime;
    return time == null ? null : DateFormat('HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<MucFlight>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        if (_flights.isEmpty) return const Iterable.empty();
        return _getFiltered(textEditingValue.text);
      },
      displayStringForOption: (flight) => flight.flightNumber,
      onSelected: (flight) => widget.onChanged(flight.flightNumber),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixIcon: Icon(
                  widget.prefixIconData,
                  color:
                      widget.prefixIconColor ??
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        tooltip: 'Clear',
                        splashRadius: 18,
                        onPressed: () {
                          controller.clear();
                          widget.onChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                ),
              ),
              // Always upper-case as the user types (LH429, not lh429).
              inputFormatters: const [UpperCaseTextFormatter()],
              validator: widget.validator,
              onChanged: widget.onChanged,
            );
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final flight = options.elementAt(index);
                    final subtitle = [
                      if (flight.airline != null) flight.airline!,
                      if (flight.origin != null) flight.origin!,
                    ].join(' · ');
                    final time = _timeLabel(flight);
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        widget.isArrival
                            ? Icons.flight_land
                            : Icons.flight_takeoff,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        flight.flightNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                      trailing: time == null
                          ? null
                          : Text(
                              time,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                      onTap: () => onSelected(flight),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
