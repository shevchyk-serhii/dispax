import 'package:flutter/material.dart';
import 'calendar/calendar_schedule_screen.dart';
import 'today_rides_screen.dart';
import 'upcoming_rides_screen.dart';
import 'ride_history_screen.dart';
import '../../screens/flight_screen.dart';
// import '../../screens/driver_map_screen.dart'; // Disabled for compatibility
import '../../screens/simple_map_screen.dart';

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
            children: [
              const TodayRidesScreen(),
              const CalendarScheduleScreen(),
              const UpcomingRidesScreen(),
              const RideHistoryScreen(),
              const FlightScreen(),
              const SimpleMapScreen(),
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
                icon: Icon(Icons.history),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.flight),
                label: 'Flights',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Map',
              ),
            ],
          ),
        );
      },
    );
  }
}

