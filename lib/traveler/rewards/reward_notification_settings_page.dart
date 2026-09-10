part of '../traveler_pages.dart';

class RewardNotificationSettingsPage extends StatefulWidget {
  const RewardNotificationSettingsPage({super.key});

  @override
  State<RewardNotificationSettingsPage> createState() =>
      _RewardNotificationSettingsPageState();
}

class _RewardNotificationSettingsPageState
    extends State<RewardNotificationSettingsPage> {
  bool checkingNearbyRewards = false;

  Future<void> _setPreference(
    BuildContext context,
    String key,
    bool value,
  ) async {
    try {
      await AppServices.setNotificationPreference(key, value);
      if (key == 'expiryReminders') {
        await AppServices.syncVoucherExpiryReminders();
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          rewardModuleErrorMessage(
            error,
            fallback:
                'Your reward notification preference could not be saved. Please try again.',
          ),
          error: true,
        );
      }
    }
  }

  Future<void> _setBackgroundMonitoring(
    BuildContext context,
    bool enabled,
  ) async {
    if (!enabled) {
      await _setPreference(context, 'backgroundLocationAlerts', false);
      return;
    }

    try {
      final permission = await AppServices.requestBackgroundLocationAccess();
      if (permission != LocationPermission.always) {
        if (!context.mounted) return;
        final openSettings =
            await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Allow background location'),
                content: const Text(
                  'Choose "Allow all the time" in the app location settings. This is required to check for nearby rewards while the screen is off or another app is open.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Not now'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ) ??
            false;
        if (openSettings) await Geolocator.openAppSettings();
        return;
      }
      if (!context.mounted) return;
      await _setPreference(context, 'backgroundLocationAlerts', true);
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          rewardModuleErrorMessage(
            error,
            fallback:
                'Background nearby alerts could not be enabled. Check location permission and try again.',
          ),
          error: true,
        );
      }
    }
  }

  Future<void> _checkNearbyRewardsNow(BuildContext context) async {
    if (checkingNearbyRewards) return;
    setState(() => checkingNearbyRewards = true);
    try {
      final notificationsEnabled = await SystemNotificationService.instance
          .areNotificationsEnabled();
      if (!notificationsEnabled) {
        if (!context.mounted) return;
        final openSettings =
            await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Allow phone notifications'),
                content: const Text(
                  'Phone notifications are turned off for MyHeritage Explorer. Allow notifications in your phone settings, then run this check again.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Not now'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ) ??
            false;
        if (openSettings) await Geolocator.openAppSettings();
        return;
      }

      final result = await AppServices.checkNearbyRewardNotifications(
        requestPermission: true,
        force: true,
      );
      if (!context.mounted) return;
      showMessage(
        context,
        result > 0
            ? 'Nearby reward alert sent. Check your phone notification panel and tap the alert to open the voucher.'
            : 'No active vouchers were found within 750 metres. Check that the vendor saved the correct map location and that the voucher has inventory remaining.',
        error: result == 0,
      );
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          rewardModuleErrorMessage(
            error,
            fallback:
                'The nearby reward check could not finish. Check location access and your internet connection, then try again.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => checkingNearbyRewards = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Reward Notifications')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppServices.travelerRef(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ExplorerEmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Notification settings are unavailable',
              subtitle: rewardModuleErrorMessage(
                snapshot.error!,
                fallback:
                    'Your reward notification settings could not be loaded. Check your connection and try again.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!.data();
          final nearby = AppServices.notificationPreference(
            profile,
            'nearbyRewards',
            defaultValue: true,
          );
          final expiry = AppServices.notificationPreference(
            profile,
            'expiryReminders',
            defaultValue: true,
          );
          final updates = AppServices.notificationPreference(
            profile,
            'rewardUpdates',
            defaultValue: true,
          );
          final background = AppServices.notificationPreference(
            profile,
            'backgroundLocationAlerts',
            defaultValue: false,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ExplorerCard(
                backgroundColor: ExplorerColors.navySoft,
                borderColor: const Color(0xFFC8D6EA),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: ExplorerColors.navy,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.notifications_active_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Stay updated on your rewards',
                            style: TextStyle(
                              color: ExplorerColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${[nearby, expiry, updates].where((item) => item).length} of 3 reward alert types enabled',
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const ExplorerSectionTitle(
                'Reward alerts',
                subtitle: 'Choose the updates that are useful to you.',
              ),
              const SizedBox(height: 10),
              ExplorerCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: nearby,
                      title: const Text('Nearby rewards'),
                      subtitle: const Text(
                        'Check every 10 minutes and alert me when an active reward is within 750 metres.',
                      ),
                      secondary: const Icon(Icons.near_me_outlined),
                      onChanged: (value) =>
                          _setPreference(context, 'nearbyRewards', value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: expiry,
                      title: const Text('Expiry reminders'),
                      subtitle: const Text(
                        'Remind me three days and one day before expiry.',
                      ),
                      secondary: const Icon(Icons.timer_outlined),
                      onChanged: (value) =>
                          _setPreference(context, 'expiryReminders', value),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: updates,
                      title: const Text('Claim and redemption updates'),
                      subtitle: const Text(
                        'Confirm when a voucher is claimed or redeemed.',
                      ),
                      secondary: const Icon(Icons.redeem_outlined),
                      onChanged: (value) =>
                          _setPreference(context, 'rewardUpdates', value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: nearby && !checkingNearbyRewards
                      ? () => _checkNearbyRewardsNow(context)
                      : null,
                  icon: checkingNearbyRewards
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    checkingNearbyRewards
                        ? 'Checking your location...'
                        : 'Check Nearby Rewards Now',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use this before your demo to confirm location access, eligible vouchers, and phone notification delivery.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              const ExplorerSectionTitle(
                'Background location',
                subtitle:
                    'Optional monitoring for nearby offers while using other apps.',
              ),
              const SizedBox(height: 10),
              ExplorerCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  value: background,
                  title: const Text('Background nearby alerts'),
                  subtitle: Text(
                    nearby
                        ? 'Requires “Allow all the time”. Android shows a persistent location notification while active.'
                        : 'Turn on Nearby rewards above to enable this option.',
                  ),
                  secondary: Icon(
                    background
                        ? Icons.location_searching
                        : Icons.location_disabled_outlined,
                  ),
                  onChanged: nearby
                      ? (value) => _setBackgroundMonitoring(context, value)
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
