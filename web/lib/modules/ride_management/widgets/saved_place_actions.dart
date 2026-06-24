import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/saved_places/saved_places_bloc.dart';
import '../../../blocs/saved_places/saved_places_event.dart';
import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../models/client_address.dart';
import '../../core/services/mapbox_service.dart';
import 'address_picker_sheet.dart';

/// Opens the action menu for a filled saved place [place]: Use this address,
/// Edit address, or Remove. Reused by the client home saved-place slots and
/// the (later) "My addresses" management screens.
///
/// Requires a [SavedPlacesBloc] above [context]: Edit/Remove dispatch events on
/// it. [clientId] scopes those mutations; [onUse] runs the "use this" action
/// (e.g. navigate to the booking tab).
Future<void> showSavedPlaceActions(
  BuildContext context, {
  required ClientAddress place,
  required String clientId,
  required VoidCallback onUse,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final bloc = context.read<SavedPlacesBloc>();

  final action = await showModalBottomSheet<_PlaceAction>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.navigation_outlined),
            title: Text(l10n.useThisAddress),
            onTap: () => Navigator.pop(ctx, _PlaceAction.use),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.editAddress),
            onTap: () => Navigator.pop(ctx, _PlaceAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.error),
            title: Text(
              l10n.removeAddress,
              style: const TextStyle(color: AppColors.error),
            ),
            onTap: () => Navigator.pop(ctx, _PlaceAction.remove),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _PlaceAction.use:
      onUse();
    case _PlaceAction.edit:
      await _editPlace(context, bloc: bloc, place: place, clientId: clientId);
    case _PlaceAction.remove:
      await _removePlace(context, bloc: bloc, place: place, clientId: clientId);
  }
}

/// Opens the address picker prefilled with [place.address]. On a new address,
/// replaces the saved place: the PATCH endpoint only renames the label, so an
/// address change is a delete-then-save under the same label (otherwise the old
/// row would be orphaned).
Future<void> _editPlace(
  BuildContext context, {
  required SavedPlacesBloc bloc,
  required ClientAddress place,
  required String clientId,
}) async {
  final existing = bloc.state.places
      .map((p) => p.address)
      .where((a) => a.isNotEmpty)
      .toList();

  final newAddress = await showAddressPickerSheet(
    context,
    isFrom: false,
    current: place.address,
    savedPlaces: existing,
  );
  if (newAddress == null || newAddress.isEmpty || newAddress == place.address) {
    return;
  }

  // Best-effort geocoding — coordinates are optional on the backend DTO.
  final coords = await MapboxService.geocodeAddress(newAddress);

  bloc.add(SavedPlacesDeleteRequested(clientId: clientId, addressId: place.id));
  bloc.add(
    SavedPlacesSaveRequested(
      clientId: clientId,
      label: place.label,
      address: newAddress,
      latitude: coords != null && coords.length == 2 ? coords[0] : null,
      longitude: coords != null && coords.length == 2 ? coords[1] : null,
    ),
  );
}

/// Confirms then deletes the saved place [place].
Future<void> _removePlace(
  BuildContext context, {
  required SavedPlacesBloc bloc,
  required ClientAddress place,
  required String clientId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.removeAddress),
      content: Text(l10n.removeAddressConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(l10n.removeAddress),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  bloc.add(SavedPlacesDeleteRequested(clientId: clientId, addressId: place.id));
}

/// Prompts for a free-form, non-empty label and then the address, and saves a
/// new custom saved place for [clientId]. Requires a [SavedPlacesBloc] above
/// [context]. No-op if the user cancels either step.
Future<void> showAddSavedPlaceFlow(
  BuildContext context, {
  required String clientId,
}) async {
  final bloc = context.read<SavedPlacesBloc>();
  final label = await promptPlaceLabel(context);
  if (label == null || label.isEmpty || !context.mounted) return;

  final existing = bloc.state.places
      .map((p) => p.address)
      .where((a) => a.isNotEmpty)
      .toList();

  final address = await showAddressPickerSheet(
    context,
    isFrom: false,
    current: '',
    savedPlaces: existing,
  );
  if (address == null || address.isEmpty) return;

  final coords = await MapboxService.geocodeAddress(address);

  bloc.add(
    SavedPlacesSaveRequested(
      clientId: clientId,
      label: label,
      address: address,
      latitude: coords != null && coords.length == 2 ? coords[0] : null,
      longitude: coords != null && coords.length == 2 ? coords[1] : null,
    ),
  );
}

/// Dialog asking for a non-empty custom label. Returns the trimmed label or
/// null if cancelled.
Future<String?> promptPlaceLabel(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showAdaptiveDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.addCustomAddress),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.addressLabel,
            hintText: l10n.addressLabelHint,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? l10n.labelRequired : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(ctx).pop(controller.text.trim());
            }
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}

enum _PlaceAction { use, edit, remove }
