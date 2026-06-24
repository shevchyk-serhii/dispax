import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/saved_places/saved_places_bloc.dart';
import '../../blocs/saved_places/saved_places_event.dart';
import '../../blocs/saved_places/saved_places_state.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../modules/ride_management/models/client_address.dart';
import '../../modules/ride_management/services/client_address_service.dart';
import '../../modules/ride_management/widgets/saved_place_actions.dart';

/// Full-screen management of the client's saved places (all of them, fixed and
/// custom). Pushed from Settings. Owns its own SavedPlacesBloc scoped to the
/// route — Settings is shared across roles and is not wrapped in one.
class ClientAddressesScreen extends StatelessWidget {
  const ClientAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    return BlocProvider<SavedPlacesBloc>(
      create: (_) {
        final bloc = SavedPlacesBloc(
          addressService: ClientAddressService(
            apiClient: context.read<AuthBloc>().apiClient,
          ),
        );
        if (user != null) bloc.add(SavedPlacesLoadRequested(user.id));
        return bloc;
      },
      child: _ClientAddressesView(clientId: user?.id),
    );
  }
}

class _ClientAddressesView extends StatelessWidget {
  final String? clientId;

  const _ClientAddressesView({required this.clientId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          _buildHeader(context, l10n),
          Expanded(
            child: BlocBuilder<SavedPlacesBloc, SavedPlacesState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final places = state.places;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (places.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          l10n.addAddress,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    for (final place in places)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AddressRow(
                          place: place,
                          onTap: () => _openPlace(context, place),
                        ),
                      ),
                    const SizedBox(height: 4),
                    _AddRow(onTap: () => _add(context)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlace(BuildContext context, ClientAddress place) async {
    if (clientId == null) return;
    await showSavedPlaceActions(
      context,
      place: place,
      clientId: clientId!,
      // On this management screen there is no booking tab to jump to, so
      // "Use this address" just closes the menu.
      onUse: () {},
    );
  }

  Future<void> _add(BuildContext context) async {
    if (clientId == null) return;
    await showAddSavedPlaceFlow(context, clientId: clientId!);
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  l10n.manageAddresses,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

class _AddressRow extends StatelessWidget {
  final ClientAddress place;
  final VoidCallback onTap;

  const _AddressRow({required this.place, required this.onTap});

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(_iconForLabel(place.label), size: 20, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.address,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_horiz, size: 20, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.add, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Text(
              l10n.addCustomAddress,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
