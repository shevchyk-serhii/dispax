import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/api_client.dart';

/// A circular avatar widget that:
/// - Shows the person's profile photo (fetched via authenticated [apiClient]) when available.
/// - Falls back to initials in a gradient circle when no photo is set or while loading.
///
/// Because GET /api/users/{id}/avatar requires a Bearer token, we cannot use
/// [NetworkImage]. Instead, bytes are fetched via [ApiClient.getBytes] and
/// rendered with [Image.memory].
///
/// The widget is [StatefulWidget] to ensure the HTTP request is created once in
/// [initState] / [didUpdateWidget] rather than on every [build] call. A new
/// request is issued only when [user.id] changes or [user.hasAvatar] changes,
/// avoiding redundant network traffic and image flickering on parent rebuilds.
class AvatarCircle extends StatefulWidget {
  final Person user;
  final double radius;
  final ApiClient apiClient;

  const AvatarCircle({
    super.key,
    required this.user,
    required this.apiClient,
    this.radius = 20,
  });

  @override
  State<AvatarCircle> createState() => _AvatarCircleState();
}

class _AvatarCircleState extends State<AvatarCircle> {
  Future<Uint8List?>? _avatarFuture;

  @override
  void initState() {
    super.initState();
    _avatarFuture = _fetchAvatar();
  }

  @override
  void didUpdateWidget(AvatarCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch only when the user identity or avatar presence changes.
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.hasAvatar != widget.user.hasAvatar) {
      setState(() {
        _avatarFuture = _fetchAvatar();
      });
    }
  }

  Future<Uint8List?> _fetchAvatar() {
    if (!widget.user.hasAvatar) return Future.value(null);
    return widget.apiClient.getBytes('/users/${widget.user.id}/avatar');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.hasAvatar) {
      return _initialsAvatar(context);
    }

    return FutureBuilder<Uint8List?>(
      future: _avatarFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done && data != null) {
          return CircleAvatar(
            radius: widget.radius,
            backgroundImage: MemoryImage(data),
          );
        }
        // While loading or on error / null (avatar removed), show initials
        return _initialsAvatar(context);
      },
    );
  }

  Widget _initialsAvatar(BuildContext context) {
    final initials = widget.user.name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0].toUpperCase())
        .take(2)
        .join();

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: TextStyle(
          fontSize: widget.radius * 0.7,
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
