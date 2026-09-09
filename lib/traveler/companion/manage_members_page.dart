part of '../traveler_pages.dart';

class ManageMembersPage extends StatefulWidget {
  const ManageMembersPage({
    super.key,
    required this.groupId,
    required this.group,
  });

  final String groupId;
  final Map<String, dynamic> group;

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  final Set<String> _requestingLocationIds = <String>{};
  final Set<String> _removingMemberIds = <String>{};

  Future<String> _displayName(String uid) async {
    try {
      final snapshot = await AppServices.travelerRef(uid).get();
      final name = '${snapshot.data()?['displayName'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return 'Traveler';
  }

  String _memberName(Map<String, dynamic> group, String uid) {
    final names = Map<String, dynamic>.from(
      group['memberNames'] ?? const <String, dynamic>{},
    );
    return '${names[uid] ?? ''}'.trim();
  }

  Future<void> _removeMember(
      Map<String, dynamic> group,
      String memberId,
      String name,
      ) async {
    final currentUser = AppServices.auth.currentUser;
    if (currentUser == null) return;

    if ('${group['leaderId'] ?? ''}' != currentUser.uid) {
      showMessage(
        context,
        'Only the group leader can remove members.',
        error: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.person_remove_outlined,
          color: ExplorerColors.danger,
          size: 38,
        ),
        title: const Text('Remove Member?'),
        content: Text(
          '$name will be removed from ${group['name'] ?? 'this travel group'}. '
              'Their group-location record will also be removed.',
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
            child: const Text('Remove Member'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removingMemberIds.add(memberId));

    try {
      final groupRef = AppServices.db
          .collection('travel_groups')
          .doc(widget.groupId);

      final batch = AppServices.db.batch();

      batch.update(groupRef, {
        'memberIds': FieldValue.arrayRemove([memberId]),
        'memberNames.$memberId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.delete(
        groupRef.collection('locations').doc(memberId),
      );

      await batch.commit();

      try {
        await AppServices.notify(
          userId: memberId,
          title: 'Removed from travel group',
          message:
          'You were removed from ${group['name'] ?? 'the travel group'}.',
          type: 'companion_group',
          referenceId: widget.groupId,
          groupId: widget.groupId,
        );
      } catch (error) {
        debugPrint('Unable to send member-removal notification: $error');
      }

      if (mounted) {
        showMessage(context, '$name was removed.');
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Failed to remove member: '
              '${error.toString().replaceFirst('Exception: ', '')}',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingMemberIds.remove(memberId));
      }
    }
  }

  Future<void> _requestLocation(
      Map<String, dynamic> group,
      String targetId,
      String targetName,
      ) async {
    final user = AppServices.auth.currentUser;

    if (user == null) {
      showMessage(context, 'Please sign in first.', error: true);
      return;
    }

    final leaderId = '${group['leaderId'] ?? ''}';

    if (leaderId != user.uid) {
      showMessage(
        context,
        'Only the group leader can request a member location from this screen. '
            'Other members can use Private Chat for one-time location requests.',
        error: true,
      );
      return;
    }

    if (_requestingLocationIds.contains(targetId)) return;

    setState(() => _requestingLocationIds.add(targetId));

    try {
      final groupName = '${group['name'] ?? 'Travel Group'}'.trim();

      var requesterName = _memberName(group, user.uid);
      if (requesterName.isEmpty) {
        requesterName = await _displayName(user.uid);
      }

      final existingSnapshot = await AppServices.db
          .collection('location_requests')
          .where('groupId', isEqualTo: widget.groupId)
          .get();

      final hasPending = existingSnapshot.docs.any((document) {
        final data = document.data();
        final requestType =
        '${data['requestType'] ?? 'group'}'.toLowerCase();

        return requestType == 'group' &&
            '${data['requesterId'] ?? ''}' == user.uid &&
            '${data['targetId'] ?? data['targetUserId'] ?? ''}' ==
                targetId &&
            '${data['status'] ?? ''}'.toLowerCase() == 'pending';
      });

      if (hasPending) {
        throw Exception(
          'A group-location request is already pending for $targetName.',
        );
      }

      final requestRef =
      AppServices.db.collection('location_requests').doc();

      await requestRef.set({
        'requestType': 'group',
        'requesterId': user.uid,
        'requesterName': requesterName,
        'targetId': targetId,
        'targetName': targetName,
        'groupId': widget.groupId,
        'groupName': groupName,
        'leaderId': leaderId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
        'location': null,
      });

      try {
        await AppServices.notify(
          userId: targetId,
          title: 'Location request from $requesterName',
          message:
          '$requesterName is requesting your location for $groupName. '
              'Open Companion to review the request.',
          type: 'group_location_request',
          referenceId: requestRef.id,
          groupId: widget.groupId,
        );
      } catch (error) {
        debugPrint('Unable to send group-location notification: $error');
      }

      if (mounted) {
        showMessage(
          context,
          'Location request sent to $targetName.',
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
        setState(() => _requestingLocationIds.remove(targetId));
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

    final groupRef = AppServices.db
        .collection('travel_groups')
        .doc(widget.groupId);

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Manage Members'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: groupRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load group members.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const ExplorerEmptyState(
              title: 'Travel Group Not Found',
              subtitle:
              'This travel group may have already been ended or removed.',
              icon: Icons.group_off_outlined,
            );
          }

          final groupData =
              snapshot.data!.data() ?? const <String, dynamic>{};

          final memberIds = List<String>.from(
            groupData['memberIds'] ?? const <String>[],
          );

          final leaderId = '${groupData['leaderId'] ?? ''}';
          final isLeader = leaderId == uid;

          return Column(
            children: [
              if (isLeader)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: ExplorerColors.navySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ExplorerColors.border),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: ExplorerColors.navy,
                        size: 19,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Group location access is consent-based. '
                              'Requesting a location creates an audit record and the member must approve before their GPS can be viewed.',
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: memberIds.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final memberId = memberIds[index];
                    final cachedName = _memberName(groupData, memberId);

                    return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      future: cachedName.isEmpty
                          ? AppServices.travelerRef(memberId).get()
                          : null,
                      builder: (context, userSnapshot) {
                        final profile =
                            userSnapshot.data?.data() ??
                                const <String, dynamic>{};

                        final loadedName =
                        '${profile['displayName'] ?? ''}'.trim();

                        final name = cachedName.isNotEmpty
                            ? cachedName
                            : loadedName.isNotEmpty
                            ? loadedName
                            : 'Group Member';

                        final initial =
                        name.isEmpty ? '?' : name[0].toUpperCase();

                        final isMe = memberId == uid;
                        final isMemberLeader = memberId == leaderId;

                        final requesting =
                        _requestingLocationIds.contains(memberId);
                        final removing =
                        _removingMemberIds.contains(memberId);

                        return ExplorerCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isMemberLeader
                                  ? ExplorerColors.goldSoft
                                  : ExplorerColors.navySoft,
                              foregroundColor: ExplorerColors.navy,
                              child: isMemberLeader
                                  ? const Icon(
                                Icons.workspace_premium_outlined,
                              )
                                  : Text(
                                initial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            title: Text(
                              isMe ? '$name (You)' : name,
                              style: const TextStyle(
                                color: ExplorerColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              isMemberLeader
                                  ? 'Group Leader'
                                  : 'Companion',
                            ),
                            trailing: !isLeader ||
                                isMe ||
                                isMemberLeader
                                ? null
                                : PopupMenuButton<String>(
                              enabled: !requesting && !removing,
                              onSelected: (value) {
                                if (value == 'request') {
                                  _requestLocation(
                                    groupData,
                                    memberId,
                                    name,
                                  );
                                } else if (value == 'remove') {
                                  _removeMember(
                                    groupData,
                                    memberId,
                                    name,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'request',
                                  child: Row(
                                    children: [
                                      if (requesting)
                                        const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child:
                                          CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.location_searching,
                                          size: 18,
                                        ),
                                      const SizedBox(width: 8),
                                      const Text('Request Location'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_remove_outlined,
                                        size: 18,
                                        color:
                                        ExplorerColors.danger,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Remove Member',
                                        style: TextStyle(
                                          color:
                                          ExplorerColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
