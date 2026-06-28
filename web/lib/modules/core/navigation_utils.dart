import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'navigation_helper.dart';
import 'models/location.dart';
import 'models/person.dart';
import '../ride_management/models/ride.dart';
import '../ride_management/services/ride_service.dart';
import '../ride_management/helpers/tag_helpers.dart';
import '../ride_management/widgets/tag_input_field.dart';
import '../../blocs/blocs.dart';
import '../../constants/app_colors.dart';
import '../../screens/ride_details_screen.dart';

class NavigationUtils {
  /// Shows the "Navigate to" picker (pickup / drop-off) and opens Google Maps
  /// for the chosen leg.
  ///
  /// On iOS [showAdaptiveDialog] renders a Cupertino-style dialog whose barrier
  /// is NOT dismissible by tapping outside, so the dialog must offer an explicit
  /// exit. The third "Cancel" option provides that exit on every platform;
  /// without it the driver would be trapped in the dialog on iOS.
  static Future<void> showNavigateToDialog(
    BuildContext context,
    Ride ride,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final choice = await showAdaptiveDialog<String>(
        context: context,
        barrierDismissible: true, // helps on Android/web; ignored by Cupertino
        builder: (BuildContext ctx) => SimpleDialog(
          title: Text(l10n.navigateTo),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop('pickup'),
              child: ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: AppColors.success,
                ),
                title: Text(ride.from.address),
                subtitle: Text(l10n.googleMapsPickup),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop('destination'),
              child: ListTile(
                leading: const Icon(Icons.flag, color: AppColors.error),
                title: Text(ride.to.address),
                subtitle: Text(l10n.googleMapsDropoff),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(),
              child: ListTile(
                leading: const Icon(Icons.close),
                title: Text(l10n.cancel),
              ),
            ),
          ],
        ),
      );

      if (choice == null || !context.mounted) return;

      final destination = choice == 'pickup' ? ride.from : ride.to;
      await openGoogleMapsNavigation(destination);

      if (context.mounted) {
        NavigationHelper.showSnackBar(context, l10n.openingNavigation);
      }
    } catch (e) {
      if (context.mounted) {
        NavigationHelper.showSnackBar(
          context,
          l10n.couldNotOpenNavigation(e.toString()),
          isError: true,
        );
      }
    }
  }

  static Future<void> openGoogleMapsNavigation(Location destination) async {
    final destinationAddress = Uri.encodeComponent(destination.address);

    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=$destinationAddress&travelmode=driving';

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      await _tryGoogleMapsApp(destination);
    }
  }

  static Future<void> openGoogleMapsRoute(
    Location origin,
    Location destination,
  ) async {
    final originParam = origin.latitude != null && origin.longitude != null
        ? '${origin.latitude},${origin.longitude}'
        : Uri.encodeComponent(origin.address);
    final destinationParam =
        destination.latitude != null && destination.longitude != null
        ? '${destination.latitude},${destination.longitude}'
        : Uri.encodeComponent(destination.address);

    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$originParam&destination=$destinationParam&travelmode=driving';

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      await _tryGoogleMapsAppWithRoute(origin, destination);
    }
  }

  static Future<void> _tryGoogleMapsApp(Location destination) async {
    final destinationAddress = Uri.encodeComponent(destination.address);

    final appUrl =
        'comgooglemaps://?daddr=$destinationAddress&directionsmode=driving';

    try {
      final Uri uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Google Maps app not found';
      }
    } catch (e) {
      throw 'Could not open navigation: $e';
    }
  }

  static Future<void> _tryGoogleMapsAppWithRoute(
    Location origin,
    Location destination,
  ) async {
    final originParam = origin.latitude != null && origin.longitude != null
        ? '${origin.latitude},${origin.longitude}'
        : Uri.encodeComponent(origin.address);
    final destinationParam =
        destination.latitude != null && destination.longitude != null
        ? '${destination.latitude},${destination.longitude}'
        : Uri.encodeComponent(destination.address);

    final appUrl =
        'comgooglemaps://?saddr=$originParam&daddr=$destinationParam&directionsmode=driving';

    try {
      final Uri uri = Uri.parse(appUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Google Maps app not found';
      }
    } catch (e) {
      throw 'Could not open navigation: $e';
    }
  }

  static Future<void> openGoogleMapsLocation(Location location) async {
    final address = Uri.encodeComponent(location.address);

    String googleMapsUrl;
    if (location.latitude != null && location.longitude != null) {
      googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
    } else {
      googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$address';
    }

    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Google Maps';
      }
    } catch (e) {
      throw 'Could not open location: $e';
    }
  }

  static Future<Ride?> navigateToEditRide(
    BuildContext context,
    Ride ride,
  ) async {
    return showAdaptiveDialog<Ride>(
      context: context,
      builder: (ctx) => _EditRideDialog(ride: ride),
    );
  }

  static Future<Person?> navigateToDriverSelection(BuildContext context) async {
    // Driver selection is now handled by the dispatcher dashboard's
    // tap-to-assign flow (pending_rides_panel.dart _showDriverSelectionSheet)
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.useDispatcherDashboardInfo)));
    return null;
  }

  static Future<void> navigateToMap(BuildContext context, Ride ride) async {
    await openGoogleMapsRoute(ride.from, ride.to);
  }

  /// Opens the full ride details screen. Used by the driver's Today cards (the
  /// live/next cards have no other entry into details, which is where the
  /// "Share" tracking-link button lives).
  static Future<void> navigateToRideDetails(
    BuildContext context,
    Ride ride,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RideDetailsScreen(ride: ride)),
    );
  }

  /// Creates (or reuses) a public guest tracking link for [ride] and copies it
  /// to the clipboard, showing a localized success/error snackbar. Shared by the
  /// ride details screen and the driver's Today card so the share behaviour
  /// stays identical everywhere.
  static Future<void> shareRide(BuildContext context, Ride ride) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final rideService = RideService(
      apiClient: context.read<AuthBloc>().apiClient,
    );
    try {
      final url = await rideService.createShareLink(ride.id);
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(SnackBar(content: Text(l10n.trackingLinkCopied)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _EditRideDialog extends StatefulWidget {
  final Ride ride;
  const _EditRideDialog({required this.ride});

  @override
  State<_EditRideDialog> createState() => _EditRideDialogState();
}

class _EditRideDialogState extends State<_EditRideDialog> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _flightCtrl;
  late List<String> _tags;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.ride.from.address);
    _toCtrl = TextEditingController(text: widget.ride.to.address);
    _dateCtrl = TextEditingController(
      text: DateFormat("yyyy-MM-dd'T'HH:mm").format(widget.ride.pickupDateTime),
    );
    _notesCtrl = TextEditingController(text: widget.ride.notes ?? '');
    _flightCtrl = TextEditingController(text: widget.ride.flightNumber ?? '');
    _tags = List<String>.from(widget.ride.tags);
  }

  void _addTag(String raw) {
    final tag = normalizeTag(raw);
    if (tag.isEmpty) return;
    if (_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) return;
    setState(() => _tags = [..._tags, tag]);
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _dateCtrl.dispose();
    _notesCtrl.dispose();
    _flightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final l10n = AppLocalizations.of(context)!;
    final apiClient = context.read<AuthBloc>().apiClient;
    // Parse local time and convert to UTC ISO-8601 for the backend
    DateTime localDt;
    try {
      localDt = DateFormat(
        "yyyy-MM-dd'T'HH:mm",
      ).parseStrict(_dateCtrl.text.trim());
    } catch (_) {
      setState(() {
        _error = l10n.invalidDateFormatError;
        _saving = false;
      });
      return;
    }
    final utcIso = localDt.toUtc().toIso8601String();

    final body = <String, dynamic>{
      'from': {'address': _fromCtrl.text.trim()},
      'to': {'address': _toCtrl.text.trim()},
      'pickupDateTime': utcIso,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      if (_flightCtrl.text.trim().isNotEmpty)
        'flightNumber': _flightCtrl.text.trim(),
      // Always send tags (even empty) so clearing all tags persists — the
      // backend treats an absent field as "leave unchanged".
      'tags': _tags,
    };

    try {
      final response = await apiClient.put('/rides/${widget.ride.id}', body);
      if (response.statusCode == 200) {
        final updated = Ride.fromJson(jsonDecode(response.body));
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        setState(() {
          _error = l10n.serverErrorMessage(response.statusCode.toString());
          _saving = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = _error;
    return AlertDialog(
      title: Text(l10n.editRideDialogTitle),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _fromCtrl,
                decoration: InputDecoration(
                  labelText: l10n.fromLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _toCtrl,
                decoration: InputDecoration(
                  labelText: l10n.toLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dateCtrl,
                decoration: InputDecoration(
                  labelText: l10n.pickupDateTimeLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _flightCtrl,
                decoration: InputDecoration(
                  labelText: l10n.flightNumberOptionalLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: l10n.notesOptionalLabel,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TagInputField(
                  tags: _tags,
                  onAdded: _addTag,
                  onRemoved: _removeTag,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
