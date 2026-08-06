import 'package:flutter/material.dart';
import '../core/explorer_ui.dart';
import '../core/services.dart';
import 'admin_pages.dart';
import 'system/admin_system_pages.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;
  final search = TextEditingController();

  static const _items = <({String label, IconData icon})>[
    (label: 'Dashboard', icon: Icons.grid_view_rounded),
    (label: 'Admin Management', icon: Icons.admin_panel_settings_outlined),
    (label: 'Tourist Management', icon: Icons.explore_outlined),
    (label: 'Vendor Management', icon: Icons.storefront_outlined),
    (label: 'Cultural Experiences', icon: Icons.account_balance_outlined),
    (label: 'Review Moderation', icon: Icons.rate_review_outlined),
    (label: 'Emergency Logs', icon: Icons.sos_outlined),
    (label: 'Safety & Hazard', icon: Icons.health_and_safety_outlined),
    (label: 'Basic Settings', icon: Icons.settings_outlined),
  ];

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AdminDashboardPage(),
      const AdminManagementPage(),
      const AdminUsersPage(
        roleFilter: 'traveler',
        pageTitle: 'Tourist Management',
      ),
      const AdminUsersPage(
        roleFilter: 'vendor',
        pageTitle: 'Vendor Management',
      ),
      const AdminCulturalPage(),
      const AdminReviewsPage(),
      const AdminEmergencyPage(),
      const AdminHazardsPage(),
      const AdminSettingsPage(),
    ];

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1050;
          return Row(
            children: [
              _AdminSidebar(
                compact: compact,
                selectedIndex: index,
                profile: widget.profile,
                onSelected: (value) => setState(() => index = value),
              ),
              Expanded(
                child: Column(
                  children: [
                    _AdminTopBar(
                      controller: search,
                      profile: widget.profile,
                      currentLabel: _items[index].label,
                    ),
                    Expanded(
                      child: IndexedStack(index: index, children: pages),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.compact,
    required this.selectedIndex,
    required this.profile,
    required this.onSelected,
  });

  final bool compact;
  final int selectedIndex;
  final Map<String, dynamic> profile;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final name = '${profile['displayName'] ?? 'Administrator'}';
    final email = '${profile['email'] ?? AppServices.auth.currentUser?.email ?? ''}';
    return Container(
      width: compact ? 86 : 242,
      color: ExplorerColors.navyDark,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 20,
                18,
                compact ? 16 : 20,
                20,
              ),
              child: compact
                  ? const Icon(
                      Icons.account_balance_outlined,
                      color: Colors.white,
                      size: 30,
                    )
                  : const ExplorerBrand(
                      compact: true,
                      dark: true,
                      subtitle: 'System Controller',
                    ),
            ),
            Container(height: 1, color: Colors.white.withOpacity(.08)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _AdminShellState._items.length,
                itemBuilder: (context, itemIndex) {
                  final item = _AdminShellState._items[itemIndex];
                  final selected = itemIndex == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Tooltip(
                      message: compact ? item.label : '',
                      child: Material(
                        color: selected
                            ? Colors.white.withOpacity(.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () => onSelected(itemIndex),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 46,
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 0 : 13,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: selected
                                  ? const Border(
                                      left: BorderSide(
                                        color: ExplorerColors.gold,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: compact
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Icon(
                                  item.icon,
                                  color: selected
                                      ? ExplorerColors.gold
                                      : Colors.white70,
                                  size: 21,
                                ),
                                if (!compact) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(height: 1, color: Colors.white.withOpacity(.08)),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 16),
              child: compact
                  ? CircleAvatar(
                      radius: 21,
                      backgroundColor: ExplorerColors.gold,
                      foregroundColor: ExplorerColors.navy,
                      child: Text(
                        name.isEmpty ? 'A' : name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: ExplorerColors.gold,
                          foregroundColor: ExplorerColors.navy,
                          child: Text(
                            name.isEmpty ? 'A' : name[0].toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                email,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.controller,
    required this.profile,
    required this.currentLabel,
  });

  final TextEditingController controller;
  final Map<String, dynamic> profile;
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    final name = '${profile['displayName'] ?? 'Administrator'}';
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ExplorerColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              currentLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 300,
            child: ExplorerSearchField(
              controller: controller,
              hintText: 'Search platform records...',
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 18,
            backgroundColor: ExplorerColors.navySoft,
            foregroundColor: ExplorerColors.navy,
            child: Text(
              name.isEmpty ? 'A' : name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'logout') AppServices.auth.signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
            child: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }
}
