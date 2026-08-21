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
  bool _loading = false;

  Future<void> _removeMember(String memberId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Are you sure you want to remove $name from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: ExplorerColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await AppServices.db.collection('travel_groups').doc(widget.groupId).update({
        'memberIds': FieldValue.arrayRemove([memberId]),
      });
      if (mounted) showMessage(context, '$name removed.');
    } catch (e) {
      if (mounted) showMessage(context, 'Failed to remove member.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestLocation(String targetId, String name) async {
    final uid = AppServices.auth.currentUser!.uid;
    
    // Check for existing pending request
    final existing = await AppServices.db
        .collection('location_requests')
        .where('requesterId', isEqualTo: uid)
        .where('targetId', isEqualTo: targetId)
        .where('groupId', isEqualTo: widget.groupId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) {
      showMessage(context, 'A request is already pending for $name.');
      return;
    }

    try {
      await AppServices.db.collection('location_requests').add({
        'requesterId': uid,
        'targetId': targetId,
        'groupId': widget.groupId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) showMessage(context, 'Location request sent to $name.');
    } catch (e) {
      if (mounted) showMessage(context, 'Failed to send request.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;
    final isLeader = widget.group['leaderId'] == uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Manage Members')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppServices.db.collection('travel_groups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final groupData = snapshot.data!.data() ?? {};
          final memberIds = List<String>.from(groupData['memberIds'] ?? []);

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: memberIds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final memberId = memberIds[index];
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: AppServices.travelerRef(memberId).get(),
                builder: (context, userSnap) {
                  final userData = userSnap.data?.data() ?? {};
                  final name = userData['displayName'] ?? 'Member';
                  final isMe = memberId == uid;
                  final isMemberLeader = memberId == groupData['leaderId'];

                  return ExplorerCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isMemberLeader ? ExplorerColors.gold : ExplorerColors.navy,
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        isMe ? '$name (You)' : name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(isMemberLeader ? 'Group Leader' : 'Companion'),
                      trailing: isMe ? null : PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'request') _requestLocation(memberId, name);
                          if (val == 'remove') _removeMember(memberId, name);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'request',
                            child: Row(
                              children: [
                                Icon(Icons.location_searching, size: 18),
                                SizedBox(width: 8),
                                Text('Request Location'),
                              ],
                            ),
                          ),
                          if (isLeader && !isMemberLeader)
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove_outlined, size: 18, color: ExplorerColors.danger),
                                  SizedBox(width: 8),
                                  Text('Remove Member', style: TextStyle(color: ExplorerColors.danger)),
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
          );
        },
      ),
    );
  }
}
