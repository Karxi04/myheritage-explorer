part of '../traveler_pages.dart';

class PrivateChatsPage extends StatefulWidget {
  const PrivateChatsPage({super.key});

  @override
  State<PrivateChatsPage> createState() => _PrivateChatsPageState();
}

class _PrivateChatsPageState extends State<PrivateChatsPage> {
  bool _startingChat = false;

  Future<String?> _askForTravelerEmail() async {
    String email = '';

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Start Private Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the registered email address of another traveler.',
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
              onChanged: (value) => email = value.trim().toLowerCase(),
              onFieldSubmitted: (_) {
                if (email.isNotEmpty) {
                  Navigator.pop(dialogContext, email);
                }
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = email.trim().toLowerCase();

              if (value.isEmpty) {
                showMessage(
                  dialogContext,
                  'Please enter a registered traveler email.',
                  error: true,
                );
                return;
              }

              Navigator.pop(dialogContext, value);
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _startNewChat() async {
    if (_startingChat) return;

    final email = await _askForTravelerEmail();
    if (!mounted || email == null || email.isEmpty) return;

    setState(() => _startingChat = true);

    try {
      final currentUser = AppServices.auth.currentUser;
      if (currentUser == null) return;

      if (currentUser.email?.trim().toLowerCase() == email) {
        throw Exception('You cannot start a private chat with yourself.');
      }

      final travelerQuery = await AppServices.db
          .collection('travelers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (travelerQuery.docs.isEmpty) {
        throw Exception('No registered traveler was found for that email.');
      }

      final travelerDocument = travelerQuery.docs.first;
      final traveler = travelerDocument.data();

      final otherUserId = '${traveler['uid'] ?? travelerDocument.id}'.trim();
      final otherUserName = '${traveler['displayName'] ?? 'Traveler'}'.trim();

      if (otherUserId.isEmpty) {
        throw Exception('This traveler account has no valid user ID.');
      }

      if ('${traveler['role'] ?? ''}'.toLowerCase() != 'traveler') {
        throw Exception('Private Companion chat is available to traveler accounts only.');
      }

      if ('${traveler['status'] ?? ''}'.toLowerCase() != 'active') {
        throw Exception('This traveler account is not active.');
      }

      if (!mounted) return;

      await openCompanionPrivateChat(
        context,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
      );
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
        setState(() => _startingChat = false);
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

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Private Chats'),
        actions: [
          IconButton(
            tooltip: 'Start new private chat',
            onPressed: _startingChat ? null : _startNewChat,
            icon: _startingChat
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('private_chats')
            .where('participantIds', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load private chats.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final first = asDate(a.data()['lastMessageAt']) ??
                  asDate(a.data()['updatedAt']) ??
                  asDate(a.data()['createdAt']) ??
                  DateTime(2000);

              final second = asDate(b.data()['lastMessageAt']) ??
                  asDate(b.data()['updatedAt']) ??
                  asDate(b.data()['createdAt']) ??
                  DateTime(2000);

              return second.compareTo(first);
            });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              ExplorerCard(
                backgroundColor: ExplorerColors.navySoft,
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: ExplorerColors.navy,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.lock_outline),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'One-to-One Private Chat',
                            style: TextStyle(
                              color: ExplorerColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Chat privately and request one-time current location sharing.',
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _startingChat ? null : _startNewChat,
                      icon: const Icon(Icons.add),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ExplorerSectionTitle(
                'Conversations',
                subtitle: chats.isEmpty
                    ? 'No private conversations yet.'
                    : '${chats.length} private conversation${chats.length == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 10),
              if (chats.isEmpty)
                ExplorerEmptyState(
                  title: 'No Private Chats Yet',
                  subtitle:
                      'Start a private conversation with another registered traveler.',
                  icon: Icons.chat_bubble_outline,
                  action: FilledButton.icon(
                    onPressed: _startingChat ? null : _startNewChat,
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Start Private Chat'),
                  ),
                )
              else
                ...chats.map((chatDocument) {
                  final chat = chatDocument.data();

                  final participantIds = List<String>.from(
                    chat['participantIds'] ?? const <String>[],
                  );

                  final otherUserId = participantIds.firstWhere(
                    (id) => id != uid,
                    orElse: () => '',
                  );

                  if (otherUserId.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final participantNames = Map<String, dynamic>.from(
                    chat['participantNames'] ?? const <String, dynamic>{},
                  );

                  final storedName = '${participantNames[otherUserId] ?? ''}'.trim();
                  final lastMessage = '${chat['lastMessage'] ?? ''}'.trim();
                  final lastMessageAt = asDate(chat['lastMessageAt']);

                  Widget buildTile(String otherName) {
                    final initial =
                        otherName.trim().isEmpty ? '?' : otherName.trim()[0].toUpperCase();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: ExplorerCard(
                        radius: 12,
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: ExplorerColors.navySoft,
                            foregroundColor: ExplorerColors.navy,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            otherName,
                            style: const TextStyle(
                              color: ExplorerColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage.isEmpty ? 'Start a conversation' : lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 10,
                            ),
                          ),
                          trailing: lastMessageAt == null
                              ? const Icon(Icons.chevron_right)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat.jm().format(lastMessageAt),
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: ExplorerColors.muted,
                                    ),
                                  ],
                                ),
                          onTap: () => openCompanionPrivateChat(
                            context,
                            otherUserId: otherUserId,
                            otherUserName: otherName,
                          ),
                        ),
                      ),
                    );
                  }

                  if (storedName.isNotEmpty) {
                    return buildTile(storedName);
                  }

                  return FutureBuilder<String>(
                    future: companionTravelerDisplayName(otherUserId),
                    builder: (context, nameSnapshot) {
                      return buildTile(nameSnapshot.data ?? 'Traveler');
                    },
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
