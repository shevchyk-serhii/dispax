import 'package:flutter/material.dart';

import '../modules/core/api_contract.dart';
import '../modules/core/services/api_client.dart';
import '../modules/core/services/version_service.dart';
import 'force_update_screen.dart';

/// Startup gate that force-updates a client older than the backend allows.
///
/// On first build it fetches the public `GET /api/version` once and compares
/// [kClientApiVersion] against the backend's `minClientVersion`. If the client
/// is too old it shows the blocking [ForceUpdateScreen]; otherwise it renders
/// [child] (the normal app).
///
/// Fail-open by design: while the check is in flight, or if it fails (backend
/// unreachable / timeout / non-200), [child] is shown. We block ONLY on a
/// successful response that says the client is outdated — a backend hiccup must
/// never brick every client at once.
class ForceUpdateGate extends StatefulWidget {
  final Widget child;

  /// Injectable for tests; in production a fresh, token-less [ApiClient] is used
  /// since `/api/version` is public and the gate runs before login.
  final ApiClient? apiClient;

  const ForceUpdateGate({super.key, required this.child, this.apiClient});

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  bool _outdated = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final backend = await VersionService(
        apiClient: widget.apiClient ?? ApiClient(),
      ).fetchBackendVersion();
      if (!mounted) return;
      if (isClientOutdated(kClientApiVersion, backend.minClientVersion)) {
        setState(() => _outdated = true);
      }
    } catch (_) {
      // Fail-open: backend unreachable / error → let the user into the app.
    }
  }

  @override
  Widget build(BuildContext context) =>
      _outdated ? const ForceUpdateScreen() : widget.child;
}
