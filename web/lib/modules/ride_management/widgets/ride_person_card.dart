import 'package:flutter/material.dart';
import 'package:dispax/l10n/app_localizations.dart';
import '../../core/models/person.dart';
import '../../core/services/api_client.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/copy_icon_button.dart';
import '../../../constants/app_colors.dart';

class RidePersonCard extends StatelessWidget {
  final Person person;
  final bool isDriver;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;

  /// When set, tapping the avatar lets the operator attach/replace this person's
  /// photo. The caller is responsible for gating this by role/target (a driver
  /// may photograph a client, not another driver), so the card simply shows a
  /// small camera badge and forwards the tap when the callback is present.
  final VoidCallback? onAvatarTap;

  /// Bumped by the caller after a successful photo upload so the avatar re-fetches
  /// even on a replace (where hasAvatar stays true).
  final Object? avatarReloadToken;

  /// Passed in (not read from context) because this card is shown inside a
  /// pushed route (RideDetailsScreen) that may sit outside the AuthBloc provider.
  final ApiClient apiClient;

  const RidePersonCard({
    super.key,
    required this.person,
    required this.apiClient,
    this.isDriver = false,
    this.onCall,
    this.onMessage,
    this.onAvatarTap,
    this.avatarReloadToken,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Profile photo when set, initials fallback otherwise.
                // Tappable (with a camera badge) when photo editing is allowed.
                _buildAvatar(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDriver ? l10n.roleDriver : l10n.roleClient,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (person.phone?.isNotEmpty == true)
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                person.phone ?? '',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            CopyIconButton(
                              value: person.phone ?? '',
                              label: l10n.phone,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),

            if (isDriver && person.vehicleInfo != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildVehicleInfo(context),
            ],

            if (person.phone?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onCall != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text(l10n.call),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (onCall != null && onMessage != null)
                    const SizedBox(width: 12),
                  if (onMessage != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onMessage,
                        icon: const Icon(Icons.message, size: 18),
                        label: Text(l10n.messageButton),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final avatar = AvatarCircle(
      user: person,
      apiClient: apiClient,
      radius: 24,
      reloadToken: avatarReloadToken,
    );
    if (onAvatarTap == null) return avatar;

    return GestureDetector(
      onTap: onAvatarTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.photo_camera,
                size: 12,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vehicle = person.vehicleInfo;
    if (vehicle == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.vehicleInformationLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Icon(
              Icons.directions_car,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '${vehicle.make} ${vehicle.model}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),

        if (vehicle.color?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.palette,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                vehicle.color ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],

        if (vehicle.licensePlate?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.confirmation_number,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  vehicle.licensePlate ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              CopyIconButton(
                value: vehicle.licensePlate ?? '',
                label: l10n.licensePlate,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
