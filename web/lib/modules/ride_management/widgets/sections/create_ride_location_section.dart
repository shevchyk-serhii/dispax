import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../address_autocomplete_field.dart';
import '../../helpers/airport_catalog.dart';
import '../../models/client_address.dart';
import '../../services/client_address_service.dart';
import '../../services/recent_addresses_store.dart';
import '../../../core/services/mapbox_service.dart';
import '../../../core/utils/service_zone.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';

/// Resolves how reachable an address is (geocode + service-zone check). Injected
/// so widget tests can supply a deterministic result without hitting Mapbox.
///
/// Used only as a fallback now: the live suggester already carries coordinates,
/// so reachability is normally classified from the suggestion response without a
/// second geocode. This still runs when no suggestion carried coordinates.
typedef ReachabilityResolver =
    Future<ReachabilityResult> Function(String address);

/// Returns address suggestions (with coordinates) for a typed query. Injected so
/// widget tests can supply deterministic suggestions without hitting Mapbox.
typedef AddressSuggester =
    Future<List<AddressSuggestion>> Function(String query);

/// Loads locally-cached recent addresses. Injected so widget tests can supply
/// deterministic recents without touching SharedPreferences.
typedef RecentAddressesLoader = Future<List<ClientAddress>> Function();

class CreateRideLocationSection extends StatefulWidget {
  /// Defaults to the real Mapbox-backed check; overridden in tests.
  final ReachabilityResolver reachabilityResolver;

  /// Defaults to the real Mapbox-backed suggester; overridden in tests.
  final AddressSuggester addressSuggester;

  /// Defaults to the SharedPreferences-backed recent store; overridden in tests.
  final RecentAddressesLoader recentAddressesLoader;

  const CreateRideLocationSection({
    super.key,
    this.reachabilityResolver = ServiceZone.reachabilityOf,
    this.addressSuggester = MapboxService.suggestAddressesDetailed,
    this.recentAddressesLoader = _loadRecentAddresses,
  });

  static Future<List<ClientAddress>> _loadRecentAddresses() =>
      const RecentAddressesStore().load();

  @override
  State<CreateRideLocationSection> createState() =>
      _CreateRideLocationSectionState();
}

class _CreateRideLocationSectionState extends State<CreateRideLocationSection> {
  late final ClientAddressService _addressService;
  late final CreateRideFormBloc _formBloc;
  late final StreamSubscription<CreateRideFormState> _subscription;
  List<ClientAddress> _savedAddresses = [];
  String? _loadedForClientId;
  // Locally-cached recent/frequent addresses (device-only, offline). Merged
  // after saved places and before live Mapbox results so the dispatcher sees
  // instant suggestions even for a short query the live suggester ignores.
  List<ClientAddress> _recentAddresses = [];

  // Soft, advisory reachability of the current from/to addresses. Never blocks
  // submission — it only drives an inline warning under each field.
  ReachabilityResult? _fromReachability;
  ReachabilityResult? _toReachability;
  // The address each result was computed for, so a stale async response for an
  // address the user has since edited is discarded.
  String? _fromCheckedAddress;
  String? _toCheckedAddress;
  Timer? _fromDebounce;
  Timer? _toDebounce;

  // Live Mapbox suggestions per field, merged (saved-first) with the client's
  // saved places before being handed to each AddressAutocompleteField.
  List<ClientAddress> _fromSuggestions = [];
  List<ClientAddress> _toSuggestions = [];

  static const Duration _debounce = Duration(milliseconds: 600);
  // Synthetic Mapbox-suggestion timestamp (epoch) — these suggestions are not
  // persisted, the ClientAddress model just requires non-null dates.
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _formBloc = context.read<CreateRideFormBloc>();
    _addressService = ClientAddressService(
      apiClient: context.read<AuthBloc>().apiClient,
    );

    final currentClientId = _formBloc.state.selectedClientId;
    if (currentClientId != null) {
      _loadAddresses(currentClientId);
    }
    _loadRecent();

    // Check whatever the form already holds (e.g. prefilled from a duplicated
    // ride) on first build.
    _scheduleFromCheck(_formBloc.state.fromAddress, immediate: true);
    _scheduleToCheck(_formBloc.state.toAddress, immediate: true);

    _subscription = _formBloc.stream.listen((state) {
      if (!mounted) return;
      final clientId = state.selectedClientId;
      if (clientId == null) {
        setState(() {
          _savedAddresses = [];
          _loadedForClientId = null;
        });
      } else if (clientId != _loadedForClientId) {
        _loadAddresses(clientId);
      }
    });
  }

  Future<void> _loadRecent() async {
    try {
      final recent = await widget.recentAddressesLoader();
      if (mounted) setState(() => _recentAddresses = recent);
    } catch (_) {
      // Recents are best-effort; a load failure just means no local suggestions.
    }
  }

  @override
  void dispose() {
    _fromDebounce?.cancel();
    _toDebounce?.cancel();
    _subscription.cancel();
    _addressService.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses(String clientId) async {
    _loadedForClientId = clientId;
    try {
      final addresses = await _addressService.getAddresses(clientId);
      if (mounted && _loadedForClientId == clientId) {
        setState(() => _savedAddresses = addresses);
      }
    } catch (_) {
      _loadedForClientId = null;
    }
  }

  void _scheduleFromCheck(String address, {bool immediate = false}) {
    _fromDebounce?.cancel();
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fromReachability = null;
        _fromCheckedAddress = null;
      });
      return;
    }
    if (trimmed == _fromCheckedAddress) return;
    void run() => _fetchSuggestionsAndCheck(trimmed, isFrom: true);

    if (immediate) {
      run();
    } else {
      _fromDebounce = Timer(_debounce, run);
    }
  }

  void _scheduleToCheck(String address, {bool immediate = false}) {
    _toDebounce?.cancel();
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _toReachability = null;
        _toCheckedAddress = null;
      });
      return;
    }
    if (trimmed == _toCheckedAddress) return;
    void run() => _fetchSuggestionsAndCheck(trimmed, isFrom: false);

    if (immediate) {
      run();
    } else {
      _toDebounce = Timer(_debounce, run);
    }
  }

  /// Single network round-trip per input pause: fetches Mapbox suggestions (with
  /// coordinates) for [query], merges them into the field's suggestion list AND
  /// classifies service-zone reachability from the same response — no second
  /// forward-geocode. Falls back to [reachabilityResolver] only when no
  /// suggestion carried coordinates. Stale responses (the user has since edited
  /// the field) are dropped.
  Future<void> _fetchSuggestionsAndCheck(
    String query, {
    required bool isFrom,
  }) async {
    final List<AddressSuggestion> suggestions;
    try {
      suggestions = await widget.addressSuggester(query);
    } catch (_) {
      // Suggestions are best-effort. Still try the fallback reachability check
      // so an out-of-area warning isn't lost when the suggester fails.
      await _runCheck(query, isFrom: isFrom);
      return;
    }
    if (!mounted) return;
    final current = isFrom
        ? _formBloc.state.fromAddress.trim()
        : _formBloc.state.toAddress.trim();
    if (current != query) return;

    // Merge order: saved places first, then locally-cached recents, then live
    // Mapbox results — deduped by normalized address. Recents stay in the list
    // once live results arrive (the field's own substring filter picks the ones
    // matching the query), so a frequently-used address isn't dropped just
    // because Mapbox's top-5 didn't include it.
    final seen = <String>{};
    final merged = <ClientAddress>[];
    for (final a in [..._savedAddresses, ..._recentAddresses]) {
      if (seen.add(a.address.trim().toLowerCase())) merged.add(a);
    }
    for (final s in suggestions) {
      if (seen.add(s.address.trim().toLowerCase())) {
        merged.add(
          ClientAddress(
            id: '',
            clientId: _loadedForClientId ?? '',
            label: '',
            address: s.address,
            latitude: s.latitude,
            longitude: s.longitude,
            useCount: 0,
            createdAt: _epoch,
            updatedAt: _epoch,
          ),
        );
      }
    }

    // Classify the suggestion whose address matches the typed text (so a partial
    // query doesn't misreport a different top hit), else the top suggestion.
    final match = _bestMatch(query, suggestions);
    ReachabilityResult? result;
    if (match != null && match.latitude != null && match.longitude != null) {
      result = ServiceZone.classify(match.latitude, match.longitude);
    }

    setState(() {
      if (isFrom) {
        _fromSuggestions = merged;
      } else {
        _toSuggestions = merged;
      }
      if (result != null) {
        if (isFrom) {
          _fromReachability = result;
          _fromCheckedAddress = query;
        } else {
          _toReachability = result;
          _toCheckedAddress = query;
        }
      }
    });

    // No suggestion carried coordinates (e.g. an empty result set): fall back to
    // the direct geocode so an out-of-area/not-found warning still appears.
    if (result == null) {
      await _runCheck(query, isFrom: isFrom);
    }
  }

  /// The suggestion whose address case-insensitively equals [query], or the
  /// first suggestion when none matches exactly, or null when empty.
  AddressSuggestion? _bestMatch(
    String query,
    List<AddressSuggestion> suggestions,
  ) {
    if (suggestions.isEmpty) return null;
    final key = query.trim().toLowerCase();
    for (final s in suggestions) {
      if (s.address.trim().toLowerCase() == key) return s;
    }
    return suggestions.first;
  }

  Future<void> _runCheck(String address, {required bool isFrom}) async {
    final result = await widget.reachabilityResolver(address);
    if (!mounted) return;
    // Drop the result if the user has since changed this field.
    final current = isFrom
        ? _formBloc.state.fromAddress.trim()
        : _formBloc.state.toAddress.trim();
    if (current != address) return;
    setState(() {
      if (isFrom) {
        _fromReachability = result;
        _fromCheckedAddress = address;
      } else {
        _toReachability = result;
        _toCheckedAddress = address;
      }
    });
  }

  /// The suggestion list handed to a field. Once live Mapbox suggestions exist
  /// they already include the saved-places merge, so use them as-is. Before then
  /// (a short/empty query the live suggester ignores, or offline) fall back to
  /// saved places plus locally-cached recents so the dropdown is never empty.
  List<ClientAddress> _suggestionsOrFallback(List<ClientAddress> live) {
    if (live.isNotEmpty) return live;
    final seen = <String>{};
    final merged = <ClientAddress>[];
    for (final a in [..._savedAddresses, ..._recentAddresses]) {
      if (seen.add(a.address.trim().toLowerCase())) merged.add(a);
    }
    return merged;
  }

  /// Inline advisory message for a reachability result, or null when the address
  /// is reachable / not yet checked. Never blocks submission.
  String? _warningFor(ReachabilityResult? result, AppLocalizations l10n) {
    if (result == null) return null;
    switch (result.status) {
      case Reachability.reachable:
        return null;
      case Reachability.notFound:
        return l10n.addressNotFound;
      case Reachability.outOfArea:
        final radius = ServiceZone.radiusKm.round();
        final distance = result.distanceKm?.round();
        return distance == null
            ? l10n.addressOutOfServiceAreaShort(radius)
            : l10n.addressOutOfServiceArea(distance, radius);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<CreateRideFormBloc, CreateRideFormState>(
      buildWhen: (prev, curr) =>
          prev.fromAddress != curr.fromAddress ||
          prev.toAddress != curr.toAddress ||
          prev.isAirportTransfer != curr.isAirportTransfer ||
          prev.isArrival != curr.isArrival,
      builder: (context, state) {
        final fromWarning = _warningFor(_fromReachability, l10n);
        final toWarning = _warningFor(_toReachability, l10n);
        // When the airport transfer is active, the airport endpoint is
        // auto-filled and shown as a read-only chip (arrival → From, departure
        // → To); the operator only edits the other endpoint.
        final fromIsAirport = state.isAirportTransfer && state.isArrival;
        final toIsAirport = state.isAirportTransfer && !state.isArrival;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.formCardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppColors.successStrong,
                      size: 24,
                    ),
                    const SizedBox(width: AppDimensions.paddingSmall),
                    const Text(
                      'Ride Locations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.formSectionGap),
                if (fromIsAirport)
                  _AirportLocationChip(
                    labelText: 'From',
                    airportLabel: state.fromAddress,
                  )
                else ...[
                  AddressAutocompleteField(
                    labelText: 'From',
                    hintText: 'Pick-up location',
                    prefixIconData: Icons.trip_origin,
                    initialValue: state.fromAddress,
                    suggestions: _suggestionsOrFallback(_fromSuggestions),
                    excludeAddress: state.toAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Pick-up location is required';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      context.read<CreateRideFormBloc>().add(
                        FromAddressChanged(value),
                      );
                      _scheduleFromCheck(value);
                    },
                  ),
                  if (fromWarning != null)
                    _AddressWarning(message: fromWarning),
                ],
                const SizedBox(height: AppDimensions.paddingSmall),
                // The swap button is hidden during an airport transfer: the
                // airport endpoint is fixed by the arrival/departure direction,
                // which is changed via the arrival/departure radio, not by
                // swapping From/To.
                if (!state.isAirportTransfer)
                  Center(
                    child: IconButton(
                      onPressed: () {
                        // Drop focus first so both address fields re-sync their
                        // text from the swapped state. AddressAutocompleteField
                        // skips the controller sync while focused, so without
                        // this the focused field would keep its stale text and
                        // the swap would look like it did nothing.
                        FocusScope.of(context).unfocus();
                        context.read<CreateRideFormBloc>().add(
                          const AddressesSwapped(),
                        );
                        // Re-evaluate both fields against the swapped values.
                        _scheduleFromCheck(
                          _formBloc.state.toAddress,
                          immediate: true,
                        );
                        _scheduleToCheck(
                          _formBloc.state.fromAddress,
                          immediate: true,
                        );
                      },
                      icon: const Icon(Icons.swap_vert),
                      tooltip: 'Swap From / To',
                      style: IconButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (!state.isAirportTransfer)
                  const SizedBox(height: AppDimensions.paddingSmall),
                if (toIsAirport)
                  _AirportLocationChip(
                    labelText: 'To',
                    airportLabel: state.toAddress,
                  )
                else ...[
                  AddressAutocompleteField(
                    labelText: 'To',
                    hintText: 'Drop-off location',
                    prefixIconData: Icons.location_on,
                    initialValue: state.toAddress,
                    suggestions: _suggestionsOrFallback(_toSuggestions),
                    excludeAddress: state.fromAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Drop-off location is required';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      context.read<CreateRideFormBloc>().add(
                        ToAddressChanged(value),
                      );
                      _scheduleToCheck(value);
                    },
                  ),
                  if (toWarning != null) _AddressWarning(message: toWarning),
                ],
                if (state.fromAddress.trim().isNotEmpty &&
                    state.toAddress.trim().isNotEmpty &&
                    state.fromAddress.trim().toLowerCase() ==
                        state.toAddress.trim().toLowerCase())
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.paddingSmall / 2,
                    ),
                    child: Text(
                      'Pick-up and drop-off cannot be the same address.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Inline advisory warning shown under an address field. Uses a warning (amber)
/// tone, not the error color, because reachability is non-blocking.
class _AddressWarning extends StatelessWidget {
  final String message;

  const _AddressWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingSmall / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: AppColors.warningStrong,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: AppColors.warningStrong),
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only chip shown in place of an address field when an airport transfer
/// fixes that endpoint to the airport. The operator cannot edit it; it only
/// signals that the airport address was auto-filled. For a known catalog
/// airport it shows the short label (e.g. "Flughafen München (MUC)"); for a
/// legacy ride with a differently-worded saved address it falls back to that
/// saved text.
class _AirportLocationChip extends StatelessWidget {
  final String labelText;
  final String airportLabel;

  const _AirportLocationChip({
    required this.labelText,
    required this.airportLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = isCatalogAirportAddress(airportLabel)
        ? defaultAirport.label
        : airportLabel;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(Icons.flight, color: scheme.primary),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
      ),
      child: Text(
        display,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
