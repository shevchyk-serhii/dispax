import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

/// Full-screen, non-dismissable gate shown at startup when this client build is
/// older than the backend's `minClientVersion` (see [isClientOutdated]). It
/// mirrors the blocking mechanism of ForcePasswordChangeScreen — no back button
/// — but sits OUTSIDE the auth flow (the user may be too old to even log in), so
/// the only action is to open the app store and update.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  // App identifiers. The Android package id is stable; the iOS App Store numeric
  // id is not yet known (the app is in App Store review) — TODO: replace the
  // placeholder once the listing is live, then the itms-apps deep link resolves.
  static const String _androidPackage = 'de.dispax.app';
  static const String _iosAppStoreId = '0000000000'; // TODO: real App Store id

  Future<void> _openStore() async {
    final Uri uri;
    if (kIsWeb) {
      uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_androidPackage',
      );
    } else if (Platform.isIOS) {
      uri = Uri.parse('https://apps.apple.com/app/id$_iosAppStoreId');
    } else {
      // Android (and anything else): the market: scheme opens the Play Store app
      // directly; url_launcher falls through to the browser if it is absent.
      uri = Uri.parse('market://details?id=$_androidPackage');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.updateRequired),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.updateRequired,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.updateRequiredMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.updateNow),
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
