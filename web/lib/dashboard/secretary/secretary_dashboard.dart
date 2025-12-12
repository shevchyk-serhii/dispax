import 'package:flutter/material.dart';
import '../../screens/create_ride_screen.dart';
import '../../theme/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';

class SecretaryDashboard extends StatefulWidget {
  const SecretaryDashboard({super.key});

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [_CreateRidesTab(), _ManageClientsTab(), _ReportsTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Create Ride',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class _CreateRidesTab extends StatelessWidget {
  const _CreateRidesTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Ride', style: AppStyles.titleLarge.copyWith(color: AppColors.textOnPrimary)),
        backgroundColor: AppColors.secretaryColor,
        foregroundColor: AppColors.textOnPrimary,
        elevation: AppDimensions.appBarElevation,
        automaticallyImplyLeading: false,
      ),
      body: AppTheme.buildGradientContainer(
        colors: AppColors.secretaryGradient,
        stops: const [0.0, 0.15, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
                  decoration: AppTheme.cardDecoration,
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: AppDimensions.iconLogo,
                        color: AppColors.secretaryColor,
                      ),
                      const SizedBox(height: AppDimensions.paddingLarge),
                      Text(
                        'Create New Ride',
                        style: AppStyles.headlineMedium,
                      ),
                      const SizedBox(height: AppDimensions.paddingMedium),
                      Text(
                        'Book rides for your clients with flight information and airport transfer details',
                        textAlign: TextAlign.center,
                        style: AppStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppDimensions.paddingXLarge),
                      SizedBox(
                        width: double.infinity,
                        height: AppDimensions.buttonHeightMedium,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const CreateRideScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Start Creating'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secretaryColor,
                            foregroundColor: AppColors.textOnPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingXLarge),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickStatCard(
                        'Today\'s Rides',
                        '12',
                        Icons.today,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: _buildQuickStatCard(
                        'This Week',
                        '47',
                        Icons.date_range,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppTheme.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppDimensions.iconXLarge),
          const SizedBox(height: AppDimensions.paddingSmall),
          Text(
            count,
            style: AppStyles.headlineMedium.copyWith(color: color),
          ),
          const SizedBox(height: AppDimensions.paddingXSmall),
          Text(
            title,
            style: AppStyles.labelSmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ManageClientsTab extends StatelessWidget {
  const _ManageClientsTab();

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildGradientContainer(
      colors: AppColors.secretaryGradient,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.paddingLarge),
          padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
          decoration: AppTheme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, size: AppDimensions.iconLogo, color: AppColors.secretaryColor),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text(
                'Client Management',
                style: AppStyles.headlineMedium.copyWith(color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                'Client list and account management',
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

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildGradientContainer(
      colors: AppColors.secretaryGradient,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.paddingLarge),
          padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
          decoration: AppTheme.glassDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics, size: AppDimensions.iconLogo, color: AppColors.secretaryColor),
              const SizedBox(height: AppDimensions.paddingMedium),
              Text(
                'Reports',
                style: AppStyles.headlineMedium.copyWith(color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: AppDimensions.paddingSmall),
              Text(
                'Statistics and ride reports',
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
