import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/blocs.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../address_autocomplete_field.dart';
import '../../models/client_address.dart';
import '../../services/client_address_service.dart';
import '../../../core/services/mapbox_service.dart';
import '../../../core/utils/service_zone.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_dimensions.dart';

/// Resolves how reachable an address is (geocode + service-zone check). Injected
/// so widget tests can supply a deterministic result without hitting Mapbox.
typedef ReachabilityResolver =
    Future<ReachabilityResult> Function(String address);

/// Returns address suggestions for a typed query. Injected so widget tests can
/// supply deterministic suggestions without hitting Mapbox.
typedef AddressSuggester = Future<List<String>> Function(String query);

class CreateRideLocationSection extends StatefulWidget {
  /// Defaults to the real Mapbox-backed check; overridden in tests.
  final ReachabilityResolver reachabilityResolver;

  /// Defaults to the real Mapbox-backed suggester; overridden in tests.
  final AddressSuggester addressSuggester;

  const CreateRideLocationSection({
    super.key,
    this.reachabilityResolver = ServiceZone.reachabilityOf,
    this.addressSuggester = MapboxService.suggestAddresses,
  });

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
    void run() {
      _runCheck(trimmed, isFrom: true);
      _fetchSuggestions(trimmed, isFrom: true);
    }

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
    void run() {
      _runCheck(trimmed, isFrom: false);
      _fetchSuggestions(trimmed, isFrom: false);
    }

    if (immediate) {
      run();
    } else {
      _toDebounce = Timer(_debounce, run);
    }
  }

  /// Fetches Mapbox suggestions for [query] and merges them (saved places first,
  /// then Mapbox, deduped by normalized address) into the field's suggestion
  /// list. Stale responses for an address the user has since edited are dropped.
  Future<void> _fetchSuggestions(String query, {required bool isFrom}) async {
    final List<String> mapbox;
    try {
      mapbox = await widget.addressSuggester(query);
    } catch (_) {
      return; // suggestions are best-effort; ignore failures
    }
    if (!mounted) return;
    final current = isFrom
        ? _formBloc.state.fromAddress.trim()
        : _formBloc.state.toAddress.trim();
    if (current != query) return;

    final seen = <String>{};
    final merged = <ClientAddress>[];
    for (final saved in _savedAddresses) {
      if (seen.add(saved.address.trim().toLowerCase())) merged.add(saved);
    }
    for (final name in mapbox) {
      if (seen.add(name.trim().toLowerCase())) {
        merged.add(
          ClientAddress(
            id: '',
            clientId: _loadedForClientId ?? '',
            label: '',
            address: name,
            useCount: 0,
            createdAt: _epoch,
            updatedAt: _epoch,
          ),
        );
      }
    }
    setState(() {
      if (isFrom) {
        _fromSuggestions = merged;
      } else {
        _toSuggestions = merged;
      }
    });
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
          prev.toAddress != curr.toAddress,
      builder: (context, state) {
        final fromWarning = _warningFor(_fromReachability, l10n);
        final toWarning = _warningFor(_toReachability, l10n);
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
                AddressAutocompleteField(
                  labelText: 'From',
                  hintText: 'Pick-up location',
                  prefixIconData: Icons.trip_origin,
                  initialValue: state.fromAddress,
                  suggestions: _fromSuggestions.isEmpty
                      ? _savedAddresses
                      : _fromSuggestions,
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
                if (fromWarning != null) _AddressWarning(message: fromWarning),
                const SizedBox(height: AppDimensions.paddingSmall),
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
                const SizedBox(height: AppDimensions.paddingSmall),
                AddressAutocompleteField(
                  labelText: 'To',
                  hintText: 'Drop-off location',
                  prefixIconData: Icons.location_on,
                  initialValue: state.toAddress,
                  suggestions: _toSuggestions.isEmpty
                      ? _savedAddresses
                      : _toSuggestions,
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
