import 'package:flutter/material.dart';

class DispatcherDashboard extends StatelessWidget {
  const DispatcherDashboard({super.key});

  static final ValueNotifier<int> selectedIndexNotifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<int>(
        valueListenable: selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return IndexedStack(
            index: selectedIndex,
            children: const [
              PendingRidesTab(),
              DriverSchedulesTab(),
              AssignRidesTab(),
            ],
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: selectedIndexNotifier,
        builder: (context, selectedIndex, child) {
          return BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              selectedIndexNotifier.value = index;
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.pending_actions),
                label: 'Pending',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_view_day),
                label: 'Schedule',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment),
                label: 'Assignment',
              ),
            ],
          );
        },
      ),
    );
  }
}

class PendingRidesTab extends StatelessWidget {
  const PendingRidesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pending_actions, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Pending Rides',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'List of rides with "Requested" status',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class DriverSchedulesTab extends StatelessWidget {
  const DriverSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_view_day, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Driver Schedules',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Overall view of all company drivers schedules',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class AssignRidesTab extends StatelessWidget {
  const AssignRidesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Ride Assignment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Interface for assigning rides to drivers',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
