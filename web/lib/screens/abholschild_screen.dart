import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../l10n/app_localizations.dart';

/// "Abholschild" (pickup sign) — lets a driver or dispatcher show an arbitrary
/// piece of text (usually a passenger's name) as a large sign on a white screen,
/// e.g. when meeting someone at the airport.
///
/// Two modes:
///  - editor: a text field pre-filled with the last shown text + a "Show" button;
///  - display: a full-screen white board with the text auto-scaled to fit, black
///    on white, dark status-bar icons. The screen is kept awake ONLY while the
///    board is shown (wakelock enabled on entry, disabled on exit), so the sign
///    never dims mid-pickup and the wakelock can't leak back into the app.
///
/// The last text is persisted in SharedPreferences so re-opening the screen
/// restores it.
class AbholschildScreen extends StatefulWidget {
  const AbholschildScreen({super.key});

  /// Persistence key for the last shown sign text.
  static const String prefsKey = 'abholschild_last_text';

  @override
  State<AbholschildScreen> createState() => _AbholschildScreenState();
}

class _AbholschildScreenState extends State<AbholschildScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLastText();
  }

  Future<void> _loadLastText() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(AbholschildScreen.prefsKey);
    if (!mounted || last == null || last.isEmpty) return;
    setState(() => _controller.text = last);
  }

  Future<void> _persist(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AbholschildScreen.prefsKey, text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _persist(text);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _SignBoard(text: text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickupSignTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.pickupSignHint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _show(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _show,
                icon: const Icon(Icons.fullscreen),
                label: Text(l10n.pickupSignShowButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen white board rendering [text] auto-scaled to fill the screen.
/// Keeps the screen awake for its whole lifetime (wakelock enabled in initState,
/// disabled in dispose — so it is bound exactly to this route being on screen).
class _SignBoard extends StatefulWidget {
  final String text;

  const _SignBoard({required this.text});

  @override
  State<_SignBoard> createState() => _SignBoardState();
}

class _SignBoardState extends State<_SignBoard> {
  @override
  void initState() {
    super.initState();
    // Best-effort: keeping the screen awake must never crash the sign.
    WakelockPlus.enable().ignore();
  }

  @override
  void dispose() {
    WakelockPlus.disable().ignore();
    super.dispose();
  }

  // Pop this board back to the editor. `pop()` (not `maybePop()`) because we
  // pushed this route ourselves and there is no PopScope in the tree — pop is
  // strictly more reliable and leaves no doubt the exit fires.
  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White background → dark status-bar icons (the app's usual `.light` is for
      // its dark headers, which would be invisible here).
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        // Swipe down anywhere to dismiss — the exit gesture the user expects.
        // A VERTICAL drag is deliberate: `onHorizontalDragEnd` would compete
        // with (and disable) the native iOS edge-swipe-back on this
        // MaterialPageRoute, whereas a downward fling does not.
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 200) _close();
          },
          child: SafeArea(
            child: Stack(
              children: [
                // Tap anywhere to go back to the editor (secondary affordance).
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      // SizedBox.expand gives the FittedBox TIGHT constraints so
                      // it scales the text UP to fill the area. A plain Center
                      // would pass loose constraints, leaving the text at its
                      // natural (~14px) size — the "tiny text" bug. FittedBox
                      // centers its own scaled child, so no extra Center needed.
                      child: SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Text(
                            widget.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Prominent, always-visible close button — the guaranteed exit
                // that does not depend on tap-anywhere firing. A faint circular
                // scrim makes the dark icon read on the white board, and the
                // 48px IconButton is a comfortable touch target.
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black12,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      iconSize: 28,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonLabel,
                      icon: const Icon(Icons.close, color: Colors.black87),
                      onPressed: _close,
                    ),
                  ),
                ),
                // Discoverability hint: tell the user how to leave the board.
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Text(
                    l10n.pickupSignCloseHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
