
import 'package:flutter/material.dart';
import '../core/explorer_ui.dart';
import 'traveler_pages.dart';

class TravelerShell extends StatefulWidget {
  const TravelerShell({
    super.key,
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  State<TravelerShell> createState() => _TravelerShellState();
}

class _TravelerShellState extends State<TravelerShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TravelerHomePage(profile: widget.profile),
      const DailyPlannerPage(),
      const CulturalTasksPage(),
      const CompanionPage(),
      TravelerProfilePage(profile: widget.profile),
    ];

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Companion',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
