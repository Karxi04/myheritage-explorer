part of '../traveler_pages.dart';

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({
    super.key,
    required this.groupId,
    required this.group,
    this.initialTab = 0,
  });

  final String groupId;
  final Map<String, dynamic> group;

  /// 0 = Group Map, 1 = Members, 2 = SOS Alerts
  final int initialTab;

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool addingMember = false;
  bool updatingLocation = false;

  GoogleMapController? _mapController;

  DocumentReference<Map<String, dynamic>> get _groupRef =>
      AppServices.db.collection('travel_groups').doc(widget.groupId);

  @override
  void initState() {
    super.initState();

    final safeInitialTab = widget.initialTab.clamp(0, 2).toInt();

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: safeInitialTab,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _displayName(String uid) async {
    try {
      final profile = await AppServices.travelerRef(uid).get();
      final data = profile.data();

      final displayName = '${data?['displayName'] ?? ''}'.trim();

      if (displayName.isNotEmpty) {
        return displayName;
      }
    } catch (error) {
      debugPrint('Unable to load displayName for $uid: $error');
    }

    return 'Group Member';
  }

  String _groupMemberName(
      Map<String, dynamic> group,
      String memberId,
      ) {
    final memberNames = Map<String, dynamic>.from(
      group['memberNames'] ?? const <String, dynamic>{},
    );

    return '${memberNames[memberId] ?? ''}'.trim();
  }

  Future<void> _copyGroupCode(Map<String, dynamic> group) async {
    final code = '${group['code'] ?? ''}'.trim();

    if (code.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: code),
    );

    if (mounted) {
      showMessage(
        context,
        'Group code copied.',
      );
    }
  }

  Future<String?> _askForMemberEmail() async {
    String enteredEmail = '';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        void submit() {
          final email = enteredEmail.trim().toLowerCase();

          if (email.isEmpty) {
            showMessage(
              dialogContext,
              'Please enter the traveler\'s registered email address.',
              error: true,
            );
            return;
          }

          FocusScope.of(dialogContext).unfocus();
          Navigator.of(dialogContext).pop(email);
        }

        return AlertDialog(
          title: const Text('Invite Group Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the registered email address of the traveler. '
                    'The traveler must accept the invitation and allow location access before joining.',
                style: TextStyle(
                  color: ExplorerColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (value) {
                  enteredEmail = value;
                },
                onFieldSubmitted: (_) {
                  submit();
                },
                decoration: const InputDecoration(
                  labelText: 'Traveler Email',
                  hintText: 'traveler@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send Invitation'),
            ),
          ],
        );
      },
    );
  }

  Future<void> addMember(Map<String, dynamic> group) async {
    final leader = AppServices.auth.currentUser;

    if (leader == null) {
      return;
    }

    if ('${group['leaderId'] ?? ''}' != leader.uid) {
      if (mounted) {
        showMessage(
          context,
          'Only the group leader can invite members.',
          error: true,
        );
      }
      return;
    }

    final email = await _askForMemberEmail();

    if (!mounted || email == null || email.isEmpty) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    await Future<void>.delayed(
      const Duration(milliseconds: 200),
    );

    if (!mounted) return;

    setState(() {
      addingMember = true;
    });

    try {
      final travelerQuery = await AppServices.db
          .collection('travelers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (travelerQuery.docs.isEmpty) {
        throw Exception(
          'No registered traveler was found for that email address.',
        );
      }

      final travelerDocument = travelerQuery.docs.first;
      final traveler = travelerDocument.data();

      final memberId =
      '${traveler['uid'] ?? travelerDocument.id}'.trim();

      final memberName =
      '${traveler['displayName'] ?? ''}'.trim();

      if (memberId.isEmpty) {
        throw Exception(
          'The traveler account has no valid user ID.',
        );
      }

      if (memberName.isEmpty) {
        throw Exception(
          'The traveler account has no display name.',
        );
      }

      if (memberId == leader.uid) {
        throw Exception(
          'You are already the leader of this group.',
        );
      }

      if ('${traveler['role'] ?? ''}'.toLowerCase() != 'traveler') {
        throw Exception(
          'Only traveler accounts can join a travel group.',
        );
      }

      if ('${traveler['status'] ?? ''}'.toLowerCase() != 'active') {
        throw Exception(
          'This traveler account is not active.',
        );
      }

      final latestGroupSnapshot = await _groupRef.get();

      if (!latestGroupSnapshot.exists) {
        throw Exception('Travel group was not found.');
      }

      final latestGroup =
          latestGroupSnapshot.data() ?? const <String, dynamic>{};

      final memberIds = List<String>.from(
        latestGroup['memberIds'] ?? const <String>[],
      );

      if (memberIds.contains(memberId)) {
        throw Exception(
          '$memberName is already a member of this group.',
        );
      }

      final invitationReference = AppServices.db
          .collection('group_invitations')
          .doc('${widget.groupId}_$memberId');

      final currentInvitation = await invitationReference.get();

      if (currentInvitation.data()?['status'] == 'pending') {
        throw Exception(
          'An invitation is already waiting for $memberName.',
        );
      }

      var leaderName = _groupMemberName(
        latestGroup,
        leader.uid,
      );

      if (leaderName.isEmpty) {
        leaderName = await _displayName(leader.uid);
      }

      await invitationReference.set(
        {
          'groupId': widget.groupId,
          'groupName':
          '${latestGroup['name'] ?? group['name'] ?? 'Travel Group'}',
          'leaderId': leader.uid,
          'leaderName': leaderName,
          'memberId': memberId,
          'memberName': memberName,
          'memberEmail': email,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'respondedAt': null,
        },
        SetOptions(merge: true),
      );

      await AppServices.notify(
        userId: memberId,
        title: 'Travel group invitation',
        message:
        '$leaderName invited you to join ${latestGroup['name'] ?? 'a travel group'}. '
            'Open Companion to accept or reject the invitation.',
        type: 'companion_group_invitation',
        referenceId: invitationReference.id,
      );

      if (mounted) {
        showMessage(
          context,
          'Invitation sent to $memberName.',
        );
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
      if (mounted) {
        setState(() {
          addingMember = false;
        });
      }
    }
  }

  Future<void> removeMember(
      Map<String, dynamic> group,
      String memberId,
      ) async {
    final leader = AppServices.auth.currentUser;

    if (leader == null) return;

    if ('${group['leaderId'] ?? ''}' != leader.uid) {
      return;
    }

    if (memberId == leader.uid) {
      return;
    }

    var memberName = _groupMemberName(
      group,
      memberId,
    );

    if (memberName.isEmpty) {
      memberName = await _displayName(memberId);
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          '$memberName will be removed from ${group['name'] ?? 'this travel group'}. '
              'Their location will no longer appear on the Group Map.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = AppServices.db.batch();

      batch.update(_groupRef, {
        'memberIds': FieldValue.arrayRemove([memberId]),
        'memberNames.$memberId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.delete(
        _groupRef.collection('locations').doc(memberId),
      );

      await batch.commit();

      await AppServices.notify(
        userId: memberId,
        title: 'Removed from travel group',
        message:
        'You were removed from ${group['name'] ?? 'the travel group'}.',
        type: 'companion_group',
        referenceId: widget.groupId,
      );

      if (mounted) {
        showMessage(
          context,
          '$memberName was removed.',
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  Future<void> _cancelInvitation(
      DocumentSnapshot<Map<String, dynamic>> invitation,
      ) async {
    try {
      await invitation.reference.update({
        'status': 'cancelled',
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage(
          context,
          'Invitation cancelled.',
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  Future<void> _updateLeaderLocation() async {
    final leader = AppServices.auth.currentUser;

    if (leader == null || updatingLocation) {
      return;
    }

    setState(() {
      updatingLocation = true;
    });

    try {
      final position = await determinePosition();

      final groupSnapshot = await _groupRef.get();

      final group =
          groupSnapshot.data() ?? widget.group;

      var displayName = _groupMemberName(
        group,
        leader.uid,
      );

      if (displayName.isEmpty) {
        displayName = await _displayName(leader.uid);
      }

      await _groupRef.collection('locations').doc(leader.uid).set(
        {
          'userId': leader.uid,
          'displayName': displayName,
          'role': 'leader',
          'location': GeoPoint(
            position.latitude,
            position.longitude,
          ),
          'approvedViewerIds': [leader.uid],
          'sharingEnabled': true,
          'sosActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        showMessage(
          context,
          'Your location was updated.',
        );
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
      if (mounted) {
        setState(() {
          updatingLocation = false;
        });
      }
    }
  }

  Future<void> resolveSos(
      DocumentReference<Map<String, dynamic>> alertReference,
      String senderId,
      ) async {
    try {
      final batch = AppServices.db.batch();

      batch.update(alertReference, {
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': AppServices.auth.currentUser?.uid,
      });

      if (senderId.isNotEmpty) {
        batch.set(
          _groupRef.collection('locations').doc(senderId),
          {
            'sosActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (mounted) {
        showMessage(
          context,
          'SOS alert marked as resolved.',
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  Future<void> _fitMapToLocations(
      Iterable<LatLng> locations,
      ) async {
    final controller = _mapController;
    final points = locations.toList();

    if (controller == null || points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          points.first,
          15,
        ),
      );
      return;
    }

    var minLatitude = points.first.latitude;
    var maxLatitude = points.first.latitude;
    var minLongitude = points.first.longitude;
    var maxLongitude = points.first.longitude;

    for (final point in points.skip(1)) {
      minLatitude = min(minLatitude, point.latitude);
      maxLatitude = max(maxLatitude, point.latitude);
      minLongitude = min(minLongitude, point.longitude);
      maxLongitude = max(maxLongitude, point.longitude);
    }

    if (minLatitude == maxLatitude &&
        minLongitude == maxLongitude) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          points.first,
          15,
        ),
      );
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            minLatitude,
            minLongitude,
          ),
          northeast: LatLng(
            maxLatitude,
            maxLongitude,
          ),
        ),
        70,
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupRef.snapshots(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState ==
            ConnectionState.waiting &&
            !groupSnapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final group =
            groupSnapshot.data?.data() ?? widget.group;

        final leaderId = '${group['leaderId'] ?? ''}';
        final isLeader = leaderId == uid;

        if (!isLeader) {
          return Scaffold(
            backgroundColor: ExplorerColors.background,
            appBar: AppBar(
              title: const Text('Group Management'),
            ),
            body: const ExplorerEmptyState(
              title: 'Leader Access Only',
              subtitle:
              'Only the group leader can manage members, view the Group Map, and review SOS alerts.',
              icon: Icons.lock_outline,
            ),
          );
        }

        final groupName =
            '${group['name'] ?? 'Travel Group'}';

        return Scaffold(
          backgroundColor: ExplorerColors.background,
          appBar: AppBar(
            title: Column(
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
                Text(
                  'Group Code: ${group['code'] ?? '-'}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Copy group code',
                onPressed: () => _copyGroupCode(group),
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.map_outlined),
                  text: 'Map',
                ),
                Tab(
                  icon: Icon(Icons.groups_outlined),
                  text: 'Members',
                ),
                Tab(
                  icon: Icon(
                    Icons.notification_important_outlined,
                  ),
                  text: 'SOS',
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMapTab(group, uid),
              _buildMembersTab(group, uid),
              _buildSosTab(group, uid),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapTab(
      Map<String, dynamic> group,
      String uid,
      ) {
    final memberIds = List<String>.from(
      group['memberIds'] ?? const <String>[],
    );

    final memberNames = Map<String, dynamic>.from(
      group['memberNames'] ?? const <String, dynamic>{},
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _groupRef
          .collection('locations')
          .where('approvedViewerIds', arrayContains: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load group locations.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final locationDocuments =
            snapshot.data?.docs ?? [];

        final positions = <String, LatLng>{};
        final locationData =
        <String, Map<String, dynamic>>{};
        final sosMembers = <String>{};

        for (final document in locationDocuments) {
          final data = document.data();
          final location = data['location'];

          if (location is! GeoPoint) {
            continue;
          }

          positions[document.id] = LatLng(
            location.latitude,
            location.longitude,
          );

          locationData[document.id] = data;

          if (data['sosActive'] == true) {
            sosMembers.add(document.id);
          }
        }

        if (positions.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _fitMapToLocations(positions.values);
          });
        }

        final markers = positions.entries.map((entry) {
          final isLeader = entry.key == '${group['leaderId'] ?? ''}';
          final isSos = sosMembers.contains(entry.key);

          final name =
              '${memberNames[entry.key] ?? locationData[entry.key]?['displayName'] ?? (isLeader ? 'Group Leader' : 'Group Member')}';

          return Marker(
            markerId: MarkerId(entry.key),
            position: entry.value,
            infoWindow: InfoWindow(
              title: isSos
                  ? '$name - SOS'
                  : name,
              snippet: isLeader
                  ? 'Group Leader'
                  : 'Group Member',
            ),
            icon: BitmapDescriptor.defaultMarker,
          );
        }).toSet();

        final ownPosition = positions[uid];

        final polylines = <Polyline>{};

        if (ownPosition != null) {
          for (final entry in positions.entries) {
            if (entry.key == uid) continue;
            if (!sosMembers.contains(entry.key)) continue;

            polylines.add(
              Polyline(
                polylineId: PolylineId(
                  'sos_${uid}_${entry.key}',
                ),
                points: [
                  ownPosition,
                  entry.value,
                ],
                width: 6,
                color: ExplorerColors.danger,
              ),
            );
          }
        }

        final initialPosition = positions.isNotEmpty
            ? (ownPosition ?? positions.values.first)
            : const LatLng(
          5.4141,
          100.3288,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            28,
          ),
          children: [
            ExplorerCard(
              radius: 12,
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group Map',
                              style: TextStyle(
                                color: ExplorerColors.navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'All accepted members who enabled location sharing are shown below.',
                              style: TextStyle(
                                color: ExplorerColors.muted,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ExplorerStatusBadge(
                        label:
                        '${positions.length}/${memberIds.length} SHARING',
                        tone: positions.length ==
                            memberIds.length
                            ? ExplorerStatusTone.success
                            : ExplorerStatusTone.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: updatingLocation
                          ? null
                          : _updateLeaderLocation,
                      icon: updatingLocation
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons.my_location,
                      ),
                      label: Text(
                        updatingLocation
                            ? 'Updating Location...'
                            : 'Update My Location',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 430,
              child: ClipRRect(
                borderRadius:
                BorderRadius.circular(14),
                child: GoogleMap(
                  initialCameraPosition:
                  CameraPosition(
                    target: initialPosition,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;

                    WidgetsBinding.instance
                        .addPostFrameCallback((_) {
                      _fitMapToLocations(
                        positions.values,
                      );
                    });
                  },
                  markers: markers,
                  polylines: polylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                ),
              ),
            ),

            const SizedBox(height: 18),

            ExplorerSectionTitle(
              'Location Status',
              subtitle:
              '${positions.length} of ${memberIds.length} group members are currently sharing a location.',
            ),

            const SizedBox(height: 10),

            ...memberIds.map((memberId) {
              final isLeader =
                  memberId == '${group['leaderId'] ?? ''}';

              final data =
              locationData[memberId];

              final isSharing =
                  data?['sharingEnabled'] == true &&
                      data?['location'] is GeoPoint;

              final lastUpdated =
              asDate(data?['updatedAt']);

              final storedName =
              '${memberNames[memberId] ?? data?['displayName'] ?? ''}'
                  .trim();

              Widget buildCard(String name) {
                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: 9),
                  child: ExplorerCard(
                    radius: 12,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isLeader
                            ? ExplorerColors.goldSoft
                            : ExplorerColors.navySoft,
                        foregroundColor:
                        ExplorerColors.navy,
                        child: Icon(
                          isLeader
                              ? Icons
                              .workspace_premium_outlined
                              : Icons.person_outline,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: ExplorerColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        isSharing
                            ? lastUpdated == null
                            ? 'Sharing location'
                            : 'Sharing • Updated ${DateFormat.jm().format(lastUpdated)}'
                            : 'Waiting for location',
                        style: TextStyle(
                          color: isSharing
                              ? ExplorerColors.success
                              : ExplorerColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Icon(
                        isSharing
                            ? Icons.location_on
                            : Icons.location_off_outlined,
                        color: isSharing
                            ? ExplorerColors.success
                            : ExplorerColors.muted,
                      ),
                    ),
                  ),
                );
              }

              if (storedName.isNotEmpty) {
                return buildCard(storedName);
              }

              return FutureBuilder<String>(
                future: _displayName(memberId),
                builder: (context, nameSnapshot) {
                  return buildCard(
                    nameSnapshot.data ??
                        'Group Member',
                  );
                },
              );
            }),

            if (sosMembers.isNotEmpty) ...[
              const SizedBox(height: 8),
              const ExplorerSectionTitle(
                'Active SOS',
                subtitle:
                'A route line is shown from the leader to each active SOS member.',
              ),
              const SizedBox(height: 10),
              ...sosMembers.map((memberId) {
                final memberPosition =
                positions[memberId];

                if (memberPosition == null ||
                    ownPosition == null) {
                  return const SizedBox.shrink();
                }

                final distanceMeters =
                Geolocator.distanceBetween(
                  ownPosition.latitude,
                  ownPosition.longitude,
                  memberPosition.latitude,
                  memberPosition.longitude,
                );

                final distanceKm =
                    distanceMeters / 1000;

                const walkingSpeedKmPerHour =
                4.5;

                final approximateMinutes =
                ((distanceKm /
                    walkingSpeedKmPerHour) *
                    60)
                    .ceil();

                final memberName =
                    '${memberNames[memberId] ?? locationData[memberId]?['displayName'] ?? 'SOS Member'}';

                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: 9),
                  child: ExplorerCard(
                    backgroundColor:
                    ExplorerColors.dangerSoft,
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor:
                          ExplorerColors.danger,
                          foregroundColor:
                          Colors.white,
                          child:
                          Icon(Icons.sos_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                memberName,
                                style: const TextStyle(
                                  color:
                                  ExplorerColors.danger,
                                  fontWeight:
                                  FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Approx. ${distanceKm.toStringAsFixed(2)} km • $approximateMinutes min walking',
                                style: const TextStyle(
                                  color:
                                  ExplorerColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMembersTab(
      Map<String, dynamic> group,
      String uid,
      ) {
    final memberIds = List<String>.from(
      group['memberIds'] ?? const <String>[],
    );

    final memberNames = Map<String, dynamic>.from(
      group['memberNames'] ?? const <String, dynamic>{},
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        28,
      ),
      children: [
        ExplorerCard(
          radius: 12,
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ExplorerLabeledValue(
                      label: 'Members',
                      value: '${memberIds.length}',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: addingMember
                        ? null
                        : () => addMember(group),
                    icon: addingMember
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.person_add_alt_1_outlined,
                    ),
                    label: Text(
                      addingMember
                          ? 'Sending...'
                          : 'Invite Member',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Invited travelers are not added immediately. They must accept the invitation and allow location access first.',
                style: TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const ExplorerSectionTitle(
          'Current Members',
          subtitle:
          'Only accepted members are shown here.',
        ),

        const SizedBox(height: 10),

        ...memberIds.map((memberId) {
          final isCurrentUser = memberId == uid;

          final isGroupLeader =
              memberId == '${group['leaderId'] ?? ''}';

          final storedName =
          '${memberNames[memberId] ?? ''}'
              .trim();

          Widget buildMemberCard(String name) {
            return Padding(
              padding:
              const EdgeInsets.only(bottom: 9),
              child: ExplorerCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isGroupLeader
                        ? ExplorerColors.goldSoft
                        : ExplorerColors.navySoft,
                    foregroundColor:
                    ExplorerColors.navy,
                    child: Icon(
                      isGroupLeader
                          ? Icons
                          .workspace_premium_outlined
                          : Icons.person_outline,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    isGroupLeader
                        ? 'Group Leader'
                        : isCurrentUser
                        ? 'You • Group Member'
                        : 'Group Member',
                  ),
                  trailing:
                  isCurrentUser || isGroupLeader
                      ? null
                      : PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value ==
                          'remove') {
                        removeMember(
                          group,
                          memberId,
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'remove',
                        child: ListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          leading: Icon(
                            Icons
                                .person_remove_outlined,
                            color:
                            ExplorerColors
                                .danger,
                          ),
                          title: Text(
                            'Remove member',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (storedName.isNotEmpty) {
            return buildMemberCard(storedName);
          }

          return FutureBuilder<String>(
            future: _displayName(memberId),
            builder: (context, snapshot) {
              return buildMemberCard(
                snapshot.data ?? 'Group Member',
              );
            },
          );
        }),

        const SizedBox(height: 14),

        const ExplorerSectionTitle(
          'Pending Invitations',
          subtitle:
          'These travelers have not joined the group yet.',
        ),

        const SizedBox(height: 10),

        StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: AppServices.db
              .collection('group_invitations')
              .where(
            'groupId',
            isEqualTo: widget.groupId,
          )
              .snapshots(),
          builder: (context, snapshot) {
            final pending =
            (snapshot.data?.docs ?? []).where(
                  (document) {
                return document.data()['status'] ==
                    'pending';
              },
            ).toList();

            if (pending.isEmpty) {
              return const ExplorerEmptyState(
                title: 'No Pending Invitations',
                subtitle:
                'Use Invite Member to invite a traveler by registered email.',
                icon: Icons.mark_email_read_outlined,
              );
            }

            return Column(
              children: pending.map((document) {
                final data = document.data();

                final memberName =
                    '${data['memberName'] ?? 'Traveler'}';

                final memberEmail =
                    '${data['memberEmail'] ?? ''}';

                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: 9),
                  child: ExplorerCard(
                    backgroundColor:
                    ExplorerColors.goldSoft,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor:
                        ExplorerColors.navy,
                        foregroundColor:
                        Colors.white,
                        child: Icon(
                          Icons
                              .mark_email_unread_outlined,
                        ),
                      ),
                      title: Text(
                        memberName,
                        style: const TextStyle(
                          color:
                          ExplorerColors.navy,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        memberEmail.isEmpty
                            ? 'Waiting for response'
                            : '$memberEmail\nWaiting for response',
                      ),
                      isThreeLine:
                      memberEmail.isNotEmpty,
                      trailing:
                      OutlinedButton(
                        onPressed: () =>
                            _cancelInvitation(
                              document,
                            ),
                        child:
                        const Text('Cancel'),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSosTab(
      Map<String, dynamic> group,
      String uid,
      ) {
    final memberNames = Map<String, dynamic>.from(
      group['memberNames'] ?? const <String, dynamic>{},
    );

    return StreamBuilder<
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

        final alerts =
        (snapshot.data?.docs ?? []).where(
              (document) {
            final data = document.data();

            return data['leaderId'] == uid &&
                data['status'] == 'active';
          },
        ).toList()
          ..sort((a, b) {
            final first =
                asDate(a.data()['lastTriggeredAt']) ??
                    asDate(a.data()['createdAt']) ??
                    DateTime(2000);

            final second =
                asDate(b.data()['lastTriggeredAt']) ??
                    asDate(b.data()['createdAt']) ??
                    DateTime(2000);

            return second.compareTo(first);
          });

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            28,
          ),
          children: [
            ExplorerCard(
              radius: 12,
              backgroundColor: alerts.isEmpty
                  ? ExplorerColors.surface
                  : ExplorerColors.dangerSoft,
              borderColor: alerts.isEmpty
                  ? ExplorerColors.border
                  : const Color(0xFFF6B8AE),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: alerts.isEmpty
                        ? ExplorerColors.navySoft
                        : ExplorerColors.danger,
                    foregroundColor: alerts.isEmpty
                        ? ExplorerColors.navy
                        : Colors.white,
                    child: Icon(
                      alerts.isEmpty
                          ? Icons.shield_outlined
                          : Icons
                          .notification_important,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          alerts.isEmpty
                              ? 'No Active SOS Alerts'
                              : '${alerts.length} Active SOS Alert${alerts.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: alerts.isEmpty
                                ? ExplorerColors.navy
                                : ExplorerColors.danger,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Member SOS alerts appear here in real time.',
                          style: TextStyle(
                            color:
                            ExplorerColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (alerts.isEmpty)
              const ExplorerEmptyState(
                title: 'Everyone is Safe',
                subtitle:
                'When a member presses SOS, the alert and latest location will appear here.',
                icon: Icons
                    .health_and_safety_outlined,
              )
            else
              ...alerts.map((alert) {
                final data = alert.data();

                final senderId =
                    '${data['senderId'] ?? ''}';

                final senderName =
                    '${memberNames[senderId] ?? data['senderName'] ?? 'Group Member'}';

                final time =
                    asDate(data['lastTriggeredAt']) ??
                        asDate(data['createdAt']);

                final triggerCount =
                    data['triggerCount'] ?? 1;

                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: 10),
                  child: ExplorerCard(
                    backgroundColor:
                    ExplorerColors.dangerSoft,
                    borderColor:
                    const Color(0xFFF6B8AE),
                    radius: 12,
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor:
                              ExplorerColors.danger,
                              foregroundColor:
                              Colors.white,
                              child: Icon(
                                Icons.sos_rounded,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    '$senderName needs help',
                                    style:
                                    const TextStyle(
                                      color:
                                      ExplorerColors
                                          .danger,
                                      fontSize: 15,
                                      fontWeight:
                                      FontWeight
                                          .w800,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 3,
                                  ),
                                  Text(
                                    time == null
                                        ? 'Latest location received'
                                        : DateFormat
                                        .yMMMd()
                                        .add_jm()
                                        .format(
                                      time,
                                    ),
                                    style:
                                    const TextStyle(
                                      color:
                                      ExplorerColors
                                          .muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ExplorerStatusBadge(
                              label: triggerCount == 1
                                  ? 'ACTIVE'
                                  : 'ACTIVE ×$triggerCount',
                              tone:
                              ExplorerStatusTone
                                  .danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child:
                              FilledButton.icon(
                                onPressed: () {
                                  _tabController
                                      .animateTo(0);
                                },
                                style:
                                FilledButton
                                    .styleFrom(
                                  backgroundColor:
                                  ExplorerColors
                                      .navy,
                                ),
                                icon: const Icon(
                                  Icons.map_outlined,
                                ),
                                label: const Text(
                                  'View on Map',
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child:
                              OutlinedButton.icon(
                                onPressed: () =>
                                    resolveSos(
                                      alert.reference,
                                      senderId,
                                    ),
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
                                ),
                                icon: const Icon(
                                  Icons
                                      .check_circle_outline,
                                ),
                                label: const Text(
                                  'Resolve',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
