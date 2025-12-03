import 'package:flutter/material.dart';
import 'calendar/calendar_schedule_screen.dart';
import 'today_rides_screen.dart';
import 'upcoming_rides_screen.dart';
import '../../screens/flight_screen.dart';

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
              UpcomingRidesScreen(),
              FlightScreen(),
              ProfileTab(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: selectedIndex,
            onTap: (index) {
              selectedIndexNotifier.value = index;
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Today'),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'Calendar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_note),
                label: 'Upcoming',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.flight),
                label: 'Flights',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Driver Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Personal information, vehicle details, and account settings',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
