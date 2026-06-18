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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved ride details. If you leave, they will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (result == true) {
      _createRideFormBloc.add(FormCleared());
    }
    return result ?? false;
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(LucideCompat.car),
      selectedIcon: Icon(LucideCompat.car),
      label: 'Today',
    ),
    NavigationDestination(
      icon: Icon(LucideCompat.calendarDays),
      selectedIcon: Icon(LucideCompat.calendarDays),
      label: 'Calendar',
    ),
    NavigationDestination(
      icon: Icon(Icons.add_circle_outline),
      selectedIcon: Icon(Icons.add_circle),
      label: 'Book',
    ),
    NavigationDestination(
      icon: Icon(LucideCompat.map),
      selectedIcon: Icon(LucideCompat.map),
      label: 'Map',
    ),
    NavigationDestination(
      icon: Icon(LucideCompat.settings),
      selectedIcon: Icon(LucideCompat.settings),
      label: 'Settings',
    ),
  ];

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
    return ResponsiveScaffold(
      destinations: _destinations,
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
