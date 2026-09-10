import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/auth_pages.dart';
import '../core/helpers.dart';
import '../core/explorer_ui.dart';
import '../core/services.dart';
import 'admin_pages.dart';
import 'system/admin_system_pages.dart' hide AdminEmergencyPage;
import 'location_sos/admin_emergency_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;
  final search = TextEditingController();

  Timer? _inactivityTimer;
  Timer? _popupCountdownTimer;
  final ValueNotifier<int> _countdownNotifier = ValueNotifier<int>(10);
  bool _isDialogShowing = false;

  static const _items = <({String label, IconData icon})>[
    (label: 'Dashboard', icon: Icons.grid_view_rounded),
    (label: 'Tourist Management', icon: Icons.explore_outlined),
    (label: 'Vendor Management', icon: Icons.storefront_outlined),
    (label: 'User & Vendor Reports', icon: Icons.report_problem_outlined),
    (label: 'Cultural Experiences', icon: Icons.account_balance_outlined),
    (label: 'Review Moderation', icon: Icons.rate_review_outlined),
    (label: 'Location & SOS Records', icon: Icons.sos_outlined),
    (label: 'Safety & Hazard', icon: Icons.health_and_safety_outlined),
    (label: 'Basic Settings', icon: Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialSessionTimeout();
    HardwareKeyboard.instance.addHandler(_onGlobalKeyEvent);
    _startInactivityTimer();
  }

  Future<void> _checkInitialSessionTimeout() async {
    final isTimedOut = await AdminSessionManager.isSessionTimedOut();
    if (isTimedOut) {
      _kickOutUser();
    } else {
      await AdminSessionManager.updateActivity();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onGlobalKeyEvent);
    _inactivityTimer?.cancel();
    _popupCountdownTimer?.cancel();
    _countdownNotifier.dispose();
    search.dispose();
    super.dispose();
  }

  bool _onGlobalKeyEvent(KeyEvent event) {
    _handleUserActivity();
    return false;
  }

  void _handleUserActivity() {
    if (_isDialogShowing) return;
    AdminSessionManager.updateActivity();
    _resetInactivityTimer();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 30), _onInactivityTimeout);
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 30), _onInactivityTimeout);
  }

  void _onInactivityTimeout() {
    if (_isDialogShowing || !mounted) return;
    _showTimeoutDialog();
  }

  void _dismissAndKickOut() {
    if (_isDialogShowing) {
      _isDialogShowing = false;
      _popupCountdownTimer?.cancel();
      try {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (_) {}
    }
    _kickOutUser();
  }

  void _showTimeoutDialog() {
    _isDialogShowing = true;
    _countdownNotifier.value = 10;

    _popupCountdownTimer?.cancel();
    _popupCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownNotifier.value <= 1) {
        _countdownNotifier.value = 0;
        timer.cancel();
        _dismissAndKickOut();
      } else {
        _countdownNotifier.value--;
      }
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ValueListenableBuilder<int>(
          valueListenable: _countdownNotifier,
          builder: (context, seconds, child) {
            return PopScope(
              canPop: false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: ExplorerColors.gold,
                      size: 28,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Session Inactivity Warning',
                      style: TextStyle(
                        color: ExplorerColors.navy,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'You have been immobile for 30 seconds. For security reasons, you will be automatically logged out in:',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: ExplorerColors.navy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$seconds',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: ExplorerColors.navy,
                            ),
                          ),
                          const Text(
                            'seconds remaining',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ExplorerColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: _dismissAndKickOut,
                    child: const Text(
                      'Sign Out Now',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ExplorerColors.navy,
                    ),
                    onPressed: _dismissTimeoutDialog,
                    child: const Text('Stay Logged In'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _isDialogShowing = false;
      _popupCountdownTimer?.cancel();
    });
  }

  void _dismissTimeoutDialog() {
    if (_isDialogShowing) {
      _isDialogShowing = false;
      _popupCountdownTimer?.cancel();
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    AdminSessionManager.updateActivity();
    _startInactivityTimer();
  }

  Future<void> _kickOutUser({bool timedOut = true}) async {
    _inactivityTimer?.cancel();
    _popupCountdownTimer?.cancel();
    _isDialogShowing = false;

    try {
      await AppServices.performAdminSignOut(timedOut: timedOut);
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AdminDashboardPage(),
      const AdminUsersPage(
        roleFilter: 'traveler',
        pageTitle: 'Tourist Management',
      ),
      const AdminUsersPage(
        roleFilter: 'vendor',
        pageTitle: 'Vendor Management',
      ),
      const AdminReportsPage(),
      const AdminCulturalPage(),
      const AdminReviewsPage(),
      const AdminEmergencyPage(),
      const AdminHazardsPage(),
      const AdminSettingsPage(),
    ];

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handleUserActivity(),
      onPointerMove: (_) => _handleUserActivity(),
      onPointerHover: (_) => _handleUserActivity(),
      onPointerSignal: (_) => _handleUserActivity(),
      child: Scaffold(
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
            onSelected: (value) async {
              if (value == 'logout') {
                try {
                  await AppServices.performAdminSignOut(timedOut: false);
                } catch (_) {}
              }
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
