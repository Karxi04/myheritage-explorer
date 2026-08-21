part of '../traveler_pages.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key});

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}



class _CompanionPageState extends State<CompanionPage> {
  final Set<String> _sendingSosGroupIds = <String>{};
  final Set<String> _respondingInvitationIds = <String>{};

// Live member location
  StreamSubscription<Position>? _liveLocationSubscription;

// Real-time SOS listener for leader
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _leaderSosSubscription;

  // Real-time private location request listener
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _privateLocationRequestSubscription;

// Prevent the same request from popping up repeatedly
  final Set<String> _handledPrivateLocationRequestIds =
  <String>{};

// Queue location requests if multiple users request at once
  final List<DocumentSnapshot<Map<String, dynamic>>>
  _pendingPrivateLocationRequests =
  <DocumentSnapshot<Map<String, dynamic>>>[];

  bool _showingPrivateLocationRequest = false;

// Prevent same SOS trigger from showing repeatedly
  final Set<String> _handledSosEvents = <String>{};

// Queue multiple SOS alerts
  final List<DocumentSnapshot<Map<String, dynamic>>>
  _pendingLeaderSosAlerts = [];

  bool _showingSosPopup = false;
  bool _liveSharingStarted = false;
  String? _cachedDisplayName;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeLiveLocationSharingIfEnabled();

      // Listen for SOS alerts sent to this user
      _startLeaderSosListener();

      _startPrivateLocationRequestListener();
    });
  }

  @override
  void dispose() {
    _liveLocationSubscription?.cancel();
    _leaderSosSubscription?.cancel();

    super.dispose();

    _privateLocationRequestSubscription?.cancel();
  }

  Future<void> _showMembersList(
      BuildContext context,
      Map<String, dynamic> group,
      ) async {
    final currentUid =
        AppServices.auth.currentUser?.uid;

    if (currentUid == null) return;

    final memberIds = List<String>.from(
      group['memberIds'] ?? const <String>[],
    );

    final memberNames = Map<String, dynamic>.from(
      group['memberNames'] ??
          const <String, dynamic>{},
    );

    final leaderId =
        '${group['leaderId'] ?? ''}';

    final groupName =
        '${group['name'] ?? 'Travel Group'}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.90,
          expand: false,
          builder: (
              context,
              scrollController,
              ) {
            return Container(
              decoration: const BoxDecoration(
                color: ExplorerColors.background,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ExplorerColors.border,
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 18,
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor:
                          ExplorerColors.navySoft,
                          foregroundColor:
                          ExplorerColors.navy,
                          child: Icon(
                            Icons.groups_outlined,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                groupName,
                                style: const TextStyle(
                                  color:
                                  ExplorerColors.navy,
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${memberIds.length} member${memberIds.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color:
                                  ExplorerColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                            );
                          },
                          icon: const Icon(
                            Icons.close,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Divider(height: 1),

                  Expanded(
                    child: ListView.separated(
                      controller:
                      scrollController,
                      padding:
                      const EdgeInsets.all(16),
                      itemCount:
                      memberIds.length,
                      separatorBuilder:
                          (_, _) =>
                      const SizedBox(
                        height: 9,
                      ),
                      itemBuilder:
                          (context, index) {
                        final memberId =
                        memberIds[index];

                        final isLeader =
                            memberId ==
                                leaderId;

                        final isCurrentUser =
                            memberId ==
                                currentUid;

                        var memberName =
                        '${memberNames[memberId] ?? ''}'
                            .trim();

                        if (memberName.isEmpty) {
                          memberName =
                          isCurrentUser
                              ? 'You'
                              : 'Group Member';
                        }

                        return ExplorerCard(
                          radius: 12,
                          child: ListTile(
                            contentPadding:
                            EdgeInsets.zero,

                            leading:
                            CircleAvatar(
                              backgroundColor:
                              isLeader
                                  ? ExplorerColors
                                  .goldSoft
                                  : ExplorerColors
                                  .navySoft,
                              foregroundColor:
                              ExplorerColors
                                  .navy,
                              child: Icon(
                                isLeader
                                    ? Icons
                                    .workspace_premium_outlined
                                    : Icons
                                    .person_outline,
                              ),
                            ),

                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    memberName,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                    style:
                                    const TextStyle(
                                      color:
                                      ExplorerColors
                                          .navy,
                                      fontWeight:
                                      FontWeight
                                          .w800,
                                    ),
                                  ),
                                ),

                                if (isCurrentUser) ...[
                                  const SizedBox(
                                    width: 6,
                                  ),
                                  const Text(
                                    '(You)',
                                    style:
                                    TextStyle(
                                      color:
                                      ExplorerColors
                                          .muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            subtitle: Text(
                              isLeader
                                  ? 'Group Leader'
                                  : 'Group Member',
                            ),

                            // READ-ONLY:
                            // no remove / edit button.
                            trailing: isCurrentUser
                                ? null
                                : OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();

                                Future.microtask(() {
                                  if (!mounted) return;

                                  openCompanionPrivateChat(
                                    this.context,
                                    otherUserId: memberId,
                                    otherUserName: memberName,
                                  );
                                });
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                              ),
                              label: const Text(
                                'Message',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startLeaderSosListener() {
    final user = AppServices.auth.currentUser;

    if (user == null) return;

    _leaderSosSubscription?.cancel();

    _leaderSosSubscription = AppServices.db
        .collection('sos_alerts')
        .where(
      'leaderId',
      isEqualTo: user.uid,
    )
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              final document = change.doc;

              final data =
                  document.data() ??
                      const <String, dynamic>{};

              // Only active SOS alerts
              if (data['status'] != 'active') {
            continue;
          }

          final senderId =
              '${data['senderId'] ?? ''}';

          // Leader should never receive own SOS
          if (senderId == user.uid) {
            continue;
          }

          final triggerCount =
              (data['triggerCount'] as num?)
                  ?.toInt() ??
                  1;

          // One popup for each SOS trigger
          final eventKey =
              '${document.id}:$triggerCount';

          if (_handledSosEvents.contains(
            eventKey,
          )) {
            continue;
          }

          _handledSosEvents.add(
            eventKey,
          );

          _pendingLeaderSosAlerts.add(
            document,
          );
        }

        _showNextLeaderSosAlert();
      },
      onError: (error) {
        debugPrint(
          'Leader SOS listener error: $error',
        );
      },
    );
  }

  Future<void> _showNextLeaderSosAlert() async {
    if (!mounted) return;

    if (_showingSosPopup) {
      return;
    }

    if (_pendingLeaderSosAlerts.isEmpty) {
      return;
    }

    _showingSosPopup = true;

    final alert =
    _pendingLeaderSosAlerts.removeAt(0);

    try {
      await _showLeaderSosPopup(
        alert,
      );
    } finally {
      _showingSosPopup = false;

      if (_pendingLeaderSosAlerts.isNotEmpty &&
          mounted) {
        Future.microtask(
          _showNextLeaderSosAlert,
        );
      }
    }
  }

  Future<void> _showLeaderSosPopup(
      DocumentSnapshot<Map<String, dynamic>>
      alertDocument,
      ) async {
    if (!mounted) return;

    final data =
        alertDocument.data() ??
            const <String, dynamic>{};

    final senderId =
        '${data['senderId'] ?? ''}';

    final senderName =
        '${data['senderName'] ?? 'Group Member'}';

    final groupId =
        '${data['groupId'] ?? ''}';

    final groupName =
        '${data['groupName'] ?? 'Travel Group'}';

    final location = data['location'];

    if (location is! GeoPoint) {
      debugPrint(
        'SOS ${alertDocument.id} has no valid GeoPoint.',
      );
      return;
    }

    final targetLatitude =
        location.latitude;

    final targetLongitude =
        location.longitude;

    // ==========================================
    // CALCULATE LEADER → MEMBER DISTANCE
    // ==========================================

    double? distanceMeters;
    int? estimatedMinutes;

    try {
      final leaderPosition =
      await determinePosition();

      distanceMeters =
          Geolocator.distanceBetween(
            leaderPosition.latitude,
            leaderPosition.longitude,
            targetLatitude,
            targetLongitude,
          );

      // Approx. walking speed:
      // 4.5 km/h ≈ 75 metres/minute
      estimatedMinutes =
          (distanceMeters / 75).ceil();
    } catch (error) {
      debugPrint(
        'Unable to calculate SOS distance: $error',
      );
    }

    if (!mounted) return;

    String distanceText;

    if (distanceMeters == null) {
      distanceText = 'Unavailable';
    } else if (distanceMeters < 1000) {
      distanceText =
      '${distanceMeters.round()} m';
    } else {
      distanceText =
      '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }

    final triggeredAt =
        asDate(data['lastTriggeredAt']) ??
            asDate(data['createdAt']);

    final timeText = triggeredAt == null
        ? 'Just now'
        : DateFormat.jm().format(
      triggeredAt,
    );

    final action =
    await showDialog<String>(
      context: context,

      // Emergency alert should require action
      barrierDismissible: false,

      builder: (dialogContext) {
        return Dialog(
          insetPadding:
          const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(18),
          ),
          child: Container(
            padding:
            const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:
              ExplorerColors.dangerSoft,
              borderRadius:
              BorderRadius.circular(18),
              border: Border.all(
                color:
                ExplorerColors.danger,
                width: 1.5,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // ===========================
                  // HEADER
                  // ===========================

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .warning_amber_rounded,
                        color:
                        ExplorerColors.danger,
                        size: 27,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      const Expanded(
                        child: Text(
                          'SOS ALERT',
                          style: TextStyle(
                            color:
                            ExplorerColors
                                .danger,
                            fontSize: 18,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                      ),

                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration:
                        BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius
                              .circular(
                            20,
                          ),
                        ),
                        child: Text(
                          timeText,
                          style:
                          const TextStyle(
                            color:
                            ExplorerColors
                                .danger,
                            fontSize: 10,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  const Text(
                    'GROUP MEMBER IN DISTRESS',
                    style: TextStyle(
                      color:
                      ExplorerColors.muted,
                      fontSize: 9,
                      fontWeight:
                      FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    senderName,
                    style: const TextStyle(
                      color:
                      ExplorerColors.danger,
                      fontSize: 19,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  // ===========================
                  // LOCATION
                  // ===========================

                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(
                      12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),
                      border: Border.all(
                        color:
                        const Color(
                          0xFFF2C6C1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons
                                  .location_on_outlined,
                              color:
                              ExplorerColors
                                  .danger,
                              size: 17,
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            Text(
                              'LAST KNOWN LOCATION',
                              style:
                              TextStyle(
                                color:
                                ExplorerColors
                                    .muted,
                                fontSize: 9,
                                fontWeight:
                                FontWeight
                                    .w800,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          '${targetLatitude.toStringAsFixed(5)}, '
                              '${targetLongitude.toStringAsFixed(5)}',
                          style:
                          const TextStyle(
                            color:
                            ExplorerColors
                                .navy,
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ===========================
                  // DISTANCE + TIME
                  // ===========================

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding:
                          const EdgeInsets
                              .all(12),
                          decoration:
                          BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius
                                .circular(
                              10,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons
                                    .route_outlined,
                                color:
                                ExplorerColors
                                    .navy,
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                distanceText,
                                style:
                                const TextStyle(
                                  color:
                                  ExplorerColors
                                      .navy,
                                  fontSize: 17,
                                  fontWeight:
                                  FontWeight
                                      .w900,
                                ),
                              ),
                              const Text(
                                'DISTANCE',
                                style:
                                TextStyle(
                                  color:
                                  ExplorerColors
                                      .muted,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Container(
                          padding:
                          const EdgeInsets
                              .all(12),
                          decoration:
                          BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius
                                .circular(
                              10,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons
                                    .schedule_outlined,
                                color:
                                ExplorerColors
                                    .navy,
                              ),
                              const SizedBox(
                                height: 5,
                              ),
                              Text(
                                estimatedMinutes ==
                                    null
                                    ? '--'
                                    : '$estimatedMinutes min',
                                style:
                                const TextStyle(
                                  color:
                                  ExplorerColors
                                      .navy,
                                  fontSize: 17,
                                  fontWeight:
                                  FontWeight
                                      .w900,
                                ),
                              ),
                              const Text(
                                'EST. WALK',
                                style:
                                TextStyle(
                                  color:
                                  ExplorerColors
                                      .muted,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ===========================
                  // ACCEPT ROUTE
                  // ===========================

                  SizedBox(
                    width:
                    double.infinity,
                    child:
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                          'route',
                        );
                      },
                      style:
                      FilledButton
                          .styleFrom(
                        backgroundColor:
                        ExplorerColors
                            .danger,
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(
                        Icons
                            .navigation_outlined,
                      ),
                      label: const Text(
                        'Accept and View Route',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 9,
                  ),

                  // ===========================
                  // CONTACT MEMBER
                  // ===========================

                  SizedBox(
                    width:
                    double.infinity,
                    child:
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          dialogContext,
                          'chat',
                        );
                      },
                      style:
                      OutlinedButton
                          .styleFrom(
                        foregroundColor:
                        ExplorerColors
                            .danger,
                        side:
                        const BorderSide(
                          color:
                          ExplorerColors
                              .danger,
                        ),
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(
                        Icons
                            .chat_bubble_outline,
                      ),
                      label: const Text(
                        'Contact Companion',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  const Center(
                    child: Text(
                      'Action is required immediately to ensure group safety.',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        color:
                        ExplorerColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    // ==========================================
    // LEADER ACCEPTS ROUTE
    // ==========================================

    if (action == 'route') {
      try {
        await alertDocument.reference.update({
          'acceptedAt':
          FieldValue.serverTimestamp(),
          'acceptedBy':
          AppServices
              .auth.currentUser?.uid,
        });
      } catch (error) {
        debugPrint(
          'Unable to acknowledge SOS: $error',
        );
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RouteGuidancePage(
                senderId: senderId,
                senderName: senderName,
                alertId:
                alertDocument.id,
                targetLat:
                targetLatitude,
                targetLng:
                targetLongitude,
              ),
        ),
      );
    }

    // ==========================================
    // CONTACT COMPANION
    // ==========================================

    if (action == 'chat') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GroupChatPage(
                groupId: groupId,
                groupName: groupName,
              ),
        ),
      );
    }
  }

  void _startPrivateLocationRequestListener() {
    final user = AppServices.auth.currentUser;

    if (user == null) return;

    _privateLocationRequestSubscription?.cancel();

    _privateLocationRequestSubscription =
        AppServices.db
            .collection('location_requests')
            .where(
          'targetId',
          isEqualTo: user.uid,
        )
            .snapshots()
            .listen(
              (snapshot) {
            for (final change
            in snapshot.docChanges) {
              final document =
                  change.doc;

              final data =
                  document.data() ??
                      const <String, dynamic>{};

              // Only handle PRIVATE requests
              if (data['requestType'] !=
                  'private') {
                continue;
              }

              if (data['status'] !=
                  'pending') {
                continue;
              }

              // Do not show same request twice
              if (_handledPrivateLocationRequestIds
                  .contains(document.id)) {
                continue;
              }

              _handledPrivateLocationRequestIds
                  .add(document.id);

              _pendingPrivateLocationRequests
                  .add(document);
            }

            _showNextPrivateLocationRequest();
          },
          onError: (error) {
            debugPrint(
              'Private location request listener error: $error',
            );
          },
        );
  }

  Future<void>
  _showNextPrivateLocationRequest() async {
    if (!mounted) return;

    if (_showingPrivateLocationRequest) {
      return;
    }

    if (_pendingPrivateLocationRequests
        .isEmpty) {
      return;
    }

    _showingPrivateLocationRequest = true;

    final request =
    _pendingPrivateLocationRequests
        .removeAt(0);

    try {
      await _showPrivateLocationRequestPrompt(
        request,
      );
    } finally {
      _showingPrivateLocationRequest =
      false;

      if (_pendingPrivateLocationRequests
          .isNotEmpty &&
          mounted) {
        Future.microtask(
          _showNextPrivateLocationRequest,
        );
      }
    }
  }

  Future<void>
  _showPrivateLocationRequestPrompt(
      DocumentSnapshot<Map<String, dynamic>>
      requestDocument,
      ) async {
    if (!mounted) return;

    final data =
        requestDocument.data() ??
            const <String, dynamic>{};

    if (data['requestType'] != 'private' ||
        data['status'] != 'pending') {
      return;
    }

    final requesterName =
        '${data['requesterName'] ?? 'Another traveler'}';

    final action =
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          AlertDialog(
            icon: const Icon(
              Icons.location_searching,
              color: ExplorerColors.navy,
              size: 42,
            ),

            title: const Text(
              'Location Request',
            ),

            content: Text(
              '$requesterName is requesting your current location.\n\n'
                  'Do you want to share it? '
                  'Your current GPS position will be '
                  'shared one time only with '
                  '$requesterName.',
              textAlign: TextAlign.center,
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    'reject',
                  );
                },
                child: const Text(
                  'Reject',
                  style: TextStyle(
                    color:
                    ExplorerColors.danger,
                  ),
                ),
              ),

              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    'share',
                  );
                },
                icon: const Icon(
                  Icons.location_on_outlined,
                ),
                label: const Text(
                  'Share Location',
                ),
              ),
            ],
          ),
    );

    if (!mounted ||
        action == null) {
      return;
    }

    await respondToPrivateLocationRequest(
      context,
      requestDocument,
      shareLocation:
      action == 'share',
    );
  }

  Future<String> _currentDisplayName() async {
    if (_cachedDisplayName != null && _cachedDisplayName!.trim().isNotEmpty) {
      return _cachedDisplayName!;
    }

    final user = AppServices.auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in first.');
    }

    final profile = await AppServices.travelerRef(user.uid).get();
    final data = profile.data();

    final displayName =
    '${data?['displayName'] ?? user.displayName ?? ''}'.trim();

    if (displayName.isEmpty) {
      throw Exception(
        'Your traveler profile does not contain a display name.',
      );
    }

    _cachedDisplayName = displayName;
    return displayName;
  }

  Future<String> _createUniqueGroupCode() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = randomCode().toUpperCase();

      final existing = await AppServices.db
          .collection('travel_groups')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        return code;
      }
    }

    throw Exception(
      'Unable to generate a unique group code. Please try again.',
    );
  }

  Future<bool> _confirmLocationSharing(
      BuildContext context, {
        required String title,
        required String message,
        String actionLabel = 'Allow Location & Continue',
      }) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.location_on_outlined,
          color: ExplorerColors.navy,
          size: 42,
        ),
        title: Text(title),
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.my_location),
            label: Text(actionLabel),
          ),
        ],
      ),
    );

    return accepted == true;
  }

  Future<void> _resumeLiveLocationSharingIfEnabled() async {
    if (_liveSharingStarted) return;

    final user = AppServices.auth.currentUser;
    if (user == null) return;

    try {
      final groups = await AppServices.db
          .collection('travel_groups')
          .where('memberIds', arrayContains: user.uid)
          .get();

      for (final group in groups.docs) {
        final locationDocument =
        await group.reference.collection('locations').doc(user.uid).get();

        if (locationDocument.data()?['sharingEnabled'] == true) {
          _startLiveLocationSharing();
          break;
        }
      }
    } catch (error) {
      debugPrint('Unable to resume companion location sharing: $error');
    }
  }

  void _startLiveLocationSharing() {
    if (_liveSharingStarted) return;

    _liveSharingStarted = true;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    );

    _liveLocationSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
              (position) {
            _publishLocationToJoinedGroups(position);
          },
          onError: (Object error) {
            debugPrint('Companion live location stream error: $error');
          },
        );
  }

  Future<void> _publishLocationToJoinedGroups(Position position) async {
    final user = AppServices.auth.currentUser;
    if (user == null) return;

    try {
      final displayName = await _currentDisplayName();

      final groups = await AppServices.db
          .collection('travel_groups')
          .where('memberIds', arrayContains: user.uid)
          .get();

      if (groups.docs.isEmpty) return;

      final batch = AppServices.db.batch();

      for (final groupDocument in groups.docs) {
        final group = groupDocument.data();

        if ('${group['status'] ?? ''}' != 'active') {
          continue;
        }

        final leaderId = '${group['leaderId'] ?? ''}';
        final isLeader = leaderId == user.uid;

        final locationReference =
        groupDocument.reference.collection('locations').doc(user.uid);

        batch.set(
          locationReference,
          {
            'userId': user.uid,
            'displayName': displayName,
            'role': isLeader ? 'leader' : 'member',
            'location': GeoPoint(position.latitude, position.longitude),
            'approvedViewerIds':
            isLeader ? [user.uid] : [user.uid, leaderId],
            'sharingEnabled': true,
            'sosActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (error) {
      debugPrint('Unable to publish companion live location: $error');
    }
  }

  Future<void> createGroup(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Travel Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. Penang Heritage Walk',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Short description of the trip',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Continue'),
          ),
        ],
      ),
    );

    final groupName = nameController.text.trim();
    final description = descriptionController.text.trim();

    nameController.dispose();
    descriptionController.dispose();

    if (confirmed != true) return;

    if (groupName.isEmpty) {
      if (context.mounted) {
        showMessage(
          context,
          'Please enter a group name.',
          error: true,
        );
      }
      return;
    }

    final user = AppServices.auth.currentUser;
    if (user == null) return;

    if (!context.mounted) return;
    final locationAccepted = await _confirmLocationSharing(
      context,
      title: 'Location Required',
      message:
      'Your location is required so you can appear on the Group Map as the group leader. '
          'The location will be stored only for this travel group.',
      actionLabel: 'Allow Location & Create',
    );

    if (!locationAccepted) return;

    try {
      final position = await determinePosition();
      final displayName = await _currentDisplayName();
      final code = await _createUniqueGroupCode();

      final groupReference = AppServices.db.collection('travel_groups').doc();
      final locationReference =
      groupReference.collection('locations').doc(user.uid);

      final batch = AppServices.db.batch();

      batch.set(groupReference, {
        'name': groupName,
        'description': description,
        'code': code,
        'leaderId': user.uid,
        'memberIds': [user.uid],
        'memberNames': {
          user.uid: displayName,
        },
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(locationReference, {
        'userId': user.uid,
        'displayName': displayName,
        'role': 'leader',
        'location': GeoPoint(position.latitude, position.longitude),
        'approvedViewerIds': [user.uid],
        'sharingEnabled': true,
        'sosActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _startLiveLocationSharing();

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Travel Group Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: ExplorerColors.success,
                size: 52,
              ),
              const SizedBox(height: 12),
              Text(
                groupName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Share this group code with your companions:',
                textAlign: TextAlign.center,
                style: TextStyle(color: ExplorerColors.muted),
              ),
              const SizedBox(height: 10),
              SelectableText(
                code,
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));

                if (dialogContext.mounted) {
                  showMessage(dialogContext, 'Group code copied.');
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy Code'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
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

  Future<void> joinGroup(BuildContext context) async {
    final codeController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Travel Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the group code shared by the group leader.',
              style: TextStyle(color: ExplorerColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Group Code',
                hintText: 'ABC123',
                counterText: '',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              onSubmitted: (_) => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.login),
            label: const Text('Continue'),
          ),
        ],
      ),
    );

    final code = codeController.text.trim().toUpperCase();
    codeController.dispose();

    if (confirmed != true) return;

    if (code.isEmpty) {
      if (context.mounted) {
        showMessage(
          context,
          'Please enter a group code.',
          error: true,
        );
      }
      return;
    }

    final user = AppServices.auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await AppServices.db
          .collection('travel_groups')
          .where('code', isEqualTo: code)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Invalid or inactive group code.');
      }

      final groupDocument = snapshot.docs.first;
      final group = groupDocument.data();

      final groupName = '${group['name'] ?? 'Travel Group'}';
      final leaderId = '${group['leaderId'] ?? ''}';

      if (leaderId.isEmpty) {
        throw Exception('This group has no valid group leader.');
      }

      if (!context.mounted) return;
      final locationAccepted = await _confirmLocationSharing(
        context,
        title: 'Join $groupName?',
        message:
        'Location sharing is required before joining this travel group. '
            'Your current and updated location will be shared with the group leader '
            'while the Companion feature is active.',
        actionLabel: 'Join & Share Location',
      );

      if (!locationAccepted) return;

      final position = await determinePosition();
      final displayName = await _currentDisplayName();

      final memberIds = List<String>.from(
        group['memberIds'] ?? const <String>[],
      );

      final locationReference =
      groupDocument.reference.collection('locations').doc(user.uid);

      final batch = AppServices.db.batch();

      batch.update(groupDocument.reference, {
        'memberIds': FieldValue.arrayUnion([user.uid]),
        'memberNames.${user.uid}': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        locationReference,
        {
          'userId': user.uid,
          'displayName': displayName,
          'role': leaderId == user.uid ? 'leader' : 'member',
          'location': GeoPoint(position.latitude, position.longitude),
          'approvedViewerIds':
          leaderId == user.uid ? [user.uid] : [user.uid, leaderId],
          'sharingEnabled': true,
          'sosActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      _startLiveLocationSharing();

      if (context.mounted) {
        if (memberIds.contains(user.uid)) {
          showMessage(
            context,
            'Your location sharing was refreshed for $groupName.',
          );
        } else {
          showMessage(
            context,
            'Joined $groupName successfully.',
          );
        }
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

  Future<void> _acceptInvitation(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> invitation,
      ) async {
    final user = AppServices.auth.currentUser;
    if (user == null) return;

    if (_respondingInvitationIds.contains(invitation.id)) return;

    final data = invitation.data();

    if ('${data['memberId'] ?? ''}' != user.uid) {
      showMessage(
        context,
        'This invitation does not belong to your account.',
        error: true,
      );
      return;
    }

    final groupName = '${data['groupName'] ?? 'Travel Group'}';

    final locationAccepted = await _confirmLocationSharing(
      context,
      title: 'Accept Invitation?',
      message:
      'To join $groupName, location sharing is required. '
          'Your current and updated location will be visible to the group leader '
          'while the Companion feature is active.',
      actionLabel: 'Accept & Share Location',
    );

    if (!locationAccepted) return;

    setState(() {
      _respondingInvitationIds.add(invitation.id);
    });

    try {
      final position = await determinePosition();
      final displayName = await _currentDisplayName();

      final groupId = '${data['groupId'] ?? ''}';

      if (groupId.isEmpty) {
        throw Exception('This invitation has no valid travel group.');
      }

      final groupReference =
      AppServices.db.collection('travel_groups').doc(groupId);

      final groupSnapshot = await groupReference.get();

      if (!groupSnapshot.exists) {
        throw Exception('This travel group no longer exists.');
      }

      final group = groupSnapshot.data() ?? const <String, dynamic>{};

      if ('${group['status'] ?? ''}' != 'active') {
        throw Exception('This travel group is no longer active.');
      }

      final leaderId = '${group['leaderId'] ?? ''}';

      if (leaderId.isEmpty) {
        throw Exception('This travel group has no valid group leader.');
      }

      final locationReference =
      groupReference.collection('locations').doc(user.uid);

      final batch = AppServices.db.batch();

      batch.update(groupReference, {
        'memberIds': FieldValue.arrayUnion([user.uid]),
        'memberNames.${user.uid}': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        locationReference,
        {
          'userId': user.uid,
          'displayName': displayName,
          'role': 'member',
          'location': GeoPoint(position.latitude, position.longitude),
          'approvedViewerIds': [user.uid, leaderId],
          'sharingEnabled': true,
          'sosActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.update(invitation.reference, {
        'status': 'accepted',
        'memberName': displayName,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      await AppServices.notify(
        userId: leaderId,
        title: '$displayName accepted your invitation',
        message: '$displayName joined $groupName and enabled location sharing.',
        type: 'companion_group',
        referenceId: groupId,
      );

      _startLiveLocationSharing();

      if (context.mounted) {
        showMessage(
          context,
          'You joined $groupName successfully.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _respondingInvitationIds.remove(invitation.id);
        });
      }
    }
  }

  Future<void> _rejectInvitation(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> invitation,
      ) async {
    final user = AppServices.auth.currentUser;
    if (user == null) return;

    if (_respondingInvitationIds.contains(invitation.id)) return;

    final data = invitation.data();

    if ('${data['memberId'] ?? ''}' != user.uid) {
      return;
    }

    final groupName = '${data['groupName'] ?? 'Travel Group'}';
    final leaderId = '${data['leaderId'] ?? ''}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Invitation?'),
        content: Text(
          'You will not be added to $groupName and your location will not be shared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: ExplorerColors.danger,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _respondingInvitationIds.add(invitation.id);
    });

    try {
      await invitation.reference.update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (leaderId.isNotEmpty) {
        final displayName = await _currentDisplayName();

        await AppServices.notify(
          userId: leaderId,
          title: '$displayName declined the invitation',
          message: '$displayName declined the invitation to $groupName.',
          type: 'companion_group',
          referenceId: '${data['groupId'] ?? ''}',
        );
      }

      if (context.mounted) {
        showMessage(
          context,
          'Invitation rejected.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _respondingInvitationIds.remove(invitation.id);
        });
      }
    }
  }

  Future<String> _displayName(String uid) async {
    try {
      final profile = await AppServices.travelerRef(uid).get();
      final data = profile.data() ?? const <String, dynamic>{};

      return '${data['displayName'] ?? uid}';
    } catch (_) {
      return uid;
    }
  }

  Future<void> _sendSos(
      BuildContext context,
      String groupId,
      Map<String, dynamic> group,
      ) async {
    final user = AppServices.auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final leaderId = '${group['leaderId'] ?? ''}';

    if (leaderId.isEmpty) {
      showMessage(
        context,
        'This group has no group leader.',
        error: true,
      );
      return;
    }

    if (uid == leaderId) {
      showMessage(
        context,
        'SOS is for group members. As the leader, you will receive member SOS alerts.',
      );
      return;
    }

    if (_sendingSosGroupIds.contains(groupId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.sos_rounded,
          color: ExplorerColors.danger,
          size: 42,
        ),
        title: const Text('Send Emergency SOS?'),
        content: const Text(
          'Your latest GPS location and timestamp will be sent to your group leader.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: ExplorerColors.danger,
            ),
            icon: const Icon(Icons.sos_rounded),
            label: const Text('Send SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sendingSosGroupIds.add(groupId);
    });

    try {
      final position = await determinePosition();
      final senderName = await _displayName(uid);
      final groupName = '${group['name'] ?? 'Travel Group'}';

      final existingSnapshot = await AppServices.db
          .collection('sos_alerts')
          .where('groupId', isEqualTo: groupId)
          .get();

      final existing = existingSnapshot.docs.where((document) {
        final data = document.data();

        return data['senderId'] == uid && data['status'] == 'active';
      }).toList();

      DocumentReference<Map<String, dynamic>> alertReference;

      if (existing.isNotEmpty) {
        alertReference = existing.first.reference;

        await alertReference.update({
          'location': GeoPoint(position.latitude, position.longitude),
          'lastTriggeredAt': FieldValue.serverTimestamp(),
          'triggerCount': FieldValue.increment(1),
        });
      } else {
        alertReference = await AppServices.db.collection('sos_alerts').add({
          'groupId': groupId,
          'groupName': groupName,
          'senderId': uid,
          'senderName': senderName,
          'leaderId': leaderId,
          'recipientId': leaderId,
          'recipientIds': [leaderId],
          'location': GeoPoint(position.latitude, position.longitude),
          'status': 'active',
          'triggerCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'lastTriggeredAt': FieldValue.serverTimestamp(),
        });
      }

      await AppServices.db
          .collection('travel_groups')
          .doc(groupId)
          .collection('locations')
          .doc(uid)
          .set(
        {
          'userId': uid,
          'displayName': senderName,
          'role': 'member',
          'location': GeoPoint(position.latitude, position.longitude),
          'approvedViewerIds': [uid, leaderId],
          'sharingEnabled': true,
          'sosActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await AppServices.notify(
        userId: leaderId,
        title: 'SOS alert from $senderName',
        message:
        '$senderName needs help in $groupName. Open the Companion page to view the location.',
        type: 'sos',
        referenceId: alertReference.id,
      );

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: ExplorerColors.success,
            size: 48,
          ),
          title: const Text('SOS Sent'),
          content: Text(
            'Your latest location has been sent to the group leader of $groupName.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingSosGroupIds.remove(groupId);
        });
      }
    }
  }

  void _openGroupChat(
      BuildContext context,
      String groupId,
      Map<String, dynamic> group,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatPage(
          groupId: groupId,
          groupName: '${group['name'] ?? 'Travel Group'}',
        ),
      ),
    );
  }

  void _openLeaderPage(
      BuildContext context,
      String groupId,
      Map<String, dynamic> group, {
        int initialTab = 0,
      }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailsPage(
          groupId: groupId,
          group: group,
          initialTab: initialTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in first.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsPage(),
              ),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('travel_groups')
            .where('memberIds', arrayContains: uid)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your travel groups.\n${groupSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!groupSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final groups = groupSnapshot.data!.docs.toList()
            ..sort((a, b) {
              final first = asDate(a.data()['updatedAt']) ??
                  asDate(a.data()['createdAt']) ??
                  DateTime(2000);

              final second = asDate(b.data()['updatedAt']) ??
                  asDate(b.data()['createdAt']) ??
                  DateTime(2000);

              return second.compareTo(first);
            });

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppServices.db
                .collection('group_invitations')
                .where('memberId', isEqualTo: uid)
                .snapshots(),
            builder: (context, invitationSnapshot) {
              final invitations = (invitationSnapshot.data?.docs ?? [])
                  .where((document) {
                return document.data()['status'] == 'pending';
              })
                  .toList()
                ..sort((a, b) {
                  final first =
                      asDate(a.data()['createdAt']) ?? DateTime(2000);
                  final second =
                      asDate(b.data()['createdAt']) ?? DateTime(2000);

                  return second.compareTo(first);
                });

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  const ExplorerPageHeader(
                    title: 'Companion',
                    subtitle:
                    'Stay connected and travel safely with your group.',
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ExplorerQuickAction(
                          label: 'Create Group',
                          icon: Icons.group_add_outlined,
                          onTap: () => createGroup(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ExplorerQuickAction(
                          label: 'Join Group',
                          icon: Icons.login,
                          gold: true,
                          onTap: () => joinGroup(context),
                        ),
                      ),
                    ],
                  ),

                  if (invitations.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    ExplorerSectionTitle(
                      'Group Invitations',
                      subtitle:
                      '${invitations.length} invitation${invitations.length == 1 ? '' : 's'} waiting for your response',
                    ),
                    const SizedBox(height: 10),
                    ...invitations.map(
                          (invitation) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildInvitationCard(
                          context,
                          invitation,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  const ExplorerSectionTitle(
                    'Private Chats',
                    subtitle:
                    'One-to-one messages with optional private location sharing.',
                  ),

                  const SizedBox(height: 10),

                  ExplorerCard(
                    radius: 12,
                    backgroundColor:
                    ExplorerColors.navySoft,

                    child: ListTile(
                      contentPadding:
                      EdgeInsets.zero,

                      leading: const CircleAvatar(
                        backgroundColor:
                        ExplorerColors.navy,
                        foregroundColor:
                        Colors.white,
                        child: Icon(
                          Icons.lock_outline,
                        ),
                      ),

                      title: const Text(
                        'Private Messages',
                        style: TextStyle(
                          color:
                          ExplorerColors.navy,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),

                      subtitle: const Text(
                        'Chat privately with another traveler '
                            'and request a one-time current location.',
                        style: TextStyle(
                          color:
                          ExplorerColors.muted,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),

                      trailing: const Icon(
                        Icons.chevron_right,
                      ),

                      onTap: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const PrivateChatsPage(),
                            ),
                          ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  ExplorerSectionTitle(
                    'My Travel Groups',
                    subtitle: groups.isEmpty
                        ? 'Create or join a group to get started.'
                        : '${groups.length} group${groups.length == 1 ? '' : 's'} available',
                  ),

                  const SizedBox(height: 10),

                  if (groups.isEmpty)
                    ExplorerEmptyState(
                      title: 'No Travel Group Yet',
                      subtitle:
                      'Create a private travel group or join one using the code shared by a group leader.',
                      icon: Icons.groups_outlined,
                      action: FilledButton.icon(
                        onPressed: () => createGroup(context),
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Create Travel Group'),
                      ),
                    )
                  else
                    ...groups.map(
                          (document) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildGroupCard(
                          context,
                          document.id,
                          document.data(),
                          uid,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInvitationCard(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> invitation,
      ) {
    final data = invitation.data();

    final groupName = '${data['groupName'] ?? 'Travel Group'}';
    final leaderName = '${data['leaderName'] ?? 'Group Leader'}';
    final isResponding = _respondingInvitationIds.contains(invitation.id);

    return ExplorerCard(
      radius: 12,
      backgroundColor: ExplorerColors.goldSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: ExplorerColors.navy,
                foregroundColor: Colors.white,
                child: Icon(Icons.mark_email_unread_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invited by $leaderName',
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const ExplorerStatusBadge(
                label: 'PENDING',
                tone: ExplorerStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Location sharing is required if you accept this invitation. '
                'The group leader will be able to see your location on the Group Map.',
            style: TextStyle(
              color: ExplorerColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isResponding
                      ? null
                      : () => _rejectInvitation(
                    context,
                    invitation,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ExplorerColors.danger,
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isResponding
                      ? null
                      : () => _acceptInvitation(
                    context,
                    invitation,
                  ),
                  icon: isResponding
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    isResponding ? 'Processing...' : 'Accept',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
      BuildContext context,
      String groupId,
      Map<String, dynamic> group,
      String uid,
      ) {
    final memberIds = List<String>.from(
      group['memberIds'] ?? const <String>[],
    );

    final isLeader = '${group['leaderId'] ?? ''}' == uid;
    final groupName = '${group['name'] ?? 'Travel Group'}';
    final description = '${group['description'] ?? ''}'.trim();
    final code = '${group['code'] ?? '-'}';
    final sendingSos = _sendingSosGroupIds.contains(groupId);

    return ExplorerCard(
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isLeader
                      ? ExplorerColors.goldSoft
                      : ExplorerColors.navySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isLeader
                      ? Icons.workspace_premium_outlined
                      : Icons.groups_outlined,
                  color: ExplorerColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ExplorerStatusBadge(
                label: isLeader ? 'LEADER' : 'MEMBER',
                tone: isLeader
                    ? ExplorerStatusTone.warning
                    : ExplorerStatusTone.navy,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ExplorerLabeledValue(
                  label: 'Group Code',
                  value: code,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExplorerLabeledValue(
                  label: 'Members',
                  value: '${memberIds.length}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isLeader) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGroupChat(
                      context,
                      groupId,
                      group,
                    ),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Group Chat'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openLeaderPage(
                      context,
                      groupId,
                      group,
                      initialTab: 1,
                    ),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Members'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openLeaderPage(
                      context,
                      groupId,
                      group,
                      initialTab: 0,
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Group Map'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _leaderSosButton(
                    context,
                    groupId,
                    group,
                    uid,
                  ),
                ),
              ],
            ),
          ] else ...[
            // =========================================
            // NORMAL MEMBER FUNCTIONS
            // =========================================

            Row(
              children: [
                // Group Chat
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGroupChat(
                      context,
                      groupId,
                      group,
                    ),
                    icon: const Icon(
                      Icons.forum_outlined,
                    ),
                    label: const Text(
                      'Group Chat',
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Read-only Members list
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMembersList(
                      context,
                      group,
                    ),
                    icon: const Icon(
                      Icons.groups_outlined,
                    ),
                    label: const Text(
                      'Members',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 9),

            // SOS button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: sendingSos
                    ? null
                    : () => _sendSos(
                  context,
                  groupId,
                  group,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ExplorerColors.danger,
                ),
                icon: sendingSos
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.sos_rounded,
                ),
                label: Text(
                  sendingSos
                      ? 'Sending SOS...'
                      : 'SOS Emergency',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _leaderSosButton(
      BuildContext context,
      String groupId,
      Map<String, dynamic> group,
      String uid,
      ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('sos_alerts')
          .where('groupId', isEqualTo: groupId)
          .snapshots(),
      builder: (context, snapshot) {
        final activeCount = (snapshot.data?.docs ?? []).where((document) {
          final data = document.data();

          return data['leaderId'] == uid && data['status'] == 'active';
        }).length;

        return OutlinedButton.icon(
          onPressed: () => _openLeaderPage(
            context,
            groupId,
            group,
            initialTab: 2,
          ),
          style: activeCount > 0
              ? OutlinedButton.styleFrom(
            foregroundColor: ExplorerColors.danger,
            side: const BorderSide(
              color: ExplorerColors.danger,
            ),
          )
              : null,
          icon: Icon(
            activeCount > 0
                ? Icons.notification_important
                : Icons.notifications_none,
          ),
          label: Text(
            activeCount > 0
                ? 'SOS ($activeCount)'
                : 'SOS Alerts',
          ),
        );
      },
    );
  }
}
