import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          DashboardScreen(),
          ClaimsScreen(),
          AssistsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (tab) {
          setState(() => _selectedTab = tab);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.description),
            label: 'Claims',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent),
            label: 'Assist',
          ),
        ],
      ),
    );
  }
}
