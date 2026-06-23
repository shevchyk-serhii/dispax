import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'calendar/calendar_schedule_screen.dart';
import 'today_rides_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/driver_map_screen.dart';
import '../../screens/create_ride_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/lucide_compat.dart';
import '../../widgets/common/responsive_scaffold.dart';
import '../../blocs/blocs.dart';
import '../../l10n/app_localizations.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  int _selectedIndex = 0;
  late RideBloc _rideBloc;
  final CreateRideFormBloc _createRideFormBloc = CreateRideFormBloc();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
  }

  @override
  void dispose() {
    _createRideFormBloc.close();
    super.dispose();
  }

  Future<bool> _confirmLeaveCreateRide(BuildContext context) async {
    if (!_createRideFormBloc.state.isModified) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.stay),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (result == true) {
      _createRideFormBloc.add(FormCleared());
    }
    return result ?? false;
  }

  List<NavigationDestination> _buildDestinations(AppLocalizations l10n) {
    return [
      NavigationDestination(
        icon: const Icon(LucideCompat.car),
        selectedIcon: const Icon(LucideCompat.car),
        label: l10n.today,
      ),
      NavigationDestination(
        icon: const Icon(LucideCompat.calendarDays),
        selectedIcon: const Icon(LucideCompat.calendarDays),
        label: l10n.calendar,
      ),
      NavigationDestination(
        icon: const Icon(Icons.add_circle_outline),
        selectedIcon: const Icon(Icons.add_circle),
        label: l10n.bookLabel,
      ),
      NavigationDestination(
        icon: const Icon(LucideCompat.map),
        selectedIcon: const Icon(LucideCompat.map),
        label: l10n.map,
      ),
      NavigationDestination(
        icon: const Icon(LucideCompat.settings),
        selectedIcon: const Icon(LucideCompat.settings),
        label: l10n.settings,
      ),
    ];
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return const TodayRidesScreen();
      case 1:
        return const CalendarScheduleScreen();
      case 2:
        return CreateRideScreen(
          rideBloc: _rideBloc,
          formBloc: _createRideFormBloc,
          onCreated: () {
            context.read<RideBloc>().add(
              RideLoadRequested(user: context.read<AuthBloc>().state.user!),
            );
            setState(() => _selectedIndex = 0);
          },
        );
      case 3:
        return const DriverMapScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const TodayRidesScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ResponsiveScaffold(
      destinations: _buildDestinations(l10n),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) async {
        if (_selectedIndex == 2 && index != 2) {
          final canLeave = await _confirmLeaveCreateRide(context);
          if (!canLeave) return;
        }
        setState(() => _selectedIndex = index);
      },
      body: _buildCurrentTab(),
    );
  }
}
