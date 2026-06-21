import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/blocs.dart';
import '../../modules/core/services/user_service.dart';
import '../../modules/ride_management/models/ride.dart';
import '../../screens/create_ride_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import 'secretary_front_desk_stats.dart';
import '../../screens/settings_screen.dart';
import '../../utils/ride_status_styles.dart';
import '../../widgets/common/notification_bell.dart';
import '../../widgets/common/responsive_scaffold.dart';
import 'widgets/secretary_reports_panel.dart';

class SecretaryDashboard extends StatefulWidget {
  const SecretaryDashboard({super.key});

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  int _selectedIndex = 0;
  late RideBloc _rideBloc;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.list_outlined),
      selectedIcon: Icon(Icons.list),
      label: 'Rides',
    ),
    NavigationDestination(
      icon: Icon(Icons.add_circle_outline),
      selectedIcon: Icon(Icons.add_circle),
      label: 'Create',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps every tab's State alive across switches so panels
    // (e.g. SecretaryReportsPanel) don't re-fetch on each visit.
    final tabs = [
      _FrontDeskTab(onQuickBook: () => setState(() => _selectedIndex = 2)),
      const SecretaryReportsPanel(),
      CreateRideScreen(
        rideBloc: _rideBloc,
        onCreated: () {
          final user = context.read<AuthBloc>().state.user;
          if (user != null) {
            context.read<RideBloc>().add(RideLoadRequested(user: user));
          }
          setState(() => _selectedIndex = 0);
        },
      ),
      const SettingsScreen(),
    ];

    return BlocProvider<ClientBloc>(
      create: (context) {
        final authBloc = context.read<AuthBloc>();
        // Load clients up-front so the "Active clients" stat tile populates —
        // the client list panel is no longer in the IndexedStack to trigger it.
        return ClientBloc(
          userService: UserService(apiClient: authBloc.apiClient),
        )..add(const ClientLoadRequested());
      },
      child: ResponsiveScaffold(
        destinations: _destinations,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        body: IndexedStack(index: _selectedIndex, children: tabs),
      ),
    );
  }
}

// ─── Front Desk Tab (Home) ────────────────────────────────────────────────────

class _FrontDeskTab extends StatelessWidget {
  final VoidCallback onQuickBook;

  const _FrontDeskTab({required this.onQuickBook});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Graphite header
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMedium,
              vertical: 14,
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Front desk',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onQuickBook,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Quick book',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSmall,
                        ),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const NotificationBell(),
                ],
              ),
            ),
          ),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4 stat tiles
                BlocBuilder<RideBloc, RideState>(
                  builder: (context, rideState) {
                    return BlocBuilder<ClientBloc, ClientState>(
                      builder: (context, clientState) {
                        return _StatTilesRow(
                          rideState: rideState,
                          clientState: clientState,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Today's bookings
                BlocBuilder<RideBloc, RideState>(
                  builder: (context, rideState) {
                    return _TodaysBookingsCard(rideState: rideState);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stat Tiles Row ───────────────────────────────────────────────────────────

class _StatTilesRow extends StatelessWidget {
  final RideState rideState;
  final ClientState clientState;

  const _StatTilesRow({required this.rideState, required this.clientState});

  @override
  Widget build(BuildContext context) {
    final bookedToday = rideState.isLoaded
        ? SecretaryFrontDeskStats.bookedCount(rideState.rides)
        : null;
    final awaitingConfirm = rideState.isLoaded
        ? SecretaryFrontDeskStats.awaitingConfirmCount(rideState.rides)
        : null;
    final activeClients = clientState.isLoaded
        ? clientState.clients.length
        : null;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Booked today',
            value: bookedToday != null ? '$bookedToday' : '—',
            valueColor: null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Awaiting confirm',
            value: awaitingConfirm != null ? '$awaitingConfirm' : '—',
            valueColor: awaitingConfirm != null && awaitingConfirm > 0
                ? AppColors.rideRequested
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Active clients',
            value: activeClients != null ? '$activeClients' : '—',
            valueColor: null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _TemplatesStatTile()),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        valueColor ??
        (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowXs,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Templates stat tile loads template count from the API.
class _TemplatesStatTile extends StatefulWidget {
  const _TemplatesStatTile();

  @override
  State<_TemplatesStatTile> createState() => _TemplatesStatTileState();
}

class _TemplatesStatTileState extends State<_TemplatesStatTile> {
  int? _count;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final apiClient = context.read<AuthBloc>().apiClient;
      final resp = await apiClient.get('/ride-templates');
      if (resp.statusCode == 200 && mounted) {
        final decoded = jsonDecode(resp.body);
        final count = decoded is List ? decoded.length : null;
        setState(() => _count = count);
      }
    } catch (_) {
      // Graceful degradation — show '—'
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowXs,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _count != null ? '$_count' : '—',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Templates',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Today's Bookings Card ────────────────────────────────────────────────────

class _TodaysBookingsCard extends StatelessWidget {
  final RideState rideState;

  const _TodaysBookingsCard({required this.rideState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayRides = rideState.isLoaded
        ? SecretaryFrontDeskStats.ridesOn(rideState.rides)
        : <Ride>[];

    // Sort by pickup time ascending
    todayRides.sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowXs,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              "Today's bookings",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.borderDark : const Color(0xFFF4F4F5),
          ),
          if (rideState.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (todayRides.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
              child: Center(
                child: Text(
                  rideState.isLoaded
                      ? 'No rides today'
                      : 'Load rides to see today\'s bookings',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...todayRides.asMap().entries.map((entry) {
              final i = entry.key;
              final ride = entry.value;
              return _BookingRow(
                ride: ride,
                isLast: i == todayRides.length - 1,
              );
            }),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final Ride ride;
  final bool isLast;

  const _BookingRow({required this.ride, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeLabel = DateFormat('HH:mm').format(ride.pickupDateTime);
    final fromShort = _truncateAddress(ride.from.address);
    final toShort = _truncateAddress(ride.to.address);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Time column
              SizedBox(
                width: 48,
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Route + subline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fromShort → $toShort',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buildSubline(ride),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.textLightDark
                            : AppColors.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              RideStatusStyles.createStatusBadge(
                ride.status,
                context: context,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.borderDark : const Color(0xFFF4F4F5),
            indent: 18,
            endIndent: 18,
          ),
      ],
    );
  }

  String _truncateAddress(String address) {
    final parts = address.split(',');
    return parts.first.trim();
  }

  String _buildSubline(Ride ride) {
    final parts = <String>[];
    if (ride.clientName.isNotEmpty) parts.add(ride.clientName);
    if (ride.flightNumber != null && ride.flightNumber!.isNotEmpty) {
      parts.add(ride.flightNumber!);
    }
    return parts.join(' · ');
  }
}
