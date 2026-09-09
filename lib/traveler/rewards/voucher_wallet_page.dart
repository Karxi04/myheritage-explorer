part of '../traveler_pages.dart';

class VoucherWalletPage extends StatefulWidget {
  const VoucherWalletPage({super.key, this.focusClaimId});

  final String? focusClaimId;

  @override
  State<VoucherWalletPage> createState() => _VoucherWalletPageState();
}

class _VoucherWalletPageState extends State<VoucherWalletPage> {
  String filter = 'All';
  final Set<String> startingSessions = <String>{};
  final Set<String> loadingDirections = <String>{};
  final Map<String, GeoPoint> resolvedVoucherLocations = <String, GeoPoint>{};
  late final String uid;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> travelerStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> claimedVouchersStream;

  @override
  void initState() {
    super.initState();
    uid = AppServices.auth.currentUser!.uid;
    travelerStream = AppServices.travelerRef(uid).snapshots();
    claimedVouchersStream = AppServices.db
        .collection('claimed_vouchers')
        .where('userId', isEqualTo: uid)
        .limit(AppServices.rewardPageReadLimit)
        .snapshots();
  }

  String _redemptionSessionError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final normalized = message.toLowerCase();
    if (normalized.contains('resource-exhausted') ||
        normalized.contains('quota exceeded') ||
        normalized.contains('quota reached')) {
      return 'Firebase has reached its request quota, so a new QR code and PIN cannot be saved right now. Your voucher is safe. Please try again after the quota resets or ask the project administrator to check Firebase usage.';
    }
    return message;
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
        showMessage(context, _redemptionSessionError(error), error: true);
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

  Future<void> _openVoucherDirections({
    required String claimId,
    required String voucherId,
    required String voucherTitle,
    required String vendorName,
    required String vendorAddress,
    GeoPoint? claimLocation,
  }) async {
    if (loadingDirections.contains(claimId)) return;

    var location = claimLocation ?? resolvedVoucherLocations[voucherId];
    if (location == null && voucherId.isNotEmpty) {
      setState(() => loadingDirections.add(claimId));
      try {
        final voucherSnapshot = await AppServices.db
            .collection('vouchers')
            .doc(voucherId)
            .get();
        final legacyLocation = voucherSnapshot.data()?['location'];
        if (legacyLocation is GeoPoint) {
          location = legacyLocation;
          resolvedVoucherLocations[voucherId] = legacyLocation;
        }
      } catch (error) {
        if (mounted) {
          showMessage(
            context,
            'The vendor location could not be loaded. Please check your connection and try again.',
            error: true,
          );
        }
        return;
      } finally {
        if (mounted) setState(() => loadingDirections.remove(claimId));
      }
    }

    if (!mounted) return;
    if (location == null) {
      showMessage(
        context,
        'This voucher does not have a vendor map location yet.',
        error: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClaimedVoucherDirectionsPage(
          voucherTitle: voucherTitle,
          vendorName: vendorName,
          vendorAddress: vendorAddress,
          vendorLocation: location!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              stream: travelerStream,
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
                  _buildClaimedVouchers(),
                  const RewardsPage(embedded: true, showPointsSummary: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimedVouchers() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: claimedVouchersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return emptyState('Unable to load your voucher wallet');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs.toList();
        var focusedClaimId = widget.focusClaimId?.trim();
        if (focusedClaimId != null &&
            focusedClaimId.isNotEmpty &&
            !allDocs.any((doc) => doc.id == focusedClaimId)) {
          final legacyMatches =
              allDocs
                  .where(
                    (doc) =>
                        '${doc.data()['voucherId'] ?? ''}' == focusedClaimId,
                  )
                  .toList()
                ..sort(
                  (a, b) => (asDate(b.data()['claimedAt']) ?? DateTime(2000))
                      .compareTo(
                        asDate(a.data()['claimedAt']) ?? DateTime(2000),
                      ),
                );
          if (legacyMatches.isNotEmpty) focusedClaimId = legacyMatches.first.id;
        }
        allDocs.sort((a, b) {
          final aIsFocused = a.id == focusedClaimId;
          final bIsFocused = b.id == focusedClaimId;
          if (aIsFocused != bIsFocused) return aIsFocused ? -1 : 1;
          return (asDate(b.data()['claimedAt']) ?? DateTime(2000)).compareTo(
            asDate(a.data()['claimedAt']) ?? DateTime(2000),
          );
        });
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
                final voucherId = '${claim['voucherId'] ?? ''}'.trim();
                final effectiveLocation = location is GeoPoint
                    ? location
                    : resolvedVoucherLocations[voucherId];
                final loadingDirection = loadingDirections.contains(doc.id);
                final voucherTitle = '${claim['title'] ?? 'Voucher'}';
                final vendorName =
                    '${claim['vendorName'] ?? 'Registered vendor'}';
                final locationLabel = vendorAddress.isNotEmpty
                    ? vendorAddress
                    : effectiveLocation is GeoPoint
                    ? '${effectiveLocation.latitude.toStringAsFixed(5)}, ${effectiveLocation.longitude.toStringAsFixed(5)}'
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
                        key: PageStorageKey('claimed-voucher-${doc.id}'),
                        initiallyExpanded: doc.id == focusedClaimId,
                        leading: const CircleAvatar(
                          backgroundColor: ExplorerColors.goldSoft,
                          foregroundColor: ExplorerColors.goldDark,
                          child: Icon(Icons.confirmation_number_outlined),
                        ),
                        title: Text(voucherTitle),
                        subtitle: Text(
                          '$vendorName - ${claim['pointCost'] ?? 0} points',
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
                          if (status == 'Active' &&
                              (voucherId.isNotEmpty ||
                                  effectiveLocation is GeoPoint)) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: loadingDirection
                                    ? null
                                    : () => _openVoucherDirections(
                                        claimId: doc.id,
                                        voucherId: voucherId,
                                        voucherTitle: voucherTitle,
                                        vendorName: vendorName,
                                        vendorAddress: vendorAddress,
                                        claimLocation: effectiveLocation,
                                      ),
                                icon: loadingDirection
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.map_outlined),
                                label: const Text(
                                  'View Vendor Map & Walking Directions',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
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
                                  _RedemptionSessionCountdown(
                                    expiry: sessionExpiry,
                                    onExpired: () {
                                      if (mounted) setState(() {});
                                    },
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

class _RedemptionSessionCountdown extends StatefulWidget {
  const _RedemptionSessionCountdown({
    required this.expiry,
    required this.onExpired,
  });

  final DateTime expiry;
  final VoidCallback onExpired;

  @override
  State<_RedemptionSessionCountdown> createState() =>
      _RedemptionSessionCountdownState();
}

class _RedemptionSessionCountdownState
    extends State<_RedemptionSessionCountdown> {
  Timer? timer;
  bool expiryReported = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _RedemptionSessionCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiry != widget.expiry) {
      expiryReported = false;
      _startTimer();
    }
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  void _tick() {
    if (!mounted) return;
    final expired = !widget.expiry.isAfter(DateTime.now());
    if (expired) timer?.cancel();
    setState(() {});
    if (expired && !expiryReported) {
      expiryReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpired();
      });
    }
  }

  String get label {
    final remaining = widget.expiry.difference(DateTime.now());
    if (remaining <= Duration.zero) return 'Code expired';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60);
    return 'Code expires in $minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerStatusBadge(
      label: label,
      tone: ExplorerStatusTone.danger,
      icon: Icons.timer_outlined,
    );
  }
}

class _ClaimedVoucherDirectionsPage extends StatefulWidget {
  const _ClaimedVoucherDirectionsPage({
    required this.voucherTitle,
    required this.vendorName,
    required this.vendorAddress,
    required this.vendorLocation,
  });

  final String voucherTitle;
  final String vendorName;
  final String vendorAddress;
  final GeoPoint vendorLocation;

  @override
  State<_ClaimedVoucherDirectionsPage> createState() =>
      _ClaimedVoucherDirectionsPageState();
}

class _ClaimedVoucherDirectionsPageState
    extends State<_ClaimedVoucherDirectionsPage> {
  Position? travelerPosition;
  GoogleMapController? mapController;
  bool loadingPosition = true;
  String? positionError;

  LatLng get vendorLatLng =>
      LatLng(widget.vendorLocation.latitude, widget.vendorLocation.longitude);

  @override
  void initState() {
    super.initState();
    unawaited(_loadTravelerPosition());
  }

  Future<void> _loadTravelerPosition() async {
    try {
      final position = await determinePosition();
      if (!mounted) return;
      setState(() {
        travelerPosition = position;
        loadingPosition = false;
      });
      _fitMapToRoute();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingPosition = false;
        positionError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _fitMapToRoute() {
    final controller = mapController;
    final traveler = travelerPosition;
    if (controller == null || traveler == null) return;

    final travelerLatLng = LatLng(traveler.latitude, traveler.longitude);
    final latitudeDifference = (travelerLatLng.latitude - vendorLatLng.latitude)
        .abs();
    final longitudeDifference =
        (travelerLatLng.longitude - vendorLatLng.longitude).abs();
    final CameraUpdate cameraUpdate;
    if (latitudeDifference < 0.0001 && longitudeDifference < 0.0001) {
      cameraUpdate = CameraUpdate.newLatLngZoom(vendorLatLng, 17);
    } else {
      cameraUpdate = CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            min(travelerLatLng.latitude, vendorLatLng.latitude),
            min(travelerLatLng.longitude, vendorLatLng.longitude),
          ),
          northeast: LatLng(
            max(travelerLatLng.latitude, vendorLatLng.latitude),
            max(travelerLatLng.longitude, vendorLatLng.longitude),
          ),
        ),
        64,
      );
    }
    unawaited(controller.animateCamera(cameraUpdate).catchError((_) {}));
  }

  Future<void> _openWalkingDirections() async {
    final traveler = travelerPosition;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (traveler != null)
        'origin': '${traveler.latitude},${traveler.longitude}',
      'destination':
          '${widget.vendorLocation.latitude},${widget.vendorLocation.longitude}',
      'travelmode': 'walking',
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showMessage(context, 'Unable to open walking directions.', error: true);
    }
  }

  String get distanceMessage {
    final traveler = travelerPosition;
    if (traveler == null) {
      return 'Distance is provided for guidance only and never blocks voucher redemption.';
    }
    final distance = Geolocator.distanceBetween(
      traveler.latitude,
      traveler.longitude,
      widget.vendorLocation.latitude,
      widget.vendorLocation.longitude,
    );
    final distanceLabel = distance < 1000
        ? '${distance.round()} m away'
        : '${(distance / 1000).toStringAsFixed(1)} km away';
    if (distance <= AppServices.nearbyRewardRadiusMeters) {
      return '$distanceLabel - within the standard ${AppServices.nearbyRewardRadiusMeters.round()} m nearby area. Distance does not restrict redemption.';
    }
    return '$distanceLabel - outside the nearby area, but you can still travel there and redeem the voucher.';
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final traveler = travelerPosition;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('voucher-vendor'),
        position: vendorLatLng,
        infoWindow: InfoWindow(
          title: widget.vendorName,
          snippet: widget.voucherTitle,
        ),
      ),
      if (traveler != null)
        Marker(
          markerId: const MarkerId('traveler'),
          position: LatLng(traveler.latitude, traveler.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Your location'),
        ),
    };

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Voucher Directions')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: ExplorerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.voucherTitle,
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.vendorName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (widget.vendorAddress.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.vendorAddress,
                        style: const TextStyle(color: ExplorerColors.muted),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.directions_walk,
                          color: ExplorerColors.navy,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loadingPosition
                                ? 'Finding your current location...'
                                : positionError == null
                                ? distanceMessage
                                : 'Your location is unavailable. You can still open directions to the vendor.',
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: vendorLatLng,
                    zoom: 15,
                  ),
                  markers: markers,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  onMapCreated: (controller) {
                    mapController = controller;
                    _fitMapToRoute();
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openWalkingDirections,
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Open Walking Directions'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
