import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';

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
    return AppTheme.buildGradientContainer(
      colors: AppColors.dispatcherGradient,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.paddingLarge),
          padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
          decoration: AppTheme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pending_actions, size: AppDimensions.iconLogo, color: AppColors.dispatcherColor),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text(
                'Pending Rides',
                style: AppStyles.headlineMedium.copyWith(color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                'List of rides with "Requested" status',
                textAlign: TextAlign.center,
                style: AppStyles.bodyLarge.copyWith(color: AppColors.textOnPrimary.withAlpha(204)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverSchedulesTab extends StatelessWidget {
  const DriverSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildGradientContainer(
      colors: AppColors.dispatcherGradient,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.paddingLarge),
          padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
          decoration: AppTheme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_view_day, size: AppDimensions.iconLogo, color: AppColors.dispatcherColor),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text(
                'Driver Schedules',
                style: AppStyles.headlineMedium.copyWith(color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                'Overall view of all company drivers schedules',
                textAlign: TextAlign.center,
                style: AppStyles.bodyLarge.copyWith(color: AppColors.textOnPrimary.withAlpha(204)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssignRidesTab extends StatelessWidget {
  const AssignRidesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildGradientContainer(
      colors: AppColors.dispatcherGradient,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.paddingLarge),
          padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
          decoration: AppTheme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment, size: AppDimensions.iconLogo, color: AppColors.dispatcherColor),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text(
                'Ride Assignment',
                style: AppStyles.headlineMedium.copyWith(color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                'Interface for assigning rides to drivers',
                textAlign: TextAlign.center,
                style: AppStyles.bodyLarge.copyWith(color: AppColors.textOnPrimary.withAlpha(204)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
