import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../constants/app_colors.dart';
import '../../modules/core/services/mapbox_service.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../modules/ride_management/widgets/address_picker_sheet.dart';

/// Client Home tab — graphite header, live ride card, saved places, book button.
class ClientHomeScreen extends StatelessWidget {
  /// Called when the user taps "Where to?" or "Book a ride" — switches to the Book tab.
  final VoidCallback onBookTap;

  const ClientHomeScreen({super.key, required this.onBookTap});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HomeHeader(onSearchTap: onBookTap),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LiveRideCard(),
                    const SizedBox(height: 20),
                    _SavedPlacesRow(onPlaceTap: onBookTap),
                    const SizedBox(height: 18),
                    _BookRideButton(onTap: onBookTap),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final VoidCallback onSearchTap;

  const _HomeHeader({required this.onSearchTap});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    final name = user?.name ?? '';
    final initials = _initials(name);

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // "Where to?" search pill
          GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Where to?',
                    style: TextStyle(fontSize: 14, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ─── Live Ride Card ──────────────────────────────────────────────────────────

class _LiveRideCard extends StatelessWidget {
  const _LiveRideCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideBloc, RideState>(
      builder: (context, rideState) {
        if (rideState.status == RideStateStatus.initial) {
          final user = context.read<AuthBloc>().state.user;
          if (user != null) {
            context.read<RideBloc>().add(RideLoadRequested(user: user));
          }
        }

        final activeRide = _findActiveRide(rideState.rides);
        if (activeRide == null) return const SizedBox.shrink();

        return _buildCard(context, activeRide);
      },
    );
  }

  Ride? _findActiveRide(List<Ride> rides) {
    try {
      return rides.firstWhere(
        (r) =>
            r.status == RideStatus.assigned ||
            r.status == RideStatus.inProgress,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildCard(BuildContext context, Ride ride) {
    final eta = ride.etaMinutes;
    final driverName = ride.driverName ?? 'Your driver';
    // Driver's reputation (their average rating), now exposed on the RideDto.
    final driverRating = ride.driverRating;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLg,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status pill + ETA
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ride.status == RideStatus.inProgress
                          ? 'On trip'
                          : (ride.driverEnRoute
                                ? 'Driver on the way'
                                : 'Driver assigned'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (eta != null)
                Text(
                  '$eta min',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          // Driver row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(driverName),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverRating != null
                          ? '$driverName · ${driverRating.toStringAsFixed(1)}★'
                          : driverName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _vehicleLine(ride),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textLight,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _vehicleLine(Ride ride) {
    // driverName is available on ride; vehicle plate isn't in the current RideDto.
    // Degrade gracefully — show whatever we have.
    return ride.driverName ?? 'Driver assigned';
  }
}

// ─── Saved Places ────────────────────────────────────────────────────────────

class _SavedPlacesRow extends StatelessWidget {
  final VoidCallback onPlaceTap;

  const _SavedPlacesRow({required this.onPlaceTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SAVED PLACES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04 * 11,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 10),
        BlocBuilder<SavedPlacesBloc, SavedPlacesState>(
          builder: (context, state) {
            final home = state.findByLabel('Home');
            final office = state.findByLabel('Office');
            final airport = state.findByLabel('Airport');

            return Row(
              children: [
                Expanded(
                  child: _PlaceTile(
                    icon: Icons.home_outlined,
                    title: home?.label ?? 'Home',
                    subtitle: home?.address ?? 'Add address',
                    onTap: home != null
                        ? onPlaceTap
                        : () => _addPlace(context, 'Home'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlaceTile(
                    icon: Icons.business_outlined,
                    title: office?.label ?? 'Office',
                    subtitle: office?.address ?? 'Add address',
                    onTap: office != null
                        ? onPlaceTap
                        : () => _addPlace(context, 'Office'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlaceTile(
                    icon: Icons.flight_outlined,
                    title: airport?.label ?? 'Airport',
                    subtitle: airport?.address ?? 'Add address',
                    onTap: airport != null
                        ? onPlaceTap
                        : () => _addPlace(context, 'Airport'),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Opens the address picker for an empty saved-place slot and persists the
  /// chosen address under [label] (Home/Office/Airport) for the current client.
  Future<void> _addPlace(BuildContext context, String label) async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;

    final savedBloc = context.read<SavedPlacesBloc>();
    final existing = savedBloc.state.places
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

    // Best-effort geocoding — coordinates are optional on the backend DTO.
    final coords = await MapboxService.geocodeAddress(address);

    savedBloc.add(
      SavedPlacesSaveRequested(
        clientId: user.id,
        label: label,
        address: address,
        latitude: coords != null && coords.length == 2 ? coords[0] : null,
        longitude: coords != null && coords.length == 2 ? coords[1] : null,
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowXs,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(height: 9),
            Text(
              title,
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
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Book a Ride Button ──────────────────────────────────────────────────────

class _BookRideButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BookRideButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 20, color: Colors.white),
        label: const Text(
          'Book a ride',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          shadowColor: AppColors.accent.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
