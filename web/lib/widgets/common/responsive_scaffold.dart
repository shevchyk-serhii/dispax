import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';

/// A scaffold that automatically switches between a [NavigationRail] (desktop,
/// >= [AppDimensions.breakpointDesktop]) and a [BottomNavigationBar] (mobile).
///
/// The graphite header and role-specific logic remain in each screen's [body].
/// [ResponsiveScaffold] only manages navigation chrome.
class ResponsiveScaffold extends StatelessWidget {
  /// The list of navigation destinations (used for both rail and bottom bar).
  final List<NavigationDestination> destinations;

  /// The currently-selected destination index.
  final int selectedIndex;

  /// Called when the user taps a destination.
  final ValueChanged<int> onDestinationSelected;

  /// The main content of the screen.
  final Widget body;

  /// Optional actions shown in the mobile [AppBar].
  final List<Widget> appBarActions;

  /// Optional widget placed at the top of the [NavigationRail] (e.g. logo).
  final Widget? railHeader;

  const ResponsiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBarActions = const [],
    this.railHeader,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppDimensions.breakpointDesktop) {
          return _buildDesktopLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildRail(context),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppDimensions.maxContentWidth,
                ),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomBar(context),
      ),
    );
  }

  Widget _buildRail(BuildContext context) {
    TextStyle labelStyle(Color color) =>
        TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600);

    return NavigationRail(
      backgroundColor: AppColors.primary,
      indicatorColor: AppColors.accent.withValues(alpha: 0.2),
      selectedIconTheme: const IconThemeData(color: AppColors.accent),
      unselectedIconTheme: const IconThemeData(color: AppColors.textOnPrimary),
      selectedLabelTextStyle: labelStyle(AppColors.accent),
      unselectedLabelTextStyle: labelStyle(AppColors.textOnPrimary),
      labelType: NavigationRailLabelType.all,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      leading: railHeader,
      destinations: destinations
          .map(
            (d) => NavigationRailDestination(
              icon: d.icon,
              selectedIcon: d.selectedIcon ?? d.icon,
              label: Text(d.label),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onDestinationSelected,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      items: destinations
          .map(
            (d) => BottomNavigationBarItem(
              icon: d.icon,
              activeIcon: d.selectedIcon ?? d.icon,
              label: d.label,
            ),
          )
          .toList(),
    );
  }
}
