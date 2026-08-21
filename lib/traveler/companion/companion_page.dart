part of '../traveler_pages.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key});

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  final Set<String> _sendingSosGroupIds = <String>{};

  Future<String> _createUniqueGroupCode() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = randomCode().toUpperCase();
      final existing = await AppServices.db
          .collection('travel_groups')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) return code;
    }

    throw Exception('Unable to generate a unique group code. Please try again.');
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
            label: const Text('Create Group'),
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
        showMessage(context, 'Please enter a group name.', error: true);
      }
      return;
    }

    final user = AppServices.auth.currentUser;
    if (user == null) return;

    try {
      final code = await _createUniqueGroupCode();

      await AppServices.db.collection('travel_groups').add({
        'name': groupName,
        'description': description,
        'code': code,
        'leaderId': user.uid,
        'memberIds': [user.uid],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

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
              decoration: const InputDecoration(
                labelText: 'Group Code',
                hintText: 'ABC123',
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
            label: const Text('Join Group'),
          ),
        ],
      ),
    );

    final code = codeController.text.trim().toUpperCase();
    codeController.dispose();

    if (confirmed != true) return;

    if (code.isEmpty) {
      if (context.mounted) {
        showMessage(context, 'Please enter a group code.', error: true);
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
      final memberIds = List<String>.from(
        group['memberIds'] ?? const <String>[],
      );

      if (memberIds.contains(user.uid)) {
        throw Exception('You are already a member of this travel group.');
      }

      await groupDocument.reference.update({
        'memberIds': FieldValue.arrayUnion([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        showMessage(
          context,
          'Joined ${group['name'] ?? 'travel group'} successfully.',
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
    }
  }

  Future<String> _displayName(String uid) async {
    try {
      final profile = await AppServices.travelerRef(uid).get();
      final data = profile.data() ?? const <String, dynamic>{};
      return '${data['displayName'] ?? data['fullName'] ?? data['name'] ?? uid}';
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
      showMessage(context, 'This group has no group leader.', error: true);
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
          'Your latest GPS location and timestamp will be sent only to your group leader.',
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

    setState(() => _sendingSosGroupIds.add(groupId));

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
          .set({
        'userId': uid,
        'location': GeoPoint(position.latitude, position.longitude),
        'approvedViewerIds': [uid, leaderId],
        'sosActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
        setState(() => _sendingSosGroupIds.remove(groupId));
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
        body: Center(child: Text('Please sign in first.')),
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
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your travel groups.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final first = asDate(a.data()['updatedAt']) ??
                  asDate(a.data()['createdAt']) ??
                  DateTime(2000);
              final second = asDate(b.data()['updatedAt']) ??
                  asDate(b.data()['createdAt']) ??
                  DateTime(2000);
              return second.compareTo(first);
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              const ExplorerPageHeader(
                title: 'Companion',
                subtitle: 'Stay connected and travel safely with your group.',
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
              const SizedBox(height: 22),
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
    final status = '${group['status'] ?? 'active'}';
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
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ExplorerStatusBadge(
                label: 'CODE $code',
                tone: ExplorerStatusTone.neutral,
                icon: Icons.key_outlined,
              ),
              ExplorerStatusBadge(
                label:
                '${memberIds.length} MEMBER${memberIds.length == 1 ? '' : 'S'}',
                tone: ExplorerStatusTone.neutral,
                icon: Icons.people_outline,
              ),
              ExplorerStatusBadge(
                label: status.toUpperCase(),
                tone: status == 'active'
                    ? ExplorerStatusTone.success
                    : ExplorerStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 15),
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
                const SizedBox(width: 9),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openLeaderPage(
                      context,
                      groupId,
                      group,
                      initialTab: 1,
                    ),
                    icon: const Icon(Icons.manage_accounts_outlined),
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
                    label: const Text('Map'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _LeaderSosButton(
                    groupId: groupId,
                    onPressed: () => _openLeaderPage(
                      context,
                      groupId,
                      group,
                      initialTab: 2,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
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
                const SizedBox(width: 9),
                Expanded(
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
                      foregroundColor: Colors.white,
                    ),
                    icon: sendingSos
                        ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.sos_rounded),
                    label: Text(sendingSos ? 'Sending...' : 'SOS'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: ExplorerColors.muted,
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'SOS shares your latest GPS location only with the group leader.',
                    style: TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LeaderSosButton extends StatelessWidget {
  const _LeaderSosButton({
    required this.groupId,
    required this.onPressed,
  });

  final String groupId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;

    if (uid == null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.notification_important_outlined),
        label: const Text('SOS Alerts'),
      );
    }

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
          onPressed: onPressed,
          style: activeCount > 0
              ? OutlinedButton.styleFrom(
            foregroundColor: ExplorerColors.danger,
            side: const BorderSide(color: ExplorerColors.danger),
          )
              : null,
          icon: Icon(
            activeCount > 0
                ? Icons.notification_important
                : Icons.notifications_none,
          ),
          label: Text(
            activeCount > 0 ? 'SOS ($activeCount)' : 'SOS Alerts',
          ),
        );
      },
    );
  }
}
