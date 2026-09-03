part of '../traveler_pages.dart';

class TravelerNotificationBell extends StatelessWidget {
  const TravelerNotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = (snapshot.data?.docs ?? const [])
            .where((doc) => doc.data()['read'] != true)
            .length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              ),
              icon: Icon(
                unreadCount > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: const BoxDecoration(
                    color: ExplorerColors.danger,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> _openPrivateChat(
      BuildContext context,
      String chatId,
      ) async {
    if (chatId.isEmpty) return;

    final uid = AppServices.auth.currentUser?.uid;
    if (uid == null) return;

    final chatSnapshot = await AppServices.db
        .collection('private_chats')
        .doc(chatId)
        .get();

    if (!chatSnapshot.exists) {
      if (context.mounted) {
        showMessage(
          context,
          'This private conversation is no longer available.',
          error: true,
        );
      }
      return;
    }

    final chat = chatSnapshot.data() ?? const <String, dynamic>{};

    final participantIds = List<String>.from(
      chat['participantIds'] ?? const <String>[],
    );

    final otherUserId = participantIds.firstWhere(
          (id) => id != uid,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) {
      if (context.mounted) {
        showMessage(
          context,
          'Unable to identify the other traveler.',
          error: true,
        );
      }
      return;
    }

    final participantNames = Map<String, dynamic>.from(
      chat['participantNames'] ?? const <String, dynamic>{},
    );

    var otherName = '${participantNames[otherUserId] ?? ''}'.trim();

    if (otherName.isEmpty) {
      otherName = await companionTravelerDisplayName(otherUserId);
    }

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatPage(
          chatId: chatId,
          otherUserId: otherUserId,
          otherUserName: otherName,
        ),
      ),
    );
  }

  Future<void> _openGroupChat(
      BuildContext context,
      String groupId,
      ) async {
    if (groupId.isEmpty) return;

    final uid = AppServices.auth.currentUser?.uid;
    if (uid == null) return;

    final groupSnapshot = await AppServices.db
        .collection('travel_groups')
        .doc(groupId)
        .get();

    if (!groupSnapshot.exists) {
      if (context.mounted) {
        showMessage(
          context,
          'This travel group is no longer available.',
          error: true,
        );
      }
      return;
    }

    final group = groupSnapshot.data() ?? const <String, dynamic>{};

    final memberIds = List<String>.from(
      group['memberIds'] ?? const <String>[],
    );

    if (!memberIds.contains(uid)) {
      if (context.mounted) {
        showMessage(
          context,
          'You are no longer a member of this travel group.',
          error: true,
        );
      }
      return;
    }

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatPage(
          groupId: groupId,
          groupName: '${group['name'] ?? 'Travel Group'}',
        ),
      ),
    );
  }

  Future<void> _openSos(
      BuildContext context,
      String alertId,
      ) async {
    if (alertId.isEmpty) return;

    final alertSnapshot = await AppServices.db
        .collection('sos_alerts')
        .doc(alertId)
        .get();

    final alert = alertSnapshot.data();

    if (alert == null) {
      if (context.mounted) {
        showMessage(
          context,
          'This SOS alert is no longer available.',
          error: true,
        );
      }
      return;
    }

    final groupId = '${alert['groupId'] ?? ''}';

    if (groupId.isEmpty) return;

    final groupSnapshot = await AppServices.db
        .collection('travel_groups')
        .doc(groupId)
        .get();

    final group = groupSnapshot.data();

    if (group == null || !context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailsPage(
          groupId: groupId,
          group: group,
          initialTab: 2,
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final data = document.data();

    if (data['read'] != true) {
      await document.reference.update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    if (!context.mounted) return;

    final type = '${data['type'] ?? 'general'}';
    final referenceId = '${data['referenceId'] ?? ''}';

    switch (type) {
      case 'group_message':
        await _openGroupChat(
          context,
          '${data['groupId'] ?? referenceId}',
        );
        return;

      case 'private_message':
      case 'private_chat':
      case 'private_location_shared':
        await _openPrivateChat(
          context,
          '${data['chatId'] ?? referenceId}',
        );
        return;

      case 'private_location_request':
        var chatId = '${data['chatId'] ?? ''}';

        if (chatId.isEmpty && referenceId.isNotEmpty) {
          final requestSnapshot = await AppServices.db
              .collection('location_requests')
              .doc(referenceId)
              .get();

          chatId = '${requestSnapshot.data()?['chatId'] ?? ''}';
        }

        if (context.mounted && chatId.isNotEmpty) {
          await _openPrivateChat(
            context,
            chatId,
          );
        }
        return;

      case 'sos':
        await _openSos(
          context,
          referenceId,
        );
        return;

      case 'companion_group':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CompanionPage(),
          ),
        );
        return;

      default:
      // Generic notifications are simply marked as read.
        return;
    }
  }

  IconData _notificationIcon(String type) {
    return switch (type) {
      'group_message' => Icons.forum_outlined,
      'private_message' || 'private_chat' =>
      Icons.chat_bubble_outline,
      'private_location_request' ||
      'private_location_shared' =>
      Icons.location_on_outlined,
      'sos' => Icons.sos_rounded,
      'companion_group' => Icons.groups_outlined,
      _ => Icons.notifications_none,
    };
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
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Notifications',
              subtitle:
              'Messages, safety alerts, location requests and account updates.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('notifications')
                    .where('userId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load notifications.\n${snapshot.error}',
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

                  final docs = snapshot.data!.docs.toList()
                    ..sort(
                          (a, b) =>
                          (asDate(b.data()['createdAt']) ??
                              DateTime(2000))
                              .compareTo(
                            asDate(a.data()['createdAt']) ??
                                DateTime(2000),
                          ),
                    );

                  if (docs.isEmpty) {
                    return const ExplorerEmptyState(
                      title: 'No notifications yet',
                      subtitle:
                      'New private messages, group messages and important updates will appear here.',
                      icon: Icons.notifications_none_rounded,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      30,
                    ),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) =>
                    const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final document = docs[index];
                      final data = document.data();
                      final read = data['read'] == true;
                      final createdAt = asDate(data['createdAt']);
                      final type = '${data['type'] ?? 'general'}';

                      return ExplorerCard(
                        backgroundColor:
                        read ? Colors.white : ExplorerColors.navySoft,
                        borderColor: read
                            ? ExplorerColors.border
                            : const Color(0xFFB9CBE2),
                        onTap: () => _handleNotificationTap(
                          context,
                          document,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: read
                                  ? ExplorerColors.subtle
                                  : ExplorerColors.navy,
                              foregroundColor: read
                                  ? ExplorerColors.muted
                                  : Colors.white,
                              child: Icon(
                                _notificationIcon(type),
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${data['title'] ?? 'Update'}',
                                          style: const TextStyle(
                                            color: ExplorerColors.navy,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (!read)
                                        const ExplorerStatusBadge(
                                          label: 'NEW',
                                          tone: ExplorerStatusTone.navy,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${data['message'] ?? ''}',
                                    style: const TextStyle(
                                      color: ExplorerColors.text,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    createdAt == null
                                        ? 'Recently'
                                        : DateFormat.yMMMd()
                                        .add_jm()
                                        .format(createdAt),
                                    style: const TextStyle(
                                      color: ExplorerColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
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
      ),
    );
  }
}
