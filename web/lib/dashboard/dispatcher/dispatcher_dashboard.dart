import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'widgets/pending_rides_panel.dart';
import 'widgets/driver_schedule_panel.dart';

class DispatcherDashboard extends StatefulWidget {
  const DispatcherDashboard({super.key});

  @override
  State<DispatcherDashboard> createState() => _DispatcherDashboardState();
}

class _DispatcherDashboardState extends State<DispatcherDashboard> {
  DateTime _selectedDate = DateTime.now();
  int _mobileTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return _buildSplitView();
          }
          return _buildMobileView();
        },
      ),
    );
  }

  Widget _buildSplitView() {
    return Container(
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: const PendingRidesPanel(),
          ),
          Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            flex: 3,
            child: DriverSchedulePanel(
              selectedDate: _selectedDate,
              onDateChanged: (date) => setState(() => _selectedDate = date),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      body: IndexedStack(
        index: _mobileTabIndex,
        children: [
          const PendingRidesPanel(),
          DriverSchedulePanel(
            selectedDate: _selectedDate,
            onDateChanged: (date) => setState(() => _selectedDate = date),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _mobileTabIndex,
        onTap: (index) => setState(() => _mobileTabIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions),
            label: 'Pending',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_view_day),
            label: 'Schedule',
          ),
        ],
      ),
    );
  }
}
