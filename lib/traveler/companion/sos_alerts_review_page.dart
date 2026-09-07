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

class _SosAlertsReviewPageState
    extends State<SosAlertsReviewPage> {
  // ==============================================================
  // LEADER LOCATION
  // ==============================================================

  Position? _leaderPosition;

  StreamSubscription<Position>?
  _positionSubscription;

  bool _loadingLeaderLocation = true;

  // ==============================================================
  // INITIALIZATION
  // ==============================================================

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

  // ==============================================================
  // START LEADER LOCATION TRACKING
  //
  // The leader's latest GPS position is used to calculate
  // the distance to every active SOS.
  // ==============================================================

  Future<void>
  _startLeaderLocationTracking() async {
    try {
      final initialPosition =
      await determinePosition();

      if (!mounted) {
        return;
      }

      setState(() {
        _leaderPosition =
            initialPosition;

        _loadingLeaderLocation =
        false;
      });

      // ----------------------------------------------------------
      // Keep updating the leader's position.
      //
      // Re-ranking happens automatically because setState()
      // rebuilds the SOS list.
      // ----------------------------------------------------------

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings:
            const LocationSettings(
              accuracy:
              LocationAccuracy.high,

              // Recalculate after leader moves around 10 metres.
              distanceFilter:
              10,
            ),
          ).listen(
                (position) {
              if (!mounted) {
                return;
              }

              setState(() {
                _leaderPosition =
                    position;
              });
            },
            onError: (error) {
              debugPrint(
                'Leader GPS stream error: $error',
              );
            },
          );
    } catch (error) {
      debugPrint(
        'Unable to obtain leader location: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingLeaderLocation =
        false;
      });

      showMessage(
        context,
        'Unable to determine your location. '
            'SOS alerts will be ordered by trigger time until GPS is available.',
        error:
        true,
      );
    }
  }

  // ==============================================================
  // GET SOS GEOPOINT
  // ==============================================================

  GeoPoint? _alertLocation(
      Map<String, dynamic> data,
      ) {
    final location =
    data['location'];

    if (location is GeoPoint) {
      return location;
    }

    // ------------------------------------------------------------
    // Backward compatibility:
    //
    // Older SOS documents may contain latitude and longitude
    // separately.
    // ------------------------------------------------------------

    final latitude =
    data['latitude'];

    final longitude =
    data['longitude'];

    if (latitude is num &&
        longitude is num) {
      return GeoPoint(
        latitude.toDouble(),
        longitude.toDouble(),
      );
    }

    return null;
  }

  // ==============================================================
  // CALCULATE DISTANCE
  //
  // Returns metres.
  // ==============================================================

  double? _distanceToAlert(
      Map<String, dynamic> data,
      ) {
    final leader =
        _leaderPosition;

    if (leader == null) {
      return null;
    }

    final location =
    _alertLocation(
      data,
    );

    if (location == null) {
      return null;
    }

    return Geolocator.distanceBetween(
      leader.latitude,
      leader.longitude,
      location.latitude,
      location.longitude,
    );
  }

  // ==============================================================
  // SOS TIMESTAMP
  // ==============================================================

  DateTime _alertTime(
      Map<String, dynamic> data,
      ) {
    return asDate(
      data['lastTriggeredAt'],
    ) ??
        asDate(
          data['timestamp'],
        ) ??
        asDate(
          data['createdAt'],
        ) ??
        DateTime.now();
  }

  // ==============================================================
  // PRIORITY SORTING
  //
  // RULE:
  //
  // 1. If distance difference > 100 metres:
  //      farther companion first
  //
  // 2. If distance difference <= 100 metres:
  //      earlier SOS first
  //
  // 3. Alerts without GPS are placed below alerts with GPS.
  // ==============================================================

  int _compareAlerts(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      alertA,
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      alertB,
      ) {
    final dataA =
    alertA.data();

    final dataB =
    alertB.data();

    final distanceA =
    _distanceToAlert(
      dataA,
    );

    final distanceB =
    _distanceToAlert(
      dataB,
    );

    // ------------------------------------------------------------
    // Both have valid distance.
    // ------------------------------------------------------------

    if (distanceA != null &&
        distanceB != null) {
      final distanceDifference =
      (distanceA - distanceB)
          .abs();

      // ----------------------------------------------------------
      // More than 100 m difference:
      // farther companion = higher priority.
      // ----------------------------------------------------------

      if (distanceDifference >
          100) {
        return distanceB.compareTo(
          distanceA,
        );
      }

      // ----------------------------------------------------------
      // Similar distance:
      // earlier SOS = higher priority.
      // ----------------------------------------------------------

      final timeA =
      _alertTime(
        dataA,
      );

      final timeB =
      _alertTime(
        dataB,
      );

      return timeA.compareTo(
        timeB,
      );
    }

    // ------------------------------------------------------------
    // A has distance but B does not.
    // A comes first.
    // ------------------------------------------------------------

    if (distanceA != null &&
        distanceB == null) {
      return -1;
    }

    // ------------------------------------------------------------
    // B has distance but A does not.
    // B comes first.
    // ------------------------------------------------------------

    if (distanceA == null &&
        distanceB != null) {
      return 1;
    }

    // ------------------------------------------------------------
    // Neither has GPS:
    // earlier SOS comes first.
    // ------------------------------------------------------------

    return _alertTime(
      dataA,
    ).compareTo(
      _alertTime(
        dataB,
      ),
    );
  }

  // ==============================================================
  // FORMAT DISTANCE
  // ==============================================================

  String _formatDistance(
      double? distanceMeters,
      ) {
    if (distanceMeters == null) {
      return 'Distance unavailable';
    }

    if (distanceMeters <
        1000) {
      return '${distanceMeters.round()} m away';
    }

    return '${(distanceMeters / 1000).toStringAsFixed(2)} km away';
  }

  // ==============================================================
  // PRIORITY COLOUR
  // ==============================================================

  Color _priorityBackground(
      int priority,
      ) {
    if (priority == 1) {
      return ExplorerColors.danger;
    }

    if (priority == 2) {
      return ExplorerColors.goldDark;
    }

    return ExplorerColors.navy;
  }

  Color _priorityForeground(
      int priority,
      ) {
    return Colors.white;
  }

  // ==============================================================
  // PAGE
  // ==============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      ExplorerColors.background,

      appBar:
      AppBar(
        title:
        const Text(
          'Emergency SOS Alerts',
        ),
      ),

      body:
      Column(
        children: [
          // ======================================================
          // PRIORITY INFORMATION BANNER
          // ======================================================

          Container(
            width:
            double.infinity,

            margin:
            const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              4,
            ),

            padding:
            const EdgeInsets.all(
              14,
            ),

            decoration:
            BoxDecoration(
              color:
              ExplorerColors.navySoft,

              borderRadius:
              BorderRadius.circular(
                14,
              ),

              border:
              Border.all(
                color:
                ExplorerColors.border,
              ),
            ),

            child:
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                const Icon(
                  Icons
                      .priority_high_rounded,
                  color:
                  ExplorerColors.navy,
                ),

                const SizedBox(
                  width:
                  10,
                ),

                Expanded(
                  child:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [
                      const Text(
                        'SOS Priority',
                        style:
                        TextStyle(
                          color:
                          ExplorerColors
                              .navy,

                          fontWeight:
                          FontWeight
                              .w800,

                          fontSize:
                          13,
                        ),
                      ),

                      const SizedBox(
                        height:
                        3,
                      ),

                      Text(
                        _loadingLeaderLocation
                            ? 'Getting your location to calculate SOS priority...'
                            : _leaderPosition ==
                            null
                            ? 'GPS unavailable. Alerts are temporarily ordered by trigger time.'
                            : 'Farther companions are prioritised first. '
                            'If two companions are within 100 m of each other, '
                            'the earlier SOS receives higher priority.',

                        style:
                        const TextStyle(
                          color:
                          ExplorerColors
                              .muted,

                          fontSize:
                          10,

                          height:
                          1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // ACTIVE SOS LIST
          // ======================================================

          Expanded(
            child:
            StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
              AppServices.db
                  .collection(
                'sos_alerts',
              )
                  .where(
                'groupId',
                isEqualTo:
                widget.groupId,
              )
                  .where(
                'status',
                isEqualTo:
                'active',
              )
                  .snapshots(),

              builder:
                  (
                  context,
                  snapshot,
                  ) {
                // ------------------------------------------------
                // ERROR
                // ------------------------------------------------

                if (snapshot.hasError) {
                  return Center(
                    child:
                    Padding(
                      padding:
                      const EdgeInsets
                          .all(
                        24,
                      ),

                      child:
                      Text(
                        'Unable to load SOS alerts.\n'
                            '${snapshot.error}',

                        textAlign:
                        TextAlign
                            .center,
                      ),
                    ),
                  );
                }

                // ------------------------------------------------
                // LOADING
                // ------------------------------------------------

                if (snapshot
                    .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                    CircularProgressIndicator(),
                  );
                }

                // ------------------------------------------------
                // COPY LIST BEFORE SORTING
                // ------------------------------------------------

                final docs =
                    snapshot.data?.docs
                        .toList() ??
                        <QueryDocumentSnapshot<
                            Map<String,
                                dynamic>>>[];

                // ------------------------------------------------
                // SORT USING OUR PRIORITY RULE
                // ------------------------------------------------

                docs.sort(
                  _compareAlerts,
                );

                // ------------------------------------------------
                // NO ACTIVE ALERTS
                // ------------------------------------------------

                if (docs.isEmpty) {
                  return const ExplorerEmptyState(
                    title:
                    'No Active Alerts',

                    subtitle:
                    'Everything looks safe. '
                        'No companions have triggered SOS.',

                    icon:
                    Icons.security,
                  );
                }

                // ------------------------------------------------
                // ACTIVE SOS LIST
                // ------------------------------------------------

                return ListView.separated(
                  padding:
                  const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    30,
                  ),

                  itemCount:
                  docs.length,

                  separatorBuilder:
                      (
                      _,
                      __,
                      ) =>
                  const SizedBox(
                    height:
                    12,
                  ),

                  itemBuilder:
                      (
                      context,
                      index,
                      ) {
                    final document =
                    docs[index];

                    final data =
                    document.data();

                    final alertId =
                        document.id;

                    final priority =
                        index + 1;

                    final senderName =
                        '${data['senderName'] ?? 'Unknown Member'}';

                    final timestamp =
                    _alertTime(
                      data,
                    );

                    final timeStr =
                    DateFormat.jm()
                        .format(
                      timestamp,
                    );

                    final distance =
                    _distanceToAlert(
                      data,
                    );

                    final distanceText =
                    _formatDistance(
                      distance,
                    );

                    final location =
                    _alertLocation(
                      data,
                    );

                    return ExplorerCard(
                      backgroundColor:
                      priority == 1
                          ? ExplorerColors
                          .dangerSoft
                          : Colors.white,

                      borderColor:
                      priority == 1
                          ? ExplorerColors
                          .danger
                          : ExplorerColors
                          .border,

                      child:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [
                          // ======================================
                          // PRIORITY + MEMBER
                          // ======================================

                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [
                              // ----------------------------------
                              // PRIORITY BADGE
                              // ----------------------------------

                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal:
                                  10,
                                  vertical:
                                  6,
                                ),

                                decoration:
                                BoxDecoration(
                                  color:
                                  _priorityBackground(
                                    priority,
                                  ),

                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    20,
                                  ),
                                ),

                                child:
                                Text(
                                  'Priority $priority',

                                  style:
                                  TextStyle(
                                    color:
                                    _priorityForeground(
                                      priority,
                                    ),

                                    fontSize:
                                    10,

                                    fontWeight:
                                    FontWeight
                                        .w800,
                                  ),
                                ),
                              ),

                              const Spacer(),

                              Text(
                                'Triggered at $timeStr',

                                style:
                                const TextStyle(
                                  fontSize:
                                  10,

                                  color:
                                  ExplorerColors
                                      .muted,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height:
                            14,
                          ),

                          // ======================================
                          // MEMBER INFORMATION
                          // ======================================

                          Row(
                            children: [
                              CircleAvatar(
                                radius:
                                24,

                                backgroundColor:
                                priority == 1
                                    ? ExplorerColors
                                    .danger
                                    : ExplorerColors
                                    .navy,

                                child:
                                const Icon(
                                  Icons
                                      .emergency_rounded,

                                  color:
                                  Colors.white,
                                ),
                              ),

                              const SizedBox(
                                width:
                                12,
                              ),

                              Expanded(
                                child:
                                Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                                  children: [
                                    Text(
                                      senderName,

                                      style:
                                      TextStyle(
                                        fontSize:
                                        18,

                                        fontWeight:
                                        FontWeight
                                            .w900,

                                        color:
                                        priority ==
                                            1
                                            ? ExplorerColors
                                            .danger
                                            : ExplorerColors
                                            .navy,
                                      ),
                                    ),

                                    const SizedBox(
                                      height:
                                      4,
                                    ),

                                    Row(
                                      children: [
                                        Icon(
                                          Icons
                                              .location_on_outlined,

                                          size:
                                          16,

                                          color:
                                          distance !=
                                              null
                                              ? ExplorerColors
                                              .goldDark
                                              : ExplorerColors
                                              .muted,
                                        ),

                                        const SizedBox(
                                          width:
                                          4,
                                        ),

                                        Expanded(
                                          child:
                                          Text(
                                            distanceText,

                                            style:
                                            const TextStyle(
                                              fontSize:
                                              12,

                                              fontWeight:
                                              FontWeight
                                                  .w700,

                                              color:
                                              ExplorerColors
                                                  .text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height:
                            16,
                          ),

                          // ======================================
                          // PRIORITY EXPLANATION
                          // ======================================

                          if (priority == 1 &&
                              docs.length > 1)
                            Container(
                              width:
                              double.infinity,

                              margin:
                              const EdgeInsets
                                  .only(
                                bottom:
                                14,
                              ),

                              padding:
                              const EdgeInsets
                                  .all(
                                10,
                              ),

                              decoration:
                              BoxDecoration(
                                color:
                                ExplorerColors
                                    .dangerSoft,

                                borderRadius:
                                BorderRadius
                                    .circular(
                                  10,
                                ),
                              ),

                              child:
                              const Row(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                                children: [
                                  Icon(
                                    Icons
                                        .priority_high_rounded,

                                    size:
                                    17,

                                    color:
                                    ExplorerColors
                                        .danger,
                                  ),

                                  SizedBox(
                                    width:
                                    7,
                                  ),

                                  Expanded(
                                    child:
                                    Text(
                                      'Highest response priority based on '
                                          'distance from the group leader and SOS trigger time.',

                                      style:
                                      TextStyle(
                                        color:
                                        ExplorerColors
                                            .danger,

                                        fontSize:
                                        10,

                                        fontWeight:
                                        FontWeight
                                            .w600,

                                        height:
                                        1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ======================================
                          // DESCRIPTION
                          // ======================================

                          const Text(
                            'This companion needs immediate assistance. '
                                'Check their location and respond as soon as possible.',

                            style:
                            TextStyle(
                              fontSize:
                              13,

                              height:
                              1.4,

                              color:
                              ExplorerColors
                                  .text,
                            ),
                          ),

                          const SizedBox(
                            height:
                            20,
                          ),

                          // ======================================
                          // ACTION BUTTONS
                          // ======================================

                          Row(
                            children: [
                              // ----------------------------------
                              // MARK RESOLVED
                              // ----------------------------------

                              Expanded(
                                child:
                                OutlinedButton.icon(
                                  onPressed:
                                      () =>
                                      _resolveAlert(
                                        document
                                            .reference,
                                      ),

                                  style:
                                  OutlinedButton
                                      .styleFrom(
                                    foregroundColor:
                                    ExplorerColors
                                        .success,
                                  ),

                                  icon:
                                  const Icon(
                                    Icons
                                        .check_circle_outline,

                                    size:
                                    18,
                                  ),

                                  label:
                                  const Text(
                                    'Mark Resolved',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width:
                                12,
                              ),

                              // ----------------------------------
                              // ACCEPT & FIND
                              // ----------------------------------

                              Expanded(
                                child:
                                FilledButton.icon(
                                  onPressed:
                                      () {
                                    if (location ==
                                        null) {
                                      showMessage(
                                        context,
                                        'SOS location is unavailable.',
                                        error:
                                        true,
                                      );

                                      return;
                                    }

                                    Navigator.push(
                                      context,

                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                            RouteGuidancePage(
                                              senderId:
                                              '${data['senderId'] ?? ''}',

                                              senderName:
                                              senderName,

                                              alertId:
                                              alertId,

                                              targetLat:
                                              location.latitude,

                                              targetLng:
                                              location.longitude,
                                            ),
                                      ),
                                    );
                                  },

                                  style:
                                  FilledButton
                                      .styleFrom(
                                    backgroundColor:
                                    priority ==
                                        1
                                        ? ExplorerColors
                                        .danger
                                        : ExplorerColors
                                        .navy,
                                  ),

                                  icon:
                                  const Icon(
                                    Icons
                                        .directions_run,
                                  ),

                                  label:
                                  const Text(
                                    'Accept & Find',
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

  // ==============================================================
  // RESOLVE SOS ALERT
  // ==============================================================

  Future<void> _resolveAlert(
      DocumentReference<
          Map<String, dynamic>>
      ref,
      ) async {
    try {
      final currentUser =
          AppServices.auth.currentUser;

      await ref.update({
        'status':
        'resolved',

        'resolvedAt':
        FieldValue.serverTimestamp(),

        if (currentUser != null)
          'resolvedBy':
          currentUser.uid,
      });

      if (!mounted) {
        return;
      }

      showMessage(
        context,
        'Alert marked as resolved.',
      );
    } catch (error) {
      debugPrint(
        'Failed to resolve SOS: $error',
      );

      if (!mounted) {
        return;
      }

      showMessage(
        context,
        'Failed to resolve alert.',
        error:
        true,
      );
    }
  }
}