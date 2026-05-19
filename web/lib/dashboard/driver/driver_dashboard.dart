import 'package:flutter/material.dart';
import 'calendar/calendar_schedule_screen.dart';
import 'today_rides_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/driver_map_screen.dart';
import '../../constants/app_colors.dart';

class DriverDashboard extends StatelessWidget {
  const DriverDashboard({super.key});

  static final ValueNotifier<int> selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedIndexNotifier,
      builder: (context, selectedIndex, child) {
        return Scaffold(
          body: IndexedStack(
            index: selectedIndex,
            children: const [
              TodayRidesScreen(),
              CalendarScheduleScreen(),
              DriverMapScreen(),
              SettingsScreen(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: selectedIndex,
            selectedItemColor: AppColors.driverColor,
            onTap: (index) {
              selectedIndexNotifier.value = index;
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
      },
    );
  }
}

