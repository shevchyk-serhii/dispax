import 'dart:async';

import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../core/services/mapbox_service.dart';
import '../models/client_address.dart';

/// Opens the Mapbox-backed address picker bottom sheet and returns the
/// selected address string (or null if dismissed).
///
/// Reused both by the booking flow (pick-up / drop-off) and by the client
/// home screen saved-places cards.
///
/// [savedAddresses] (optional) renders a labelled quick-pick section (Home /
/// Office / Airport / custom) at the top for one-tap selection. The flat
/// [savedPlaces] list is kept for backwards compatibility with call sites that
/// only have plain address strings.
Future<String?> showAddressPickerSheet(
  BuildContext context, {
  required bool isFrom,
  required String current,
  required List<String> savedPlaces,
  List<ClientAddress> savedAddresses = const [],
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => AddressPickerSheet(
      isFrom: isFrom,
      current: current,
      savedPlaces: savedPlaces,
      savedAddresses: savedAddresses,
    ),
  );
}

/// Bottom sheet with a live Mapbox address search plus the user's saved
/// places. Pops the chosen address string via [Navigator.pop].
class AddressPickerSheet extends StatefulWidget {
  final bool isFrom;
  final String current;
  final List<String> savedPlaces;
  final List<ClientAddress> savedAddresses;

  const AddressPickerSheet({
    super.key,
    required this.isFrom,
    required this.current,
    required this.savedPlaces,
    this.savedAddresses = const [],
  });

  @override
  State<AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<AddressPickerSheet> {
  late TextEditingController _ctrl;
  Timer? _debounce;
  List<String> _suggestions = const [];
  bool _loading = false;
  // Guards against a stale in-flight suggest call overwriting newer results:
  // each keystroke bumps this and only the latest query is allowed to commit.
  int _querySeq = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final seq = ++_querySeq;
    final trimmed = value.trim();

    if (trimmed.length < 3) {
      setState(() {
        _suggestions = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await MapboxService.suggestAddresses(trimmed);
      // Drop the response if the user kept typing or closed the sheet.
      if (!mounted || seq != _querySeq) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // The sheet height is made keyboard-aware: we reserve the keyboard inset
    // via the outer Padding AND cap the content to 90% of the *visible* (above
    // the keyboard) height. This keeps the search field, the results list and
    // the Confirm button sharing the space above the keyboard, so the list does
    // not collapse to a single row. (A previous attempt wrapped a full-height
    // DraggableScrollableSheet in this padding, which double-counted the inset
    // and overflowed by a few pixels — that's why the cap below is required.)
    final screenHeight = MediaQuery.of(context).size.height;
    // Clamp the inset to the screen height so an over-large reported keyboard
    // (or test geometry) can't drive the sheet height negative and trip a
    // BoxConstraints assertion, nor push the bottom padding past the screen.
    final keyboardInset = MediaQuery.of(
      context,
    ).viewInsets.bottom.clamp(0.0, screenHeight);
    // Height available above the keyboard, capped at 90% of it.
    final maxSheetHeight = (screenHeight - keyboardInset) * 0.9;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.isFrom
                      ? 'Enter pick-up address'
                      : 'Enter drop-off address',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.borderPrimary,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: _onQueryChanged,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
                },
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (_suggestions.isNotEmpty) ...[
                    _sectionLabel('Suggestions'),
                    ..._suggestions.map(
                      (s) => ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.accent,
                        ),
                        title: Text(s),
                        onTap: () => Navigator.of(context).pop(s),
                      ),
                    ),
                  ],
                  if (widget.savedAddresses.isNotEmpty) ...[
                    _sectionLabel('Saved places'),
                    ...widget.savedAddresses.map(
                      (a) => ListTile(
                        leading: Icon(
                          _iconForLabel(a.label),
                          color: AppColors.accent,
                        ),
                        title: Text(a.label),
                        subtitle: Text(
                          a.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(a.address),
                      ),
                    ),
                  ] else if (widget.savedPlaces.isNotEmpty) ...[
                    _sectionLabel('Saved places'),
                    ...widget.savedPlaces.map(
                      (p) => ListTile(
                        leading: const Icon(
                          Icons.bookmark_outline,
                          color: AppColors.accent,
                        ),
                        title: Text(p),
                        onTap: () => Navigator.of(context).pop(p),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              // Keyboard inset is reserved by the outer Padding, so the button
              // only needs its own bottom margin here (no double counting).
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: Builder(
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return ElevatedButton(
                      onPressed: () {
                        final v = _ctrl.text.trim();
                        if (v.isNotEmpty) Navigator.of(context).pop(v);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirm'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'office':
        return Icons.business_outlined;
      case 'airport':
        return Icons.flight_outlined;
      default:
        return Icons.bookmark_outline;
    }
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
        ),
      ),
    ),
  );
}
