part of '../traveler_pages.dart';

class VoucherWalletPage extends StatefulWidget {
  const VoucherWalletPage({super.key});

  @override
  State<VoucherWalletPage> createState() => _VoucherWalletPageState();
}

class _VoucherWalletPageState extends State<VoucherWalletPage> {
  String filter = 'All';
  final Set<String> startingSessions = <String>{};
  Timer? sessionTicker;

  @override
  void initState() {
    super.initState();
    unawaited(AppServices.syncVoucherExpiryReminders());
    sessionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    sessionTicker?.cancel();
    super.dispose();
  }

  String _sessionCountdown(DateTime expiry) {
    final remaining = expiry.difference(DateTime.now());
    if (remaining <= Duration.zero) return 'Code expired';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return 'Code expires in $minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startRedemptionSession(String claimId) async {
    if (startingSessions.contains(claimId)) return;
    setState(() => startingSessions.add(claimId));
    try {
      await AppServices.startRedemptionSession(claimId);
      if (mounted) {
        showMessage(context, 'A new QR code and PIN are active for 3 minutes.');
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => startingSessions.remove(claimId));
    }
  }

  String _displayStatus(Map<String, dynamic> claim) {
    if (claim['status'] == 'redeemed') return 'Redeemed';
    final expiry = asDate(claim['expiresAt']);
    if (expiry != null && !expiry.isAfter(DateTime.now())) return 'Expired';
    if (claim['status'] == 'claimed') return 'Active';
    final raw = '${claim['status'] ?? 'Unavailable'}';
    return raw.isEmpty
        ? 'Unavailable'
        : '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  ExplorerStatusTone _statusTone(String status) => switch (status) {
    'Active' => ExplorerStatusTone.success,
    'Redeemed' => ExplorerStatusTone.navy,
    'Expired' => ExplorerStatusTone.danger,
    _ => ExplorerStatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Digital Wallet'),
          actions: [
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RewardNotificationSettingsPage(),
                ),
              ),
              icon: const Icon(Icons.notifications_active_outlined),
              tooltip: 'Reward notification settings',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Claimed Vouchers'),
              Tab(text: 'Available Rewards'),
            ],
          ),
        ),
        body: Column(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AppServices.travelerRef(uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Card(
                      child: ListTile(
                        leading: Icon(Icons.cloud_off_outlined),
                        title: Text('Unable to load wallet data'),
                        subtitle: Text('Please check your connection.'),
                      ),
                    ),
                  );
                }

                final points =
                    (snapshot.data?.data()?['points'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: ExplorerCard(
                    backgroundColor: ExplorerColors.navy,
                    borderColor: ExplorerColors.navy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: ExplorerColors.goldSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            color: ExplorerColors.goldDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available balance',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Ready to spend on rewards',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        snapshot.hasData
                            ? Text(
                                '$points pts',
                                style: const TextStyle(
                                  color: ExplorerColors.gold,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildClaimedVouchers(uid),
                  const RewardsPage(embedded: true, showPointsSummary: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimedVouchers(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('claimed_vouchers')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return emptyState('Unable to load your voucher wallet');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => (asDate(b.data()['claimedAt']) ?? DateTime(2000))
                .compareTo(asDate(a.data()['claimedAt']) ?? DateTime(2000)),
          );
        final docs = allDocs.where((doc) {
          return filter == 'All' || _displayStatus(doc.data()) == filter;
        }).toList();
        final statusCounts = <String, int>{
          for (final item in ['Active', 'Redeemed', 'Expired'])
            item: allDocs
                .where((doc) => _displayStatus(doc.data()) == item)
                .length,
        };

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            const ExplorerSectionTitle(
              'Your vouchers',
              subtitle:
                  'Open an active voucher when you are ready to redeem it.',
            ),
            const SizedBox(height: 12),
            const ExplorerCard(
              backgroundColor: ExplorerColors.navySoft,
              borderColor: Color(0xFFC8D6EA),
              padding: EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_clock_outlined, color: ExplorerColors.navy),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'At the vendor, generate a temporary QR code or PIN. It stays active for 3 minutes for safer redemption.',
                      style: TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Active', 'Redeemed', 'Expired']
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            '$item ${item == 'All' ? allDocs.length : statusCounts[item] ?? 0}',
                          ),
                          selected: filter == item,
                          onSelected: (_) => setState(() => filter = item),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 44),
                child: emptyState(
                  allDocs.isEmpty
                      ? 'No claimed vouchers'
                      : 'No $filter vouchers',
                ),
              )
            else
              ...docs.map((doc) {
                final claim = doc.data();
                final status = _displayStatus(claim);
                final claimedAt = asDate(claim['claimedAt']);
                final redeemedAt = asDate(claim['redeemedAt']);
                final expiry = asDate(claim['expiresAt']);
                final sessionToken = '${claim['redemptionSessionToken'] ?? ''}'
                    .trim();
                final sessionPin = '${claim['redemptionSessionPin'] ?? ''}'
                    .trim();
                final sessionExpiry = asDate(
                  claim['redemptionSessionExpiresAt'],
                );
                final sessionActive =
                    status == 'Active' &&
                    sessionToken.isNotEmpty &&
                    sessionPin.isNotEmpty &&
                    sessionExpiry != null &&
                    sessionExpiry.isAfter(DateTime.now());
                final startingSession = startingSessions.contains(doc.id);
                final vendorAddress = '${claim['vendorAddress'] ?? ''}'.trim();
                final location = claim['location'];
                final locationLabel = vendorAddress.isNotEmpty
                    ? vendorAddress
                    : location is GeoPoint
                    ? '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'
                    : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ExplorerCard(
                    padding: EdgeInsets.zero,
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: const CircleAvatar(
                          backgroundColor: ExplorerColors.goldSoft,
                          foregroundColor: ExplorerColors.goldDark,
                          child: Icon(Icons.confirmation_number_outlined),
                        ),
                        title: Text('${claim['title'] ?? 'Voucher'}'),
                        subtitle: Text(
                          '${claim['vendorName'] ?? 'Registered vendor'} - ${claim['pointCost'] ?? 0} points',
                        ),
                        trailing: ExplorerStatusBadge(
                          label: status.toUpperCase(),
                          tone: _statusTone(status),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          18,
                          0,
                          18,
                          18,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ('${claim['description'] ?? ''}'.trim().isNotEmpty)
                            Text('${claim['description']}'),
                          if (locationLabel.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Vendor location: $locationLabel'),
                          ],
                          if ('${claim['terms'] ?? ''}'.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Terms: ${claim['terms']}',
                              style: const TextStyle(
                                color: ExplorerColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            [
                              if (claimedAt != null)
                                'Claimed ${DateFormat.yMMMd().add_jm().format(claimedAt)}',
                              if (expiry != null)
                                '${expiryCountdownLabel(expiry)} (${DateFormat.yMMMd().add_jm().format(expiry)})',
                              if (redeemedAt != null)
                                'Redeemed ${DateFormat.yMMMd().add_jm().format(redeemedAt)}',
                            ].join('\n'),
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (status == 'Active' && !sessionActive)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: startingSession
                                    ? null
                                    : () => _startRedemptionSession(doc.id),
                                icon: startingSession
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.qr_code_2),
                                label: Text(
                                  sessionExpiry != null
                                      ? 'Generate New 3-Minute Code'
                                      : 'Generate 3-Minute Redemption Code',
                                ),
                              ),
                            )
                          else if (sessionActive) ...[
                            ExplorerCard(
                              backgroundColor: ExplorerColors.goldSoft,
                              borderColor: ExplorerColors.gold,
                              child: Column(
                                children: [
                                  const Text(
                                    'Show this temporary code to the vendor',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ExplorerColors.navy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  ExplorerStatusBadge(
                                    label: _sessionCountdown(sessionExpiry),
                                    tone: ExplorerStatusTone.danger,
                                    icon: Icons.timer_outlined,
                                  ),
                                  const SizedBox(height: 10),
                                  QrImageView(
                                    data: 'MHE1|${doc.id}|$sessionToken',
                                    size: 210,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Or tell the vendor this 6-digit PIN',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 5),
                                  SelectableText(
                                    sessionPin,
                                    style: const TextStyle(
                                      color: ExplorerColors.navy,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton.icon(
                                    onPressed: startingSession
                                        ? null
                                        : () => _startRedemptionSession(doc.id),
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Replace this code'),
                                  ),
                                ],
                              ),
                            ),
                          ] else
                            Center(
                              child: Text(
                                status == 'Redeemed'
                                    ? 'This voucher has already been redeemed.'
                                    : status == 'Expired'
                                    ? 'This voucher expired before redemption.'
                                    : 'This voucher is unavailable.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
