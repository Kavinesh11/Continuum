import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/notification_toast.dart';
import 'dashboard.dart';
import 'claims.dart';
import 'assists.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedTab = 0;
  int _dashboardRefreshToken = 0;
  int _claimsRefreshToken = 0;

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.cardOf(context);

    return NotificationToastLayer(
      child: Scaffold(
        body: IndexedStack(
        index: _selectedTab,
        children: [
          DashboardScreen(refreshToken: _dashboardRefreshToken),
          ClaimsScreen(refreshToken: _claimsRefreshToken),
          const AssistsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                AppTheme.isDark(context) ? 0.3 : 0.06,
              ),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (tab) {
              setState(() {
                _selectedTab = tab;
                if (tab == 0) {
                  _dashboardRefreshToken++;
                }
                if (tab == 1) {
                  _claimsRefreshToken++;
                }
              });
            },
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.home_outlined,
                  color: _selectedTab == 0
                      ? AppTheme.primary
                      : AppTheme.textHintOf(context),
                ),
                selectedIcon: const Icon(
                  Icons.home_rounded,
                  color: AppTheme.primary,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.description_outlined,
                  color: _selectedTab == 1
                      ? AppTheme.primary
                      : AppTheme.textHintOf(context),
                ),
                selectedIcon: const Icon(
                  Icons.description_rounded,
                  color: AppTheme.primary,
                ),
                label: 'Claims',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.support_agent_outlined,
                  color: _selectedTab == 2
                      ? AppTheme.primary
                      : AppTheme.textHintOf(context),
                ),
                selectedIcon: const Icon(
                  Icons.support_agent,
                  color: AppTheme.primary,
                ),
                label: 'Assist',
              ),
            ],
          ),
        ),
      ),
      ),
    ); // NotificationToastLayer
  }
}
