part of '../traveler_pages.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();

  CollectionReference<Map<String, dynamic>> get _messagesRef => AppServices.db
      .collection('travel_groups')
      .doc(widget.groupId)
      .collection('messages');

  Future<void> _send() async {
    final text = _input.text.trim();

    if (text.isEmpty) {
      return;
    }

    final user = AppServices.auth.currentUser;

    if (user == null) {
      if (mounted) {
        showMessage(context, 'Please sign in first.', error: true);
      }

      return;
    }

    final senderId = user.uid;

    try {
      // ============================================================
      // 1. LOAD SENDER NAME
      // ============================================================

      String senderName = user.displayName?.trim() ?? '';

      try {
        final travelerSnapshot = await AppServices.travelerRef(senderId).get();

        final travelerData =
            travelerSnapshot.data() ?? const <String, dynamic>{};

        final firestoreName = '${travelerData['displayName'] ?? ''}'.trim();

        if (firestoreName.isNotEmpty) {
          senderName = firestoreName;
        }
      } catch (error) {
        debugPrint('Unable to load sender profile: $error');
      }

      if (senderName.isEmpty) {
        senderName = user.email?.split('@').first ?? 'Member';
      }

      // ============================================================
      // 2. VERIFY GROUP EXISTS + USER IS MEMBER
      // ============================================================

      final groupReference = AppServices.db
          .collection('travel_groups')
          .doc(widget.groupId);

      final groupSnapshot = await groupReference.get();

      if (!groupSnapshot.exists) {
        throw Exception('This travel group no longer exists.');
      }

      final group = groupSnapshot.data() ?? const <String, dynamic>{};

      final memberIds = List<String>.from(
        group['memberIds'] ?? const <String>[],
      );

      if (!memberIds.contains(senderId)) {
        throw Exception('You are no longer a member of this travel group.');
      }

      final groupName = '${group['name'] ?? widget.groupName}'.trim();

      // ============================================================
      // 3. SAVE MESSAGE
      // ============================================================

      final messageRef = await _messagesRef.add({
        'text': text,

        'senderId': senderId,

        'senderName': senderName,

        'timestamp': FieldValue.serverTimestamp(),

        'createdAt': FieldValue.serverTimestamp(),
      });

      // Only clear AFTER message save succeeds.
      _input.clear();

      debugPrint('GROUP CHAT MESSAGE SAVED: ${messageRef.id}');

      // ============================================================
      // 4. SEND NOTIFICATIONS
      //
      // Notification failure must NOT make chat sending look failed.
      // ============================================================

      try {
        final notificationBatch = AppServices.db.batch();

        var notificationCount = 0;

        for (final memberId in memberIds) {
          if (memberId.isEmpty || memberId == senderId) {
            continue;
          }

          final notificationRef = AppServices.db
              .collection('notifications')
              .doc();

          notificationBatch.set(notificationRef, {
            'userId': memberId,

            'title': 'New message in $groupName',

            'message': '$senderName: $text',

            'type': 'group_message',

            'referenceId': widget.groupId,

            'groupId': widget.groupId,

            'groupName': groupName,

            'messageId': messageRef.id,

            'senderId': senderId,

            'senderName': senderName,

            'read': false,

            'pushStatus': 'pending',

            'pushAttempts': 0,

            'createdAt': FieldValue.serverTimestamp(),
          });

          notificationCount++;
        }

        if (notificationCount > 0) {
          await notificationBatch.commit();
        }

        debugPrint(
          'GROUP CHAT NOTIFICATIONS CREATED: '
          '$notificationCount',
        );
      } catch (notificationError) {
        // Message already exists.
        // Do not claim message sending failed.
        debugPrint(
          'GROUP CHAT NOTIFICATION ERROR: '
          '$notificationError',
        );
      }

      if (!mounted) {
        return;
      }

      _scrollToBottom();
    } on FirebaseException catch (error) {
      debugPrint(
        'GROUP CHAT FIREBASE ERROR: '
        '${error.code} - ${error.message}',
      );

      if (!mounted) {
        return;
      }

      showMessage(
        context,
        'Unable to send message: '
        '${error.message ?? error.code}',
        error: true,
      );
    } catch (error) {
      debugPrint('GROUP CHAT ERROR: $error');

      if (!mounted) {
        return;
      }

      showMessage(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName),
            const Text(
              'Group Chat',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AppServices.db
                .collection('travel_groups')
                .doc(widget.groupId)
                .snapshots(),
            builder: (context, snapshot) {
              final group = snapshot.data?.data();
              final isLeader = group?['leaderId'] == uid;
              if (isLeader) return const SizedBox.shrink();

              return IconButton(
                tooltip: 'Emergency SOS',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SosPanicPage(
                      groupId: widget.groupId,
                      group: group ?? {},
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.sos_rounded,
                  color: ExplorerColors.danger,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Role-based Location Request Banner (For Members)
          _LocationRequestBanner(groupId: widget.groupId),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Do NOT order in Firestore.
              // Listen to the whole messages collection directly.
              stream: _messagesRef.snapshots(includeMetadataChanges: true),

              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('GROUP CHAT STREAM ERROR: ${snapshot.error}');

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: ExplorerColors.danger,
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load group messages',
                            style: TextStyle(
                              color: ExplorerColors.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = [...snapshot.data!.docs];

                // ============================================================
                // SORT LOCALLY
                // ============================================================

                docs.sort((a, b) {
                  final aTime = asDate(a.data()['timestamp']);

                  final bTime = asDate(b.data()['timestamp']);

                  if (aTime == null && bTime == null) {
                    return 0;
                  }

                  if (aTime == null) {
                    return 1;
                  }

                  if (bTime == null) {
                    return -1;
                  }

                  return aTime.compareTo(bTime);
                });

                debugPrint('================================');

                debugPrint('GROUP CHAT UPDATE');

                debugPrint('GROUP: ${widget.groupId}');

                debugPrint('CURRENT UID: $uid');

                debugPrint('MESSAGES: ${docs.length}');

                debugPrint(
                  'FROM CACHE: '
                  '${snapshot.data!.metadata.isFromCache}',
                );

                for (final document in docs) {
                  debugPrint(
                    '${document.id} => '
                    '${document.data()['text']}',
                  );
                }

                debugPrint('================================');

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet.\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ExplorerColors.muted),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();

                    final isMe = data['senderId'] == uid;

                    return _buildMessageBubble(data, isMe);
                  },
                );
              },
            ),
          ),

          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    final time = asDate(data['timestamp']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                '${data['senderName']}',
                style: const TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: isMe ? ExplorerColors.navy : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMe ? 14 : 3),
                bottomRight: Radius.circular(isMe ? 3 : 14),
              ),
              border: isMe ? null : Border.all(color: ExplorerColors.border),
            ),
            child: Text(
              '${data['text']}',
              style: TextStyle(
                color: isMe ? Colors.white : ExplorerColors.text,
                fontSize: 13,
              ),
            ),
          ),
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                DateFormat.jm().format(time),
                style: const TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ExplorerColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRequestBanner extends StatelessWidget {
  const _LocationRequestBanner({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('location_requests')
          .where('targetId', isEqualTo: uid)
          .where('groupId', isEqualTo: groupId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox.shrink();

        final doc = snapshot.data!.docs.first;
        final data = doc.data();

        return Container(
          width: double.infinity,
          color: ExplorerColors.goldSoft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.location_searching,
                color: ExplorerColors.goldDark,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Group Leader requested your location.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ExplorerColors.goldDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => doc.reference.update({'status': 'rejected'}),
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
              FilledButton(
                onPressed: () => _approve(doc.reference, uid, context),
                style: FilledButton.styleFrom(
                  backgroundColor: ExplorerColors.navy,
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Approve', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _approve(
    DocumentReference ref,
    String uid,
    BuildContext context,
  ) async {
    try {
      final pos = await determinePosition();
      await AppServices.db.runTransaction((tx) async {
        tx.update(ref, {
          'status': 'approved',
          'respondedAt': FieldValue.serverTimestamp(),
        });

        final locRef = AppServices.db
            .collection('travel_groups')
            .doc(groupId)
            .collection('locations')
            .doc(uid);
        final locSnap = await tx.get(locRef);
        List<String> viewers = [uid];
        if (locSnap.exists)
          viewers = List<String>.from(
            locSnap.data()?['approvedViewerIds'] ?? [uid],
          );

        final reqData = await ref.get();
        final requesterId = (reqData.data() as Map)['requesterId'];
        if (!viewers.contains(requesterId)) viewers.add(requesterId);

        tx.set(locRef, {
          'location': GeoPoint(pos.latitude, pos.longitude),
          'updatedAt': FieldValue.serverTimestamp(),
          'approvedViewerIds': viewers,
        }, SetOptions(merge: true));
      });
      if (context.mounted) showMessage(context, 'Location shared with leader.');
    } catch (e) {
      if (context.mounted)
        showMessage(context, 'Approval failed: $e', error: true);
    }
  }
}
