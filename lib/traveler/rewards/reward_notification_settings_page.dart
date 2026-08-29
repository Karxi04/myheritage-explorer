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
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Control which reward alerts you receive. Background monitoring is optional and can be disabled at any time.',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: nearby,
                title: const Text('Nearby rewards'),
                subtitle: const Text(
                  'Notify me when an active reward is close to my location.',
                ),
                secondary: const Icon(Icons.near_me_outlined),
                onChanged: (value) =>
                    _setPreference(context, 'nearbyRewards', value),
              ),
              SwitchListTile(
                value: expiry,
                title: const Text('Voucher expiry reminders'),
                subtitle: const Text(
                  'Remind me three days and one day before a claimed voucher expires.',
                ),
                secondary: const Icon(Icons.timer_outlined),
                onChanged: (value) =>
                    _setPreference(context, 'expiryReminders', value),
              ),
              SwitchListTile(
                value: updates,
                title: const Text('Claim and redemption updates'),
                subtitle: const Text(
                  'Show confirmations when vouchers are claimed or redeemed.',
                ),
                secondary: const Icon(Icons.redeem_outlined),
                onChanged: (value) =>
                    _setPreference(context, 'rewardUpdates', value),
              ),
              const Divider(height: 30),
              SwitchListTile(
                value: background,
                title: const Text('Background nearby alerts'),
                subtitle: const Text(
                  'Keep checking for nearby rewards while the screen is off. Android displays a persistent location notification while this is active.',
                ),
                secondary: const Icon(Icons.location_searching),
                onChanged: nearby
                    ? (value) => _setBackgroundMonitoring(context, value)
                    : null,
              ),
              if (!nearby)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Enable Nearby rewards before turning on background monitoring.',
                    style: TextStyle(color: ExplorerColors.muted),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
