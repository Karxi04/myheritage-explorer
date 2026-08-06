
part of '../traveler_pages.dart';

class TravelerHomePage extends StatelessWidget {
  const TravelerHomePage({
    super.key,
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;
    final displayName =
        '${profile['displayName'] ?? AppServices.auth.currentUser?.displayName ?? 'Traveler'}';
    final firstName = displayName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyPlannerPage()),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: ExplorerColors.goldSoft,
              foregroundColor: ExplorerColors.goldDark,
              child: Text(
                firstName.isEmpty ? 'T' : firstName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 350)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            Text(
              'Welcome back, $firstName',
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -.45,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Ready to discover something new today?',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ExplorerCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 15,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: ExplorerColors.goldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: ExplorerColors.goldDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ExplorerLabeledValue(
                      label: 'Rank',
                      value: '${profile['rank'] ?? 'Bronze'}',
                      valueColor: ExplorerColors.goldDark,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 42,
                    color: ExplorerColors.border,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: ExplorerLabeledValue(
                      label: 'Local Impact Score',
                      value: '${profile['localImpactScore'] ?? 0} pts',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: .92,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                ExplorerQuickAction(
                  label: 'Daily\nItinerary',
                  icon: Icons.auto_awesome_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DailyPlannerPage()),
                  ),
                ),
                ExplorerQuickAction(
                  label: 'Cultural\nTasks',
                  icon: Icons.workspace_premium_outlined,
                  gold: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CulturalTasksPage(),
                    ),
                  ),
                ),
                ExplorerQuickAction(
                  label: 'Voucher\nWallet',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VoucherWalletPage(),
                    ),
                  ),
                ),
                ExplorerQuickAction(
                  label: 'Report\nHazard',
                  icon: Icons.warning_amber_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SafetyPage()),
                  ),
                ),
                ExplorerQuickAction(
                  label: 'Companion\nTracking',
                  icon: Icons.location_on_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CompanionPage()),
                  ),
                ),
                ExplorerQuickAction(
                  label: 'Ask\nChatbot',
                  icon: Icons.smart_toy_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatbotPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ExplorerSectionTitle(
              'Current Itinerary',
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyItinerariesPage(),
                  ),
                ),
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppServices.db
                  .collection('itineraries')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ExplorerCard(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort(
                    (a, b) => (asDate(b.data()['updatedAt']) ??
                            asDate(b.data()['createdAt']) ??
                            DateTime(2000))
                        .compareTo(
                      asDate(a.data()['updatedAt']) ??
                          asDate(a.data()['createdAt']) ??
                          DateTime(2000),
                    ),
                  );
                if (docs.isEmpty) {
                  return ExplorerCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DailyPlannerPage(),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.route_outlined,
                          color: ExplorerColors.navy,
                          size: 34,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'No itinerary yet. Tap here to generate your first heritage journey.',
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  );
                }
                return _itineraryCard(
                  context,
                  docs.first.id,
                  docs.first.data(),
                );
              },
            ),
            const SizedBox(height: 20),
            const ExplorerSectionTitle('Active Task'),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppServices.db
                  .collection('task_submissions')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ExplorerCard(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort(
                    (a, b) => (asDate(b.data()['createdAt']) ??
                            DateTime(2000))
                        .compareTo(
                      asDate(a.data()['createdAt']) ?? DateTime(2000),
                    ),
                  );
                if (docs.isEmpty) {
                  return ExplorerCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CulturalTasksPage(),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          color: ExplorerColors.navy,
                          size: 32,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Explore cultural tasks and earn impact points.',
                            style: TextStyle(color: ExplorerColors.muted),
                          ),
                        ),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  );
                }
                return _taskCard(context, docs.first.data());
              },
            ),
            const SizedBox(height: 22),
            const ExplorerSectionTitle('Updates for You'),
            const SizedBox(height: 10),
            _updateCard(
              icon: Icons.confirmation_number_outlined,
              iconBackground: ExplorerColors.goldSoft,
              iconColor: ExplorerColors.goldDark,
              title: 'Nearby voucher available',
              subtitle: 'Explore active rewards from verified local vendors.',
              action: 'Claim',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RewardsPage()),
              ),
            ),
            const SizedBox(height: 9),
            _updateCard(
              icon: Icons.cloud_outlined,
              iconBackground: ExplorerColors.navySoft,
              iconColor: ExplorerColors.navy,
              title: 'Weather reminder',
              subtitle: 'Review the latest forecast before outdoor activities.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WeatherReminderPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itineraryCard(
    BuildContext context,
    String itineraryId,
    Map<String, dynamic> data,
  ) {
    final stops = List<Map<String, dynamic>>.from(data['stops'] ?? const []);
    final firstStop = stops.isEmpty ? null : stops.first;
    return ExplorerCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItineraryEditPage(
            itineraryId: itineraryId,
            itinerary: data,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 128,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: ExplorerColors.navySoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Stack(
              children: [
                Positioned.fill(
                  child: Icon(
                    Icons.account_balance_outlined,
                    size: 72,
                    color: Color(0xFF9EB1CC),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 10,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.arrow_forward,
                      color: ExplorerColors.navy,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExplorerStatusBadge(
                  label: 'CURRENT',
                  tone: ExplorerStatusTone.navy,
                ),
                const SizedBox(height: 10),
                Text(
                  '${data['title'] ?? firstStop?['name'] ?? 'Saved Itinerary'}',
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['area'] ?? firstStop?['area'] ?? ''}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 15,
                      color: ExplorerColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${data['availableHours'] ?? '-'} hours',
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${stops.length} stops',
                      style: const TextStyle(
                        color: ExplorerColors.goldDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final status = '${data['status'] ?? 'pending'}';
    final tone = status == 'approved'
        ? ExplorerStatusTone.success
        : status == 'rejected'
            ? ExplorerStatusTone.danger
            : ExplorerStatusTone.warning;
    return ExplorerCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CulturalTasksPage()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExplorerStatusBadge(
                label: status.toUpperCase(),
                tone: tone,
              ),
              const Spacer(),
              Text(
                '+${data['rewardPoints'] ?? 0} pts',
                style: const TextStyle(
                  color: ExplorerColors.goldDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${data['taskTitle'] ?? 'Cultural Task'}',
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${data['expectedCategory'] ?? 'Complete your cultural experience and submit proof.'}',
            style: const TextStyle(
              color: ExplorerColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: status == 'approved' ? 1 : .6,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: ExplorerColors.subtle,
            valueColor: const AlwaysStoppedAnimation(ExplorerColors.navy),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CulturalTasksPage(),
                ),
              ),
              child: const Text('Continue Task'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _updateCard({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? action,
  }) {
    return ExplorerCard(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Text(
              action,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            const Icon(
              Icons.chevron_right,
              color: ExplorerColors.muted,
            ),
        ],
      ),
    );
  }
}
