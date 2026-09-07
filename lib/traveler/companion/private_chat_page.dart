part of '../traveler_pages.dart';

String companionPrivateChatId(String uidA, String uidB) {
  final ids = <String>[uidA, uidB]..sort();
  return '${ids[0]}_${ids[1]}';
}

Future<String> companionTravelerDisplayName(String uid) async {
  try {
    final profile = await AppServices.travelerRef(uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    final name = '${data['displayName'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
  } catch (_) {
    // Fall through to a safe label.
  }

  return 'Traveler';
}

Future<void> openCompanionPrivateChat(
  BuildContext context, {
  required String otherUserId,
  String? otherUserName,
}) async {
  final currentUser = AppServices.auth.currentUser;

  if (currentUser == null) {
    if (context.mounted) {
      showMessage(context, 'Please sign in first.', error: true);
    }
    return;
  }

  if (currentUser.uid == otherUserId) {
    if (context.mounted) {
      showMessage(context, 'You cannot start a private chat with yourself.');
    }
    return;
  }

  try {
    final myProfile = await AppServices.travelerRef(currentUser.uid).get();
    final myName = '${myProfile.data()?['displayName'] ?? currentUser.displayName ?? 'Traveler'}'.trim();

    var resolvedOtherName = '${otherUserName ?? ''}'.trim();
    if (resolvedOtherName.isEmpty || resolvedOtherName == 'Group Member') {
      resolvedOtherName = await companionTravelerDisplayName(otherUserId);
    }

    final chatId = companionPrivateChatId(currentUser.uid, otherUserId);
    final chatRef = AppServices.db.collection('private_chats').doc(chatId);
    final existing = await chatRef.get();

    if (!existing.exists) {
      await chatRef.set({
        'participantIds': [currentUser.uid, otherUserId],
        'participantNames': {
          currentUser.uid: myName,
          otherUserId: resolvedOtherName,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } else {
      await chatRef.set({
        'participantIds': [currentUser.uid, otherUserId],
        'participantNames': {
          currentUser.uid: myName,
          otherUserId: resolvedOtherName,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatPage(
          chatId: chatId,
          otherUserId: otherUserId,
          otherUserName: resolvedOtherName,
        ),
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

Future<void> respondToPrivateLocationRequest(
  BuildContext context,
  DocumentSnapshot<Map<String, dynamic>> requestDocument, {
  required bool shareLocation,
}) async {
  final currentUser = AppServices.auth.currentUser;
  if (currentUser == null) return;

  final data = requestDocument.data() ?? const <String, dynamic>{};

  if ('${data['requestType'] ?? ''}' != 'private') return;
  if ('${data['targetId'] ?? ''}' != currentUser.uid) return;
  if ('${data['status'] ?? ''}' != 'pending') return;

  final requesterId = '${data['requesterId'] ?? ''}';
  final requesterName = '${data['requesterName'] ?? 'Traveler'}';
  final chatId = '${data['chatId'] ?? ''}';

  if (requesterId.isEmpty || chatId.isEmpty) {
    if (context.mounted) {
      showMessage(context, 'This location request is invalid.', error: true);
    }
    return;
  }

  try {
    final currentProfile = await AppServices.travelerRef(currentUser.uid).get();
    final currentName =
        '${currentProfile.data()?['displayName'] ?? currentUser.displayName ?? 'Traveler'}'.trim();

    final chatRef = AppServices.db.collection('private_chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final batch = AppServices.db.batch();

    if (shareLocation) {
      final position = await determinePosition();

      batch.update(requestDocument.reference, {
        'status': 'accepted',
        'location': GeoPoint(position.latitude, position.longitude),
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(messageRef, {
        'senderId': currentUser.uid,
        'senderName': currentName,
        'receiverId': requesterId,
        'type': 'location',
        'text': '$currentName shared their current location.',
        'location': GeoPoint(position.latitude, position.longitude),
        'locationRequestId': requestDocument.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        chatRef,
        {
          'lastMessage': '📍 $currentName shared a location',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      await AppServices.notify(
        userId: requesterId,
        title: '$currentName shared a location',
        message: 'Open your private chat to view the shared current location.',
        type: 'private_location_shared',
        referenceId: chatId,
      );

      if (context.mounted) {
        showMessage(context, 'Your current location was shared with $requesterName.');
      }
    } else {
      batch.update(requestDocument.reference, {
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(messageRef, {
        'senderId': currentUser.uid,
        'senderName': currentName,
        'receiverId': requesterId,
        'type': 'location_response',
        'text': '$currentName declined the location request.',
        'locationRequestId': requestDocument.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        chatRef,
        {
          'lastMessage': '$currentName declined the location request',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      await AppServices.notify(
        userId: requesterId,
        title: 'Location request declined',
        message: '$currentName declined your private location request.',
        type: 'private_location_request',
        referenceId: chatId,
      );

      if (context.mounted) {
        showMessage(context, 'Location request rejected.');
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

class PrivateChatPage extends StatefulWidget {
  const PrivateChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  final String chatId;
  final String otherUserId;
  final String otherUserName;

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;
  bool _requestingLocation = false;

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      AppServices.db.collection('private_chats').doc(widget.chatId);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _chatRef.collection('messages');

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String> _myDisplayName() async {
    final user = AppServices.auth.currentUser;
    if (user == null) return 'Traveler';

    final profile = await AppServices.travelerRef(user.uid).get();
    return '${profile.data()?['displayName'] ?? user.displayName ?? 'Traveler'}'.trim();
  }

  Future<void> _sendText() async {
    if (_sending) return;

    final text = _input.text.trim();
    if (text.isEmpty) return;

    final user = AppServices.auth.currentUser;
    if (user == null) return;

    setState(() => _sending = true);

    try {
      final myName = await _myDisplayName();
      final messageRef = _messagesRef.doc();
      final batch = AppServices.db.batch();

      batch.set(messageRef, {
        'senderId': user.uid,
        'senderName': myName,
        'receiverId': widget.otherUserId,
        'type': 'text',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        _chatRef,
        {
          'participantIds': [user.uid, widget.otherUserId],
          'participantNames': {
            user.uid: myName,
            widget.otherUserId: widget.otherUserName,
          },
          'lastMessage': text,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      _input.clear();

      await AppServices.notify(
        userId: widget.otherUserId,
        title: myName,
        message: text,
        type: 'private_chat',
        referenceId: widget.chatId,
        chatId: widget.chatId,
      );

      _scrollToBottom();
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
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _requestLocation() async {
    if (_requestingLocation) return;

    final user = AppServices.auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.location_searching,
          color: ExplorerColors.navy,
          size: 38,
        ),
        title: Text('Request ${widget.otherUserName}\'s Location?'),
        content: Text(
          '${widget.otherUserName} will be asked whether they want to share '
          'their current location with you. The location is shared one time only.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.location_searching),
            label: const Text('Request Location'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _requestingLocation = true);

    try {
      final existingSnapshot = await AppServices.db
          .collection('location_requests')
          .where('targetId', isEqualTo: widget.otherUserId)
          .get();

      final alreadyPending = existingSnapshot.docs.any((document) {
        final data = document.data();
        return data['requestType'] == 'private' &&
            data['chatId'] == widget.chatId &&
            data['requesterId'] == user.uid &&
            data['status'] == 'pending';
      });

      if (alreadyPending) {
        throw Exception('A location request is already waiting for ${widget.otherUserName}.');
      }

      final myName = await _myDisplayName();
      final requestRef = AppServices.db.collection('location_requests').doc();
      final messageRef = _messagesRef.doc();
      final batch = AppServices.db.batch();

      batch.set(requestRef, {
        'requestType': 'private',
        'chatId': widget.chatId,
        'requesterId': user.uid,
        'requesterName': myName,
        'targetId': widget.otherUserId,
        'targetName': widget.otherUserName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      batch.set(messageRef, {
        'senderId': user.uid,
        'senderName': myName,
        'receiverId': widget.otherUserId,
        'type': 'location_request',
        'text': '$myName requested ${widget.otherUserName}\'s current location.',
        'locationRequestId': requestRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        _chatRef,
        {
          'lastMessage': '📍 Location requested',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      await AppServices.notify(
        userId: widget.otherUserId,
        title: 'Location request from $myName',
        message: '$myName is asking you to share your current location.',
        type: 'private_location_request',
        referenceId: requestRef.id,
      );

      if (mounted) {
        showMessage(context, 'Location request sent to ${widget.otherUserName}.');
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
        setState(() => _requestingLocation = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'Private Chat',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Request current location',
            onPressed: _requestingLocation ? null : _requestLocation,
            icon: _requestingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.location_searching),
          ),
        ],
      ),
      body: Column(
        children: [
          _PrivateLocationRequestBanner(chatId: widget.chatId),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesRef.orderBy('createdAt').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load private messages.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const ExplorerEmptyState(
                    title: 'No Private Messages Yet',
                    subtitle:
                        'Send a message or request the other traveler\'s current location.',
                    icon: Icons.chat_bubble_outline,
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final isMe = data['senderId'] == uid;

                    return _buildMessage(
                      context,
                      data,
                      isMe,
                    );
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

  Widget _buildMessage(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMe,
  ) {
    final type = '${data['type'] ?? 'text'}';
    final time = asDate(data['createdAt']);

    if (type == 'location_request' || type == 'location_response') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 310),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: type == 'location_request'
                  ? ExplorerColors.goldSoft
                  : ExplorerColors.navySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type == 'location_request'
                      ? Icons.location_searching
                      : Icons.info_outline,
                  color: ExplorerColors.navy,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    '${data['text'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (type == 'location') {
      final location = data['location'];
      if (location is! GeoPoint) return const SizedBox.shrink();

      final senderName = '${data['senderName'] ?? 'Traveler'}';

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isMe ? ExplorerColors.navy : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: isMe ? null : Border.all(color: ExplorerColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: isMe ? Colors.white : ExplorerColors.danger,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '$senderName shared a location',
                        style: TextStyle(
                          color: isMe ? Colors.white : ExplorerColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${location.latitude.toStringAsFixed(5)}, '
                  '${location.longitude.toStringAsFixed(5)}',
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : ExplorerColors.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PrivateSharedLocationMapPage(
                          personName: senderName,
                          targetLat: location.latitude,
                          targetLng: location.longitude,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isMe ? Colors.white : ExplorerColors.navy,
                      side: BorderSide(
                        color: isMe ? Colors.white : ExplorerColors.navy,
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View on Map'),
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      DateFormat.jm().format(time),
                      style: TextStyle(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.65)
                            : ExplorerColors.muted,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                '${data['senderName'] ?? widget.otherUserName}',
                style: const TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.all(12),
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
              '${data['text'] ?? ''}',
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
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: ExplorerColors.border),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Request location',
              onPressed: _requestingLocation ? null : _requestLocation,
              icon: const Icon(Icons.location_searching),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: TextField(
                controller: _input,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Private message...',
                  isDense: true,
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _sending ? null : _sendText,
              icon: _sending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateLocationRequestBanner extends StatelessWidget {
  const _PrivateLocationRequestBanner({
    required this.chatId,
  });

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('location_requests')
          .where('targetId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final pending = (snapshot.data?.docs ?? []).where((document) {
          final data = document.data();
          return data['requestType'] == 'private' &&
              data['chatId'] == chatId &&
              data['status'] == 'pending';
        }).toList();

        if (pending.isEmpty) return const SizedBox.shrink();

        final request = pending.first;
        final data = request.data();
        final requesterName = '${data['requesterName'] ?? 'Traveler'}';

        return Container(
          width: double.infinity,
          color: ExplorerColors.goldSoft,
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(
            children: [
              const Icon(
                Icons.location_searching,
                color: ExplorerColors.goldDark,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '$requesterName requested your current location.',
                  style: const TextStyle(
                    color: ExplorerColors.goldDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => respondToPrivateLocationRequest(
                  context,
                  request,
                  shareLocation: false,
                ),
                child: const Text(
                  'Reject',
                  style: TextStyle(color: ExplorerColors.danger),
                ),
              ),
              FilledButton(
                onPressed: () => respondToPrivateLocationRequest(
                  context,
                  request,
                  shareLocation: true,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ExplorerColors.navy,
                  minimumSize: const Size(58, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text(
                  'Share',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PrivateSharedLocationMapPage extends StatefulWidget {
  const PrivateSharedLocationMapPage({
    super.key,
    required this.personName,
    required this.targetLat,
    required this.targetLng,
  });

  final String personName;
  final double targetLat;
  final double targetLng;

  @override
  State<PrivateSharedLocationMapPage> createState() =>
      _PrivateSharedLocationMapPageState();
}

class _PrivateSharedLocationMapPageState
    extends State<PrivateSharedLocationMapPage> {
  GoogleMapController? _controller;
  Position? _myPosition;
  double? _distanceMeters;

  @override
  void initState() {
    super.initState();
    _loadMyPosition();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadMyPosition() async {
    try {
      final position = await determinePosition();
      if (!mounted) return;

      setState(() {
        _myPosition = position;
        _distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          widget.targetLat,
          widget.targetLng,
        );
      });

      _fitMap();
    } catch (_) {
      // The shared point can still be viewed without the viewer's location.
    }
  }

  Future<void> _fitMap() async {
    final controller = _controller;
    if (controller == null) return;

    final target = LatLng(widget.targetLat, widget.targetLng);

    if (_myPosition == null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
      return;
    }

    final me = LatLng(
      _myPosition!.latitude,
      _myPosition!.longitude,
    );

    final minLat = min(me.latitude, target.latitude);
    final maxLat = max(me.latitude, target.latitude);
    final minLng = min(me.longitude, target.longitude);
    final maxLng = max(me.longitude, target.longitude);

    if (minLat == maxLat && minLng == maxLng) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16),
      );
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = LatLng(widget.targetLat, widget.targetLng);
    final me = _myPosition == null
        ? null
        : LatLng(_myPosition!.latitude, _myPosition!.longitude);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('shared_location'),
        position: target,
        infoWindow: InfoWindow(
          title: widget.personName,
          snippet: 'Shared current location',
        ),
      ),
      if (me != null)
        Marker(
          markerId: const MarkerId('me'),
          position: me,
          infoWindow: const InfoWindow(title: 'You'),
        ),
    };

    final polylines = <Polyline>{
      if (me != null)
        Polyline(
          polylineId: const PolylineId('private_location_line'),
          points: [me, target],
          width: 5,
          color: ExplorerColors.navy,
          patterns: [
            PatternItem.dash(18),
            PatternItem.gap(9),
          ],
        ),
    };

    final distanceText = _distanceMeters == null
        ? 'Shared current location'
        : _distanceMeters! < 1000
            ? '${_distanceMeters!.round()} m away'
            : '${(_distanceMeters! / 1000).toStringAsFixed(2)} km away';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: Text('${widget.personName}\'s Location'),
        actions: [
          IconButton(
            tooltip: 'Fit locations',
            onPressed: _fitMap,
            icon: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: target,
                zoom: 16,
              ),
              onMapCreated: (controller) {
                _controller = controller;
                WidgetsBinding.instance.addPostFrameCallback((_) => _fitMap());
              },
              markers: markers,
              polylines: polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: ExplorerCard(
              backgroundColor: ExplorerColors.navy,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.personName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          distanceText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
