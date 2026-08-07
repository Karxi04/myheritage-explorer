part of '../traveler_pages.dart';

class GroupDetailsPage extends StatefulWidget {
  const GroupDetailsPage({
    super.key,
    required this.groupId,
    required this.group,
  });

  final String groupId;
  final Map<String, dynamic> group;

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  bool addingMember = false;
  bool sendingSos = false;

  DocumentReference<Map<String, dynamic>> get _groupRef =>
      AppServices.db.collection('travel_groups').doc(widget.groupId);

  Future<String> _displayName(String uid) async {
    try {
      final profile = await AppServices.userRef(uid).get();
      final data = profile.data() ?? const <String, dynamic>{};
      return '${data['displayName'] ?? data['fullName'] ?? data['name'] ?? uid}';
    } catch (_) {
      return uid;
    }
  }

  Future<void> _copyGroupCode(Map<String, dynamic> group) async {
    final code = '${group['code'] ?? ''}'.trim();
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) showMessage(context, 'Group code copied.');
  }

  Future<String?> _askForMemberEmail() async {
    var enteredEmail = '';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        void submit() {
          final normalizedEmail = enteredEmail.trim().toLowerCase();

          if (normalizedEmail.isEmpty) {
            showMessage(
              dialogContext,
              'Please enter the traveler’s registered email address.',
              error: true,
            );
            return;
          }

          FocusScope.of(dialogContext).unfocus();
          Navigator.of(dialogContext).pop(normalizedEmail);
        }

        return AlertDialog(
          title: const Text('Add Group Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the traveler’s registered email address.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (value) => enteredEmail = value,
                onFieldSubmitted: (_) => submit(),
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
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add Member'),
            ),
          ],
        );
      },
    );
  }

  Future<void> addMember(Map<String, dynamic> group) async {
    final uid = AppServices.auth.currentUser!.uid;
    if ('${group['leaderId'] ?? ''}' != uid) {
      showMessage(
        context,
        'Only the group leader can add members.',
        error: true,
      );
      return;
    }

    final normalizedEmail = await _askForMemberEmail();
    if (!mounted ||
        normalizedEmail == null ||
        normalizedEmail.isEmpty) {
      return;
    }

    // Wait until the dialog route and keyboard are fully removed before the
    // Firestore stream rebuilds the members section.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    setState(() => addingMember = true);
    try {
      final users = await AppServices.db
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (users.docs.isEmpty) {
        throw Exception(
          'No registered traveler was found for that email address.',
        );
      }

      final memberDocument = users.docs.first;
      final member = memberDocument.data();
      final memberId = memberDocument.id;
      final memberIds = List<String>.from(
        group['memberIds'] ?? const <String>[],
      );

      if ('${member['status'] ?? ''}' != 'active') {
        throw Exception('This traveler account is not active.');
      }
      if ('${member['role'] ?? ''}' != 'traveler') {
        throw Exception('Only traveler accounts can join a travel group.');
      }
      if (memberIds.contains(memberId)) {
        throw Exception('This traveler is already a group member.');
      }

      await _groupRef.update({
        'memberIds': FieldValue.arrayUnion([memberId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AppServices.notify(
        userId: memberId,
        title: 'Added to a travel group',
        message:
            'You were added to ${group['name'] ?? 'a travel group'} by the group leader.',
        type: 'companion_group',
        referenceId: widget.groupId,
      );

      if (mounted) {
        showMessage(
          context,
          '${member['displayName'] ?? normalizedEmail} was added.',
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
    final uid = AppServices.auth.currentUser!.uid;
    if ('${group['leaderId'] ?? ''}' != uid || memberId == uid) return;

    final name = await _displayName(memberId);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('$name will be removed from this travel group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _groupRef.update({
      'memberIds': FieldValue.arrayRemove([memberId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _groupRef.collection('locations').doc(memberId).delete();
    await AppServices.notify(
      userId: memberId,
      title: 'Removed from travel group',
      message: 'You were removed from ${group['name'] ?? 'the group'}.',
      type: 'companion_group',
      referenceId: widget.groupId,
    );
    if (mounted) showMessage(context, '$name was removed.');
  }

  Future<void> shareLocation(Map<String, dynamic> group) async {
    try {
      final position = await determinePosition();
      final uid = AppServices.auth.currentUser!.uid;
      final approvedRequests = await AppServices.db
          .collection('location_requests')
          .where('targetId', isEqualTo: uid)
          .get();
      final approvedViewerIds = <String>{uid};

      for (final request in approvedRequests.docs) {
        if (request.data()['groupId'] == widget.groupId &&
            request.data()['status'] == 'approved') {
          approvedViewerIds.add('${request.data()['requesterId']}');
        }
      }

      final leaderId = '${group['leaderId'] ?? ''}';
      if (leaderId.isNotEmpty && leaderId == uid) {
        approvedViewerIds.add(uid);
      }

      await _groupRef.collection('locations').doc(uid).set({
        'userId': uid,
        'location': GeoPoint(position.latitude, position.longitude),
        'approvedViewerIds': approvedViewerIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showMessage(context, 'Your latest location was shared.');
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

  Future<void> sendSos(Map<String, dynamic> group) async {
    final uid = AppServices.auth.currentUser!.uid;
    final leaderId = '${group['leaderId'] ?? ''}';

    if (leaderId.isEmpty) {
      showMessage(context, 'This group has no leader.', error: true);
      return;
    }
    if (uid == leaderId) {
      showMessage(
        context,
        'The SOS button is for group members. Member alerts are delivered to you as the leader.',
      );
      return;
    }

    setState(() => sendingSos = true);
    try {
      final position = await determinePosition();
      final senderName = await _displayName(uid);
      final groupName = '${group['name'] ?? 'Travel Group'}';

      final existingSnapshot = await AppServices.db
          .collection('sos_alerts')
          .where('groupId', isEqualTo: widget.groupId)
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
          'groupId': widget.groupId,
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

      // Make the SOS sender visible only to the sender and group leader.
      await _groupRef.collection('locations').doc(uid).set({
        'userId': uid,
        'location': GeoPoint(position.latitude, position.longitude),
        'approvedViewerIds': [uid, leaderId],
        'sosActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // The notification is intentionally written only for the leader.
      await AppServices.notify(
        userId: leaderId,
        title: 'SOS alert from $senderName',
        message: '$senderName needs help in $groupName. Open the group map to view the latest location.',
        type: 'sos',
        referenceId: alertReference.id,
      );

      if (mounted) {
        showMessage(context, 'SOS alert sent only to the group leader.');
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
      if (mounted) setState(() => sendingSos = false);
    }
  }

  Future<void> resolveSos(
    DocumentReference<Map<String, dynamic>> reference,
    String senderId,
  ) async {
    await reference.update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': AppServices.auth.currentUser?.uid,
    });
    await _groupRef.collection('locations').doc(senderId).set({
      'sosActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) showMessage(context, 'SOS alert marked as resolved.');
  }

  Future<void> requestLocation(String targetId) async {
    final uid = AppServices.auth.currentUser!.uid;
    final requestSnapshot = await AppServices.db
        .collection('location_requests')
        .where('groupId', isEqualTo: widget.groupId)
        .get();
    final existing = requestSnapshot.docs.where((document) {
      final data = document.data();
      return data['requesterId'] == uid &&
          data['targetId'] == targetId &&
          data['status'] == 'pending';
    });
    if (existing.isNotEmpty) {
      if (mounted) showMessage(context, 'A request is already pending.');
      return;
    }

    await AppServices.db.collection('location_requests').add({
      'groupId': widget.groupId,
      'requesterId': uid,
      'targetId': targetId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await AppServices.notify(
      userId: targetId,
      title: 'Location sharing request',
      message: 'A companion requested your location in ${widget.group['name'] ?? 'the group'}.',
      type: 'location_request',
      referenceId: widget.groupId,
    );
    if (mounted) showMessage(context, 'Location request sent.');
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

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
        final memberIds = List<String>.from(
          group['memberIds'] ?? const <String>[],
        );
        final isLeader = '${group['leaderId'] ?? ''}' == uid;

        return Scaffold(
          backgroundColor: ExplorerColors.background,
          appBar: AppBar(
            title: Text('${group['name'] ?? 'Group Details'}'),
            actions: [
              if (isLeader)
                IconButton(
                  tooltip: 'Add member',
                  onPressed: addingMember ? null : () => addMember(group),
                  icon: addingMember
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1_outlined),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              ExplorerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GROUP CODE',
                                style: TextStyle(
                                  color: ExplorerColors.muted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${group['code'] ?? '-'}',
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy group code',
                          onPressed: () => _copyGroupCode(group),
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                    if ('${group['description'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        '${group['description']}',
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => shareLocation(group),
                          icon: const Icon(Icons.my_location_outlined),
                          label: const Text('Share Location'),
                        ),
                        if (isLeader)
                          FilledButton.icon(
                            onPressed: addingMember
                                ? null
                                : () => addMember(group),
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Add Member'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: sendingSos
                                ? null
                                : () => sendSos(group),
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
                                : const Icon(Icons.sos_rounded),
                            label: Text(
                              sendingSos ? 'Sending...' : 'Send SOS',
                            ),
                          ),
                      ],
                    ),
                    if (!isLeader) ...[
                      const SizedBox(height: 9),
                      const Text(
                        'SOS sends your latest location and timestamp only to the group leader.',
                        style: TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (isLeader) ...[
                const ExplorerSectionTitle(
                  'Active SOS Alerts',
                  subtitle: 'Only alerts sent to you as the group leader are shown.',
                ),
                const SizedBox(height: 9),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AppServices.db
                      .collection('sos_alerts')
                      .where('groupId', isEqualTo: widget.groupId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final alerts = (snapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data();
                      return data['status'] == 'active' &&
                          data['leaderId'] == uid;
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

                    if (alerts.isEmpty) {
                      return const ExplorerCard(
                        child: Text(
                          'No active SOS alerts.',
                          style: TextStyle(color: ExplorerColors.muted),
                        ),
                      );
                    }

                    return Column(
                      children: alerts.map((alert) {
                        final data = alert.data();
                        final time = asDate(data['lastTriggeredAt']) ??
                            asDate(data['createdAt']);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: ExplorerCard(
                            backgroundColor: const Color(0xFFFFE6E1),
                            borderColor: const Color(0xFFF6B8AE),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: ExplorerColors.danger,
                                  foregroundColor: Colors.white,
                                  child: Icon(Icons.crisis_alert_rounded),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${data['senderName'] ?? data['senderId'] ?? 'Group member'} needs help',
                                        style: const TextStyle(
                                          color: ExplorerColors.danger,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        time == null
                                            ? 'Location received'
                                            : 'Latest alert: ${DateFormat.yMMMd().add_jm().format(time)}',
                                        style: const TextStyle(
                                          color: ExplorerColors.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => resolveSos(
                                    alert.reference,
                                    '${data['senderId'] ?? ''}',
                                  ),
                                  child: const Text('Resolve'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              const ExplorerSectionTitle(
                'Group Map',
                subtitle: 'Only approved companion locations are visible.',
              ),
              const SizedBox(height: 9),
              SizedBox(
                height: 300,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _groupRef
                      .collection('locations')
                      .where('approvedViewerIds', arrayContains: uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    final positions = <String, LatLng>{};
                    final sosMembers = <String>{};
                    for (final doc in docs) {
                      final data = doc.data();
                      final geo = data['location'];
                      if (geo is GeoPoint) {
                        positions[doc.id] =
                            LatLng(geo.latitude, geo.longitude);
                        if (data['sosActive'] == true) {
                          sosMembers.add(doc.id);
                        }
                      }
                    }

                    final markers = positions.entries.map((entry) {
                      return Marker(
                        markerId: MarkerId(entry.key),
                        position: entry.value,
                        infoWindow: InfoWindow(
                          title: entry.key == uid
                              ? 'You'
                              : sosMembers.contains(entry.key)
                                  ? 'SOS companion'
                                  : 'Approved companion',
                        ),
                      );
                    }).toSet();
                    final ownPosition = positions[uid];
                    final polylines = ownPosition == null
                        ? <Polyline>{}
                        : positions.entries
                            .where((entry) => entry.key != uid)
                            .map(
                              (entry) => Polyline(
                                polylineId:
                                    PolylineId('${uid}_${entry.key}'),
                                points: [ownPosition, entry.value],
                                width: 4,
                              ),
                            )
                            .toSet();
                    final initial = ownPosition ??
                        (markers.isNotEmpty
                            ? markers.first.position
                            : const LatLng(5.4141, 100.3288));

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: GoogleMap(
                        initialCameraPosition:
                            CameraPosition(target: initial, zoom: 14),
                        markers: markers,
                        polylines: polylines,
                        myLocationButtonEnabled: true,
                        myLocationEnabled: true,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: ExplorerSectionTitle(
                      'Members',
                      subtitle: 'Manage companions and location access.',
                    ),
                  ),
                  if (isLeader)
                    IconButton(
                      tooltip: 'Add member',
                      onPressed: addingMember ? null : () => addMember(group),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...memberIds.map(
                (memberId) => FutureBuilder<
                    DocumentSnapshot<Map<String, dynamic>>>(
                  key: ValueKey('travel-group-member-$memberId'),
                  future: AppServices.userRef(memberId).get(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data?.data();
                    final name =
                        '${profile?['displayName'] ?? profile?['fullName'] ?? memberId}';
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
                          name,
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          isGroupLeader
                              ? 'Group leader'
                              : isCurrentUser
                                  ? 'You • Companion'
                                  : 'Companion',
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
                                      leading: Icon(Icons.location_searching),
                                      title: Text('Request location'),
                                    ),
                                  ),
                                  if (isLeader && !isGroupLeader)
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.person_remove_outlined,
                                          color: ExplorerColors.danger,
                                        ),
                                        title: Text('Remove member'),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              const ExplorerSectionTitle(
                'Incoming Location Requests',
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('location_requests')
                    .where('targetId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final requests = (snapshot.data?.docs ?? []).where(
                    (document) =>
                        document.data()['groupId'] == widget.groupId &&
                        document.data()['status'] == 'pending',
                  ).toList();

                  if (requests.isEmpty) {
                    return const ExplorerCard(
                      child: Text(
                        'No pending requests.',
                        style: TextStyle(color: ExplorerColors.muted),
                      ),
                    );
                  }

                  return Column(
                    children: requests.map((request) {
                      final requesterId =
                          '${request.data()['requesterId'] ?? ''}';
                      return FutureBuilder<String>(
                        future: _displayName(requesterId),
                        builder: (context, profileSnapshot) {
                          return ExplorerCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${profileSnapshot.data ?? requesterId} requested your location',
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Reject',
                                    onPressed: () => request.reference.update({
                                      'status': 'rejected',
                                      'respondedAt':
                                          FieldValue.serverTimestamp(),
                                    }),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Approve',
                                    onPressed: () async {
                                      await request.reference.update({
                                        'status': 'approved',
                                        'respondedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                      await shareLocation(group);
                                    },
                                    icon: const Icon(Icons.check_rounded),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
