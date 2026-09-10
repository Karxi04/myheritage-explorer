part of '../traveler_pages.dart';

class RewardNotificationSettingsPage extends StatelessWidget {
  const RewardNotificationSettingsPage({super.key});

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
          error.toString().replaceFirst('Exception: ', ''),
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
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
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
