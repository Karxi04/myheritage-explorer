part of '../traveler_pages.dart';

class SosAlertsReviewPage extends StatefulWidget {
  const SosAlertsReviewPage({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<SosAlertsReviewPage> createState() =>
      _SosAlertsReviewPageState();
}

class _SosAlertsReviewPageState extends State<SosAlertsReviewPage> {
  Position? _leaderPosition;
  StreamSubscription<Position>? _positionSubscription;
  bool _loadingLeaderLocation = true;
  final Set<String> _respondingAlertIds = <String>{};
  final Set<String> _resolvingAlertIds = <String>{};

  @override
  void initState() {
    super.initState();
    _startLeaderLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLeaderLocationTracking() async {
    try {
      final initialPosition = await determinePosition();

      if (!mounted) return;

      setState(() {
        _leaderPosition = initialPosition;
        _loadingLeaderLocation = false;
      });

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
            (position) {
          if (!mounted) return;
          setState(() => _leaderPosition = position);
        },
        onError: (error) {
          debugPrint('Leader GPS stream error: $error');
        },
      );
    } catch (error) {
      debugPrint('Unable to obtain leader location: $error');

      if (!mounted) return;

      setState(() => _loadingLeaderLocation = false);

      showMessage(
        context,
        'Unable to determine your location. '
            'SOS alerts will be ordered by trigger time until GPS is available.',
        error: true,
      );
    }
  }

  GeoPoint? _alertLocation(Map<String, dynamic> data) {
    final location = data['location'];

    if (location is GeoPoint) {
      return location;
    }

    final latitude = data['latitude'];
    final longitude = data['longitude'];

    if (latitude is num && longitude is num) {
      return GeoPoint(
        latitude.toDouble(),
        longitude.toDouble(),
      );
    }

    return null;
  }

  double? _distanceToAlert(Map<String, dynamic> data) {
    final leader = _leaderPosition;
    final location = _alertLocation(data);

    if (leader == null || location == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      leader.latitude,
      leader.longitude,
      location.latitude,
      location.longitude,
    );
  }

  DateTime _alertTime(Map<String, dynamic> data) {
    return asDate(data['lastTriggeredAt']) ??
        asDate(data['timestamp']) ??
        asDate(data['createdAt']) ??
        DateTime.now();
  }

  int _compareAlerts(
      QueryDocumentSnapshot<Map<String, dynamic>> alertA,
      QueryDocumentSnapshot<Map<String, dynamic>> alertB,
      ) {
    final dataA = alertA.data();
    final dataB = alertB.data();

    final distanceA = _distanceToAlert(dataA);
    final distanceB = _distanceToAlert(dataB);

    if (distanceA != null && distanceB != null) {
      final difference = (distanceA - distanceB).abs();

      if (difference > 100) {
        return distanceB.compareTo(distanceA);
      }

      return _alertTime(dataA).compareTo(_alertTime(dataB));
    }

    if (distanceA != null && distanceB == null) {
      return -1;
    }

    if (distanceA == null && distanceB != null) {
      return 1;
    }

    return _alertTime(dataA).compareTo(_alertTime(dataB));
  }

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) {
      return 'Distance unavailable';
    }

    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m away';
    }

    return '${(distanceMeters / 1000).toStringAsFixed(2)} km away';
  }

  Future<String> _myDisplayName() async {
    final user = AppServices.auth.currentUser;
    if (user == null) return 'Group Leader';

    try {
      final profile = await AppServices.travelerRef(user.uid).get();
      final name =
      '${profile.data()?['displayName'] ?? user.displayName ?? ''}'
          .trim();

      if (name.isNotEmpty) return name;
    } catch (_) {}

    return user.displayName ?? 'Group Leader';
  }

  Future<void> _acceptAndFind(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    if (_respondingAlertIds.contains(document.id)) return;

    final user = AppServices.auth.currentUser;
    if (user == null) {
      showMessage(context, 'Please sign in first.', error: true);
      return;
    }

    final data = document.data();
    final location = _alertLocation(data);

    if (location == null) {
      showMessage(
        context,
        'SOS location is unavailable.',
        error: true,
      );
      return;
    }

    final senderName =
        '${data['senderName'] ?? 'Group Member'}';

    setState(() => _respondingAlertIds.add(document.id));

    try {
      final leaderName = await _myDisplayName();

      // Keep status = active. Admin derives RESPONDING from these fields.
      // This prevents the alert from disappearing if leader backs out.
      await document.reference.set(
        {
          'acknowledgedAt': FieldValue.serverTimestamp(),
          'acknowledgedBy': user.uid,
          'acknowledgedByName': leaderName,
          'routeStartedAt': FieldValue.serverTimestamp(),
          'lastResponseAction': 'accept_and_find',
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RouteGuidancePage(
            senderId: '${data['senderId'] ?? ''}',
            senderName: senderName,
            alertId: document.id,
            targetLat: location.latitude,
            targetLng: location.longitude,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Unable to start SOS response: '
              '${error.toString().replaceFirst('Exception: ', '')}',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _respondingAlertIds.remove(document.id));
      }
    }
  }

  Future<void> _resolveAlert(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    if (_resolvingAlertIds.contains(document.id)) return;

    final data = document.data();
    final senderName =
        '${data['senderName'] ?? 'Group Member'}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: ExplorerColors.success,
          size: 40,
        ),
        title: const Text('Mark SOS Resolved?'),
        content: Text(
          'Only resolve the alert after confirming that $senderName '
              'is safe or no longer requires emergency assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ExplorerColors.success,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.task_alt),
            label: const Text('Confirm Resolved'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = AppServices.auth.currentUser;

    if (user == null) {
      showMessage(context, 'Please sign in first.', error: true);
      return;
    }

    setState(() => _resolvingAlertIds.add(document.id));

    try {
      final leaderName = await _myDisplayName();
      final senderId = '${data['senderId'] ?? ''}';
      final groupId = '${data['groupId'] ?? widget.groupId}';

      final batch = AppServices.db.batch();

      batch.update(document.reference, {
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': user.uid,
        'resolvedByName': leaderName,
        'resolutionType': 'leader_manual',
        'resolutionNote':
        'Group leader confirmed that the emergency was handled.',
        'adminOverride': false,
      });

      if (senderId.isNotEmpty && groupId.isNotEmpty) {
        final locationRef = AppServices.db
            .collection('travel_groups')
            .doc(groupId)
            .collection('locations')
            .doc(senderId);

        batch.set(
          locationRef,
          {
            'sosActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (senderId.isNotEmpty) {
        try {
          await AppServices.notify(
            userId: senderId,
            title: 'SOS resolved',
            message:
            '$leaderName marked your SOS alert as resolved.',
            type: 'sos_resolved',
            referenceId: document.id,
            groupId: groupId.isNotEmpty ? groupId : null,
          );
        } catch (error) {
          debugPrint(
            'Unable to send SOS-resolved notification: $error',
          );
        }
      }

      if (mounted) {
        showMessage(context, 'SOS alert marked as resolved.');
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Unable to resolve SOS alert: '
              '${error.toString().replaceFirst('Exception: ', '')}',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _resolvingAlertIds.remove(document.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Emergency SOS Alerts'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ExplorerColors.navySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ExplorerColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.priority_high_rounded,
                  color: ExplorerColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SOS Response Priority',
                        style: TextStyle(
                          color: ExplorerColors.navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _loadingLeaderLocation
                            ? 'Getting your location to calculate priority...'
                            : _leaderPosition == null
                            ? 'GPS unavailable. Alerts are ordered by trigger time.'
                            : 'If distance differs by more than 100 m, '
                            'the farther companion is prioritised first. '
                            'Otherwise, the earlier SOS is prioritised.',
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: AppServices.db
                  .collection('sos_alerts')
                  .where(
                'groupId',
                isEqualTo: widget.groupId,
              )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load SOS alerts.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs.where((document) {
                  final status =
                  '${document.data()['status'] ?? 'active'}'
                      .toLowerCase();
                  return status != 'resolved';
                }).toList();

                docs.sort(_compareAlerts);

                if (docs.isEmpty) {
                  return const ExplorerEmptyState(
                    title: 'No Active Alerts',
                    subtitle:
                    'Everything looks safe. No companions currently have an unresolved SOS.',
                    icon: Icons.security,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    30,
                  ),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final document = docs[index];
                    final data = document.data();

                    final senderName =
                        '${data['senderName'] ?? 'Unknown Member'}';

                    final timestamp = _alertTime(data);
                    final distance = _distanceToAlert(data);
                    final distanceText =
                    _formatDistance(distance);

                    final location = _alertLocation(data);

                    final acknowledgedAt =
                        asDate(data['acknowledgedAt']) ??
                            asDate(data['routeStartedAt']);

                    final responding =
                        acknowledgedAt != null;

                    final triggerCount =
                        (data['triggerCount'] as num?)?.toInt() ?? 1;

                    final busyResponding =
                    _respondingAlertIds.contains(document.id);
                    final busyResolving =
                    _resolvingAlertIds.contains(document.id);

                    return ExplorerCard(
                      backgroundColor: index == 0
                          ? ExplorerColors.dangerSoft
                          : Colors.white,
                      borderColor: index == 0
                          ? ExplorerColors.danger
                          : ExplorerColors.border,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? ExplorerColors.danger
                                      : ExplorerColors.navy,
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Priority ${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              ExplorerStatusBadge(
                                label: responding
                                    ? 'RESPONDING'
                                    : 'ACTIVE',
                                tone: responding
                                    ? ExplorerStatusTone.warning
                                    : ExplorerStatusTone.danger,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: index == 0
                                    ? ExplorerColors.danger
                                    : ExplorerColors.navy,
                                foregroundColor: Colors.white,
                                child: const Icon(
                                  Icons.emergency_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: index == 0
                                            ? ExplorerColors.danger
                                            : ExplorerColors.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      distanceText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: ExplorerColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Triggered ${DateFormat.yMMMd().add_jm().format(timestamp)}'
                                          '${triggerCount > 1 ? ' • $triggerCount triggers' : ''}',
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (responding) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Response started ${DateFormat.jm().format(acknowledgedAt)}',
                                        style: const TextStyle(
                                          color: ExplorerColors.goldDark,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (location != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ExplorerColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    color: ExplorerColors.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      '${location.latitude.toStringAsFixed(6)}, '
                                          '${location.longitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: busyResolving
                                      ? null
                                      : () => _resolveAlert(document),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                    ExplorerColors.success,
                                  ),
                                  icon: busyResolving
                                      ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  label:
                                  const Text('Mark Resolved'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed:
                                  location == null || busyResponding
                                      ? null
                                      : () =>
                                      _acceptAndFind(document),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: index == 0
                                        ? ExplorerColors.danger
                                        : ExplorerColors.navy,
                                  ),
                                  icon: busyResponding
                                      ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child:
                                    CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : const Icon(
                                    Icons.directions_run,
                                  ),
                                  label: Text(
                                    responding
                                        ? 'Continue Finding'
                                        : 'Accept & Find',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
