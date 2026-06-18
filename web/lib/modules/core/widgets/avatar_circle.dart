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
class AvatarCircle extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!user.hasAvatar) {
      return _initialsAvatar(context);
    }

    return FutureBuilder<Uint8List?>(
      future: apiClient.getBytes('/users/${user.id}/avatar'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(snapshot.data!),
          );
        }
        // While loading or on error / null (avatar removed), show initials
        return _initialsAvatar(context);
      },
    );
  }

  Widget _initialsAvatar(BuildContext context) {
    final initials = user.name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0].toUpperCase())
        .take(2)
        .join();

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: TextStyle(
          fontSize: radius * 0.7,
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
