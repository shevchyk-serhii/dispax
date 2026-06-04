import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'calendar/calendar_schedule_screen.dart';
import 'today_rides_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/driver_map_screen.dart';
import '../../screens/create_ride_screen.dart';
import '../../constants/app_colors.dart';
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
        content: const Text('You have unsaved ride details. If you leave, they will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
            context.read<RideBloc>().add(RideLoadRequested(user: context.read<AuthBloc>().state.user!));
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
    return Scaffold(
      body: _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.driverColor,
        onTap: (index) async {
          if (_selectedIndex == 2 && index != 2) {
            final canLeave = await _confirmLeaveCreateRide(context);
            if (!canLeave) return;
          }
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            activeIcon: Icon(Icons.today),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
