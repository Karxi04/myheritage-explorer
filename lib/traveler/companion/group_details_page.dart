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

  DocumentReference<Map<String, dynamic>> get _groupRef =>
      AppServices.db.collection('travel_groups').doc(widget.groupId);

  Future<void> requestLocation(String memberKey) async {
    final uid = AppServices.auth.currentUser!.uid;
    final targetUid = await _resolveTravelerUid(memberKey);

    final requestSnapshot = await AppServices.db
        .collection('location_requests')
        .where('groupId', isEqualTo: widget.groupId)
        .get();

    final existing = requestSnapshot.docs.where((document) {
      final data = document.data();

      return data['requesterId'] == uid &&
          data['targetId'] == targetUid &&
          data['status'] == 'pending';
    });

    if (existing.isNotEmpty) {
      if (mounted) {
        showMessage(
          context,
          'A request is already pending.',
        );
      }
      return;
    }

    await AppServices.db.collection('location_requests').add({
      'groupId': widget.groupId,
      'requesterId': uid,
      'targetId': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await AppServices.notify(
      userId: targetUid,
      title: 'Location sharing request',
      message:
      'A companion requested your location in ${widget.group['name'] ?? 'the group'}.',
      type: 'location_request',
      referenceId: widget.groupId,
    );

    if (mounted) {
      showMessage(
        context,
        'Location request sent.',
      );
    }
  }

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
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _travelerProfile(String memberKey) async {
    try {
      // Current data structure: travelers/{FirebaseAuthUid}
      final directProfile = await AppServices.db
          .collection('travelers')
          .doc(memberKey)
          .get();

      if (directProfile.exists) {
        return directProfile.data();
      }

      // Compatibility with older traveler records whose document ID is not UID.
      final byUid = await AppServices.db
          .collection('travelers')
          .where('uid', isEqualTo: memberKey)
          .limit(1)
          .get();

      if (byUid.docs.isNotEmpty) {
        return byUid.docs.first.data();
      }

      return null;
    } catch (error) {
      debugPrint('Error loading traveler profile for $memberKey: $error');
      return null;
    }
  }

  Future<String> _resolveTravelerUid(String memberKey) async {
    final profile = await _travelerProfile(memberKey);
    final storedUid = '${profile?['uid'] ?? ''}'.trim();

    if (storedUid.isNotEmpty) {
      return storedUid;
    }

    return memberKey;
  }

  String _nameFromProfile(Map<String, dynamic>? data) {
    if (data == null) return '';

    return '${data['displayName'] ?? ''}'.trim();
  }

  Future<String> _displayName(String uid) async {
    try {
      // First try the normal structure:
      // travelers/{Firebase Auth UID}
      final profile = await AppServices.db
          .collection('travelers')
          .doc(uid)
          .get();

      if (profile.exists) {
        final data = profile.data();

        final displayName =
        '${data?['displayName'] ?? ''}'.trim();

        if (displayName.isNotEmpty) {
          return displayName;
        }
      }

      // Fallback in case the Firestore document ID
      // is different from the Firebase Auth UID
      final query = await AppServices.db
          .collection('travelers')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();

        final displayName =
        '${data['displayName'] ?? ''}'.trim();

        if (displayName.isNotEmpty) {
          return displayName;
        }
      }

      return 'Unknown User';
    } catch (error) {
      debugPrint(
        'Failed to retrieve displayName for $uid: $error',
      );

      return 'Unknown User';
    }
  }

  Future<void> _copyGroupCode(Map<String, dynamic> group) async {
    final code = '${group['code'] ?? ''}'.trim();
    if (code.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: code));

    if (mounted) {
      showMessage(context, 'Group code copied.');
    }
  }

  Future<String?> _askForMemberEmail() async {
    final emailController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Group Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the registered email address of the traveler you want to add.',
              style: TextStyle(color: ExplorerColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Traveler Email',
                hintText: 'traveler@example.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              onSubmitted: (_) {
                Navigator.pop(
                  dialogContext,
                  emailController.text.trim().toLowerCase(),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              dialogContext,
              emailController.text.trim().toLowerCase(),
            ),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Add Member'),
          ),
        ],
      ),
    );

    emailController.dispose();
    return result;
  }

  Future<void> addMember(Map<String, dynamic> group) async {
    final uid = AppServices.auth.currentUser?.uid;

    if (uid == null || '${group['leaderId'] ?? ''}' != uid) {
      if (mounted) {
        showMessage(
          context,
          'Only the group leader can add members.',
          error: true,
        );
      }
      return;
    }

    final normalizedEmail = await _askForMemberEmail();

    if (!mounted ||
        normalizedEmail == null ||
        normalizedEmail.trim().isEmpty) {
      return;
    }

    setState(() => addingMember = true);

    try {
      final travelers = await AppServices.db
          .collection('travelers')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (travelers.docs.isEmpty) {
        throw Exception(
          'No registered traveler was found for that email address.',
        );
      }

      final memberDocument = travelers.docs.first;
      final member = memberDocument.data();
      final memberDocumentId = memberDocument.id;
      final memberUid =
          '${member['uid'] ?? memberDocument.id}';

      if (memberUid.isEmpty) {
        throw Exception('The traveler account has no valid user ID.');
      }

      final memberIds = List<String>.from(
        group['memberIds'] ?? const <String>[],
      );

      if ('${member['status'] ?? ''}' != 'active') {
        throw Exception('This traveler account is not active.');
      }

      if ('${member['role'] ?? ''}' != 'traveler') {
        throw Exception('Only traveler accounts can join a travel group.');
      }

      if (memberIds.contains(memberUid) ||
          memberIds.contains(memberDocumentId)) {
        throw Exception('This traveler is already a group member.');
      }

      await _groupRef.update({
        'memberIds': FieldValue.arrayUnion([memberUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AppServices.notify(
        userId: memberUid,
        title: 'Added to a travel group',
        message:
        'You were added to ${group['name'] ?? 'a travel group'} by the group leader.',
        type: 'companion_group',
        referenceId: widget.groupId,
      );

      if (mounted) {
        showMessage(
          context,
          '${_nameFromProfile(member).isNotEmpty ? _nameFromProfile(member) : normalizedEmail} was added.',
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
      if (mounted) setState(() => addingMember = false);
    }
  }

  Future<void> removeMember(
      Map<String, dynamic> group,
      String memberId,
      ) async {
    final uid = AppServices.auth.currentUser?.uid;

    if (uid == null ||
        '${group['leaderId'] ?? ''}' != uid ||
        memberId == uid) {
      return;
    }

    final memberName = await _displayName(memberId);
    final memberUid = await _resolveTravelerUid(memberId);

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          '$memberName will be removed from ${group['name'] ?? 'this travel group'}.',
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
      await _groupRef.update({
        'memberIds': FieldValue.arrayRemove([memberId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Location documents should use the Firebase Auth UID.
      try {
        await _groupRef.collection('locations').doc(memberUid).delete();
      } catch (_) {}

      // Also remove an old location document if this group stored a legacy
      // traveler document ID instead of the Firebase Auth UID.
      if (memberUid != memberId) {
        try {
          await _groupRef.collection('locations').doc(memberId).delete();
        } catch (_) {}
      }

      await AppServices.notify(
        userId: memberUid,
        title: 'Removed from travel group',
        message: 'You were removed from ${group['name'] ?? 'the group'}.',
        type: 'companion_group',
        referenceId: widget.groupId,
      );

      if (mounted) {
        showMessage(context, '$memberName was removed.');
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
    final uid = AppServices.auth.currentUser?.uid;
    if (uid == null || updatingLocation) return;

    setState(() => updatingLocation = true);

    try {
      final position = await determinePosition();

      await _groupRef.collection('locations').doc(uid).set({
        'userId': uid,
        'location': GeoPoint(position.latitude, position.longitude),
        'approvedViewerIds': [uid],
        'sosActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        showMessage(context, 'Your latest location was updated.');
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
      if (mounted) setState(() => updatingLocation = false);
    }
  }

  Future<void> resolveSos(
      DocumentReference<Map<String, dynamic>> alertReference,
      String senderId,
      ) async {
    try {
      await alertReference.update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': AppServices.auth.currentUser?.uid,
      });

      if (senderId.isNotEmpty) {
        await _groupRef.collection('locations').doc(senderId).set({
          'sosActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        showMessage(context, 'SOS alert marked as resolved.');
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

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in first.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupRef.snapshots(),
      builder: (context, groupSnapshot) {
        if (groupSnapshot.connectionState == ConnectionState.waiting &&
            !groupSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final group = groupSnapshot.data?.data() ?? widget.group;
        final leaderId = '${group['leaderId'] ?? ''}';
        final isLeader = leaderId == uid;

        if (!isLeader) {
          return Scaffold(
            backgroundColor: ExplorerColors.background,
            appBar: AppBar(title: const Text('Group Management')),
            body: const ExplorerEmptyState(
              title: 'Leader Access Only',
              subtitle:
              'Only the group leader can manage members, view the group map, and review SOS alerts.',
              icon: Icons.lock_outline,
            ),
          );
        }

        final groupName = '${group['name'] ?? 'Travel Group'}';

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
                Tab(icon: Icon(Icons.map_outlined), text: 'Map'),
                Tab(icon: Icon(Icons.groups_outlined), text: 'Members'),
                Tab(
                  icon: Icon(Icons.notification_important_outlined),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        ExplorerCard(
          radius: 12,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Group Map',
                      style: TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Only locations shared with you and active SOS locations are displayed.',
                      style: TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: updatingLocation ? null : _updateLeaderLocation,
                icon: updatingLocation
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.my_location),
                label: Text(updatingLocation ? 'Updating' : 'My Location'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 430,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _groupRef
                .collection('locations')
                .where('approvedViewerIds', arrayContains: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ExplorerCard(
                  child: Center(
                    child: Text(
                      'Unable to load locations.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final documents = snapshot.data?.docs ?? [];
              final positions = <String, LatLng>{};
              final sosMembers = <String>{};

              for (final document in documents) {
                final data = document.data();
                final location = data['location'];

                if (location is! GeoPoint) continue;

                positions[document.id] = LatLng(
                  location.latitude,
                  location.longitude,
                );

                if (data['sosActive'] == true) {
                  sosMembers.add(document.id);
                }
              }

              if (positions.isEmpty) {
                return const ExplorerEmptyState(
                  title: 'No Locations Available',
                  subtitle:
                  'Update your location or wait for a member to send an SOS alert.',
                  icon: Icons.location_off_outlined,
                );
              }

              final ownPosition = positions[uid];

              final markers = positions.entries.map((entry) {
                final isCurrentUser = entry.key == uid;
                final hasSos = sosMembers.contains(entry.key);

                return Marker(
                  markerId: MarkerId(entry.key),
                  position: entry.value,
                  infoWindow: InfoWindow(
                    title: isCurrentUser
                        ? 'You - Group Leader'
                        : hasSos
                        ? 'SOS Companion'
                        : 'Companion',
                  ),
                  icon: hasSos
                      ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  )
                      : isCurrentUser
                      ? BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure,
                  )
                      : BitmapDescriptor.defaultMarker,
                );
              }).toSet();

              final polylines = <Polyline>{};

              if (ownPosition != null) {
                for (final entry in positions.entries) {
                  if (entry.key == uid) continue;

                  final isSos = sosMembers.contains(entry.key);

                  polylines.add(
                    Polyline(
                      polylineId: PolylineId('${uid}_${entry.key}'),
                      points: [ownPosition, entry.value],
                      width: isSos ? 6 : 4,
                      color: isSos
                          ? ExplorerColors.danger
                          : ExplorerColors.navy,
                    ),
                  );
                }
              }

              final initialPosition = ownPosition ?? positions.values.first;

              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialPosition,
                    zoom: 14,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _groupRef
              .collection('locations')
              .where('approvedViewerIds', arrayContains: uid)
              .snapshots(),
          builder: (context, snapshot) {
            final documents = snapshot.data?.docs ?? [];

            final ownDocument = documents.where((document) {
              return document.id == uid &&
                  document.data()['location'] is GeoPoint;
            }).toList();

            if (ownDocument.isEmpty) {
              return const ExplorerCard(
                child: Text(
                  'Update your location to calculate approximate distance and time to an SOS companion.',
                  style: TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                  ),
                ),
              );
            }

            final ownGeo = ownDocument.first.data()['location'] as GeoPoint;

            final sosDocuments = documents.where((document) {
              return document.id != uid &&
                  document.data()['sosActive'] == true &&
                  document.data()['location'] is GeoPoint;
            }).toList();

            if (sosDocuments.isEmpty) {
              return const ExplorerCard(
                child: Text(
                  'No active SOS companion is currently shown on the map.',
                  style: TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                  ),
                ),
              );
            }

            return Column(
              children: sosDocuments.map((document) {
                final geo = document.data()['location'] as GeoPoint;

                final distanceMeters = Geolocator.distanceBetween(
                  ownGeo.latitude,
                  ownGeo.longitude,
                  geo.latitude,
                  geo.longitude,
                );

                final distanceKm = distanceMeters / 1000;
                const walkingSpeedKmPerHour = 4.5;
                final approximateMinutes =
                ((distanceKm / walkingSpeedKmPerHour) * 60).ceil();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: ExplorerCard(
                    backgroundColor: ExplorerColors.dangerSoft,
                    borderColor: const Color(0xFFF6B8AE),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: ExplorerColors.danger,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.sos_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _displayName(document.id),
                            builder: (context, nameSnapshot) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nameSnapshot.data ?? 'SOS Companion',
                                    style: const TextStyle(
                                      color: ExplorerColors.danger,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Approx. ${distanceKm.toStringAsFixed(2)} km • $approximateMinutes min walking',
                                    style: const TextStyle(
                                      color: ExplorerColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
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

  Widget _buildMembersTab(
      Map<String, dynamic> group,
      String uid,
      ) {
    final memberIds = List<String>.from(
      group['memberIds'] ?? const <String>[],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        ExplorerCard(
          radius: 12,
          child: Row(
            children: [
              Expanded(
                child: ExplorerLabeledValue(
                  label: 'Members',
                  value: '${memberIds.length}',
                ),
              ),
              FilledButton.icon(
                onPressed: addingMember ? null : () => addMember(group),
                icon: addingMember
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.person_add_alt_1_outlined),
                label: Text(addingMember ? 'Adding...' : 'Add Member'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ...memberIds.map(
              (memberId) => FutureBuilder<String>(
            key: ValueKey('travel-group-member-$memberId'),
            future: _displayName(memberId),
            builder: (context, snapshot) {
              final memberName =
              snapshot.connectionState == ConnectionState.waiting
                  ? 'Loading...'
                  : snapshot.data ?? 'Unknown User';

              final isCurrentUser = memberId == uid;

              final isGroupLeader =
                  memberId == '${group['leaderId'] ?? ''}';

              return ExplorerCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,

                  leading: CircleAvatar(
                    backgroundColor: isGroupLeader
                        ? ExplorerColors.goldSoft
                        : ExplorerColors.navySoft,
                    foregroundColor: ExplorerColors.navy,
                    child: Icon(
                      isGroupLeader
                          ? Icons.workspace_premium_outlined
                          : Icons.person_outline,
                    ),
                  ),

                  title: Text(
                    memberName,
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

                  trailing: isCurrentUser
                      ? null
                      : PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'request') {
                        requestLocation(memberId);
                      } else if (value == 'remove') {
                        removeMember(group, memberId);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'request',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.location_searching,
                          ),
                          title: Text(
                            'Request location',
                          ),
                        ),
                      ),

                      if ('${group['leaderId'] ?? ''}' == uid &&
                          !isGroupLeader)
                        const PopupMenuItem(
                          value: 'remove',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.person_remove_outlined,
                              color: ExplorerColors.danger,
                            ),
                            title: Text(
                              'Remove member',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSosTab(
      Map<String, dynamic> group,
      String uid,
      ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('sos_alerts')
          .where('groupId', isEqualTo: widget.groupId)
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

        final alerts = (snapshot.data?.docs ?? []).where((document) {
          final data = document.data();
          return data['leaderId'] == uid && data['status'] == 'active';
        }).toList()
          ..sort((a, b) {
            final first = asDate(a.data()['lastTriggeredAt']) ??
                asDate(a.data()['createdAt']) ??
                DateTime(2000);
            final second = asDate(b.data()['lastTriggeredAt']) ??
                asDate(b.data()['createdAt']) ??
                DateTime(2000);
            return second.compareTo(first);
          });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
                    foregroundColor:
                    alerts.isEmpty ? ExplorerColors.navy : Colors.white,
                    child: Icon(
                      alerts.isEmpty
                          ? Icons.shield_outlined
                          : Icons.notification_important,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alerts.isEmpty
                              ? 'No Active SOS Alerts'
                              : '${alerts.length} Active SOS Alert${alerts.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: alerts.isEmpty
                                ? ExplorerColors.navy
                                : ExplorerColors.danger,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Member SOS alerts appear here in real time.',
                          style: TextStyle(
                            color: ExplorerColors.muted,
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
                icon: Icons.health_and_safety_outlined,
              )
            else
              ...alerts.map(
                    (alert) {
                  final data = alert.data();
                  final senderId = '${data['senderId'] ?? ''}';
                  final storedSenderName =
                  '${data['senderName'] ?? ''}'.trim();
                  final time = asDate(data['lastTriggeredAt']) ??
                      asDate(data['createdAt']);
                  final triggerCount = data['triggerCount'] ?? 1;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExplorerCard(
                      backgroundColor: ExplorerColors.dangerSoft,
                      borderColor: const Color(0xFFF6B8AE),
                      radius: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: ExplorerColors.danger,
                                foregroundColor: Colors.white,
                                child: Icon(Icons.sos_rounded),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<String>(
                                      future: storedSenderName.isNotEmpty &&
                                          storedSenderName != senderId
                                          ? Future<String>.value(storedSenderName)
                                          : _displayName(senderId),
                                      builder: (context, nameSnapshot) {
                                        final senderName =
                                            nameSnapshot.data ?? 'Loading...';

                                        return Text(
                                          '$senderName needs help',
                                          style: const TextStyle(
                                            color: ExplorerColors.danger,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      time == null
                                          ? 'Latest location received'
                                          : DateFormat.yMMMd()
                                          .add_jm()
                                          .format(time),
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
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
                                tone: ExplorerStatusTone.danger,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    _tabController.animateTo(0);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: ExplorerColors.navy,
                                  ),
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('View on Map'),
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => resolveSos(
                                    alert.reference,
                                    senderId,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: ExplorerColors.danger,
                                    side: const BorderSide(
                                      color: ExplorerColors.danger,
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Resolve'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
