import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services.dart';
import '../core/explorer_ui.dart';
import 'traveler_pages.dart';

class TravelerShell extends StatefulWidget {
  const TravelerShell({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<TravelerShell> createState() => _TravelerShellState();
}

class _TravelerShellState extends State<TravelerShell>
    with WidgetsBindingObserver {
  int index = 0;
  StreamSubscription<Position>? _rewardLocationSubscription;
  bool _backgroundRewardsActive = false;
  bool _backgroundRewardsStarting = false;
  DateTime? _lastBackgroundRewardCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkNearbyRewards());
      unawaited(AppServices.syncVoucherExpiryReminders());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_rewardLocationSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkNearbyRewards());
    }
  }

  Future<void> _checkNearbyRewards() async {
    try {
      await AppServices.checkNearbyRewardNotifications();
    } catch (_) {
      // Proximity alerts are best-effort and must not block the traveler UI.
    }
  }

  void _syncBackgroundRewardMonitoring(Map<String, dynamic> profile) {
    final shouldRun =
        AppServices.notificationPreference(
          profile,
          'nearbyRewards',
          defaultValue: true,
        ) &&
        AppServices.notificationPreference(
          profile,
          'backgroundLocationAlerts',
          defaultValue: false,
        );
    if (shouldRun == _backgroundRewardsActive || _backgroundRewardsStarting) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldRun) {
        unawaited(_startBackgroundRewardMonitoring());
      } else {
        unawaited(_stopBackgroundRewardMonitoring());
      }
    });
  }

  Future<void> _startBackgroundRewardMonitoring() async {
    if (_backgroundRewardsActive || _backgroundRewardsStarting) return;
    _backgroundRewardsStarting = true;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always ||
          !await Geolocator.isLocationServiceEnabled()) {
        return;
      }

      final LocationSettings settings;
      if (kIsWeb) {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 150,
        );
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 150,
          intervalDuration: Duration(minutes: 2),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Nearby reward alerts are active',
            notificationText:
                'MyHeritage Explorer is checking for rewards near you.',
            enableWakeLock: false,
            setOngoing: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        settings = AppleSettings(
          accuracy: LocationAccuracy.medium,
          activityType: ActivityType.other,
          distanceFilter: 150,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      } else {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 150,
        );
      }

      await _rewardLocationSubscription?.cancel();
      _rewardLocationSubscription =
          Geolocator.getPositionStream(locationSettings: settings).listen((
            position,
          ) {
            final now = DateTime.now();
            if (_lastBackgroundRewardCheck != null &&
                now.difference(_lastBackgroundRewardCheck!) <
                    const Duration(minutes: 2)) {
              return;
            }
            _lastBackgroundRewardCheck = now;
            unawaited(
              AppServices.checkNearbyRewardNotifications(
                currentPosition: position,
              ).catchError((_) => 0),
            );
          }, onError: (_) {});
      _backgroundRewardsActive = true;
    } finally {
      _backgroundRewardsStarting = false;
    }
  }

  Future<void> _stopBackgroundRewardMonitoring() async {
    await _rewardLocationSubscription?.cancel();
    _rewardLocationSubscription = null;
    _backgroundRewardsActive = false;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;
    if (uid == null) return _buildShell(widget.profile);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppServices.travelerRef(uid).snapshots(),
      builder: (context, snapshot) {
        final liveProfile = snapshot.data?.data();
        final profile = liveProfile == null
            ? widget.profile
            : <String, dynamic>{...widget.profile, ...liveProfile};
        _syncBackgroundRewardMonitoring(profile);
        return _buildShell(profile);
      },
    );
  }

  Widget _buildShell(Map<String, dynamic> profile) {
    final pages = [
      TravelerHomePage(profile: profile),
      const DailyPlannerPage(),
      const CulturalTasksPage(),
      const CompanionPage(),
      TravelerProfilePage(profile: profile),
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
