import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/core/services/user_service.dart';
import '../../screens/create_ride_screen.dart';
import '../../theme/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../constants/app_dimensions.dart';
import '../../screens/settings_screen.dart';
import '../../widgets/common/notification_bell.dart';
import 'widgets/secretary_reports_panel.dart';

class SecretaryDashboard extends StatefulWidget {
  const SecretaryDashboard({super.key});

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  int _selectedIndex = 0;
  late RideBloc _rideBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ClientBloc>(
      create: (context) {
        final authBloc = context.read<AuthBloc>();
        return ClientBloc(
          userService: UserService(apiClient: authBloc.apiClient),
        );
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const _CreateRidesTab(),
            const SecretaryReportsPanel(),
            CreateRideScreen(
              rideBloc: _rideBloc,
              onCreated: () {
                final user = context.read<AuthBloc>().state.user;
                if (user != null) context.read<RideBloc>().add(RideLoadRequested(user: user));
                setState(() => _selectedIndex = 0);
              },
            ),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: AppColors.accent,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_outlined),
              activeIcon: Icon(Icons.list),
              label: 'Rides',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Create',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRidesTab extends StatelessWidget {
  const _CreateRidesTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppColors.secretaryGradient),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Create New Ride',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const NotificationBell(),
              ],
            ),
          ),
        ),
        Expanded(
          child: AppTheme.buildGradientContainer(
        colors: AppColors.secretaryGradient,
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
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
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
                          onPressed: () async {
                            final rideBloc = context.read<RideBloc>();
                            final authBloc = context.read<AuthBloc>();
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CreateRideScreen(rideBloc: rideBloc),
                              ),
                            );
                            final user = authBloc.state.user;
                            if (user != null) rideBloc.add(RideLoadRequested(user: user));
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
                        context,
                        'Today\'s Rides',
                        '12',
                        Icons.today,
                        AppColors.info,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.paddingMedium),
                    Expanded(
                      child: _buildQuickStatCard(
                        context,
                        'This Week',
                        '47',
                        Icons.date_range,
                        AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(BuildContext context, String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
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
