
part of '../traveler_pages.dart';

class CompanionPage extends StatelessWidget {
  const CompanionPage({super.key});

  Future<void> createGroup(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Travel Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
    if (confirmed != true || name.text.trim().isEmpty) return;

    final uid = AppServices.auth.currentUser!.uid;
    await AppServices.db.collection('travel_groups').add({
      'name': name.text.trim(),
      'description': description.text.trim(),
      'code': randomCode(),
      'leaderId': uid,
      'memberIds': [uid],
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> joinGroup(BuildContext context) async {
    final code = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Travel Group'),
        content: TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Group Code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join Group'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final snap = await AppServices.db
        .collection('travel_groups')
        .where('code', isEqualTo: code.text.trim().toUpperCase())
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      if (context.mounted) {
        showMessage(context, 'Invalid group code.', error: true);
      }
      return;
    }

    await snap.docs.first.reference.update({
      'memberIds': FieldValue.arrayUnion([
        AppServices.auth.currentUser!.uid,
      ]),
    });

    if (context.mounted) {
      showMessage(context, 'Joined group successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.companionBackground,
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: ExplorerColors.companionBackground,
                  child: CustomPaint(painter: _MapPatternPainter()),
                ),
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  ExplorerCard(
                    backgroundColor: const Color(0xFFFFE6E1),
                    borderColor: const Color(0xFFF6B8AE),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: ExplorerColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.crisis_alert,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Separation Alert',
                                style: TextStyle(
                                  color: ExplorerColors.danger,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'A group member may be outside the preferred safety distance.',
                                style: TextStyle(
                                  color: Color(0xFF9B3C33),
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: docs.isEmpty
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GroupDetailsPage(
                                        groupId: docs.first.id,
                                        group: docs.first.data(),
                                      ),
                                    ),
                                  ),
                          child: const Text('Ping'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (docs.isEmpty)
                    ExplorerCard(
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: ExplorerColors.navySoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.groups_outlined,
                              color: ExplorerColors.navy,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No Travel Group Yet',
                            style: TextStyle(
                              color: ExplorerColors.navy,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Create a private travel group or join one using a six-character code.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () => createGroup(context),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Create Travel Group'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => joinGroup(context),
                            icon: const Icon(Icons.login),
                            label: const Text('Join Travel Group'),
                          ),
                        ],
                      ),
                    )
                  else
                    ...docs.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _groupCard(
                          context,
                          doc.id,
                          doc.data(),
                          uid,
                        ),
                      ),
                    ),
                  if (docs.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => createGroup(context),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Create'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => joinGroup(context),
                            icon: const Icon(Icons.login),
                            label: const Text('Join'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ExplorerCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'EMERGENCY',
                                  style: TextStyle(
                                    color: ExplorerColors.muted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  docs.first.data()['leaderId'] == uid
                                      ? 'Review member SOS alerts'
                                      : 'Need immediate help?',
                                  style: const TextStyle(
                                    color: ExplorerColors.navy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupDetailsPage(
                                  groupId: docs.first.id,
                                  group: docs.first.data(),
                                ),
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(58, 58),
                              backgroundColor: ExplorerColors.danger,
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              docs.first.data()['leaderId'] == uid
                                  ? 'ALERTS'
                                  : 'SOS',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _groupCard(
    BuildContext context,
    String groupId,
    Map<String, dynamic> group,
    String uid,
  ) {
    final members = List<String>.from(group['memberIds'] ?? const []);
    final isLeader = group['leaderId'] == uid;

    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tour Group',
                style: TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              ExplorerStatusBadge(
                label: '${group['code'] ?? '-'}',
                tone: ExplorerStatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ...List.generate(
                members.length.clamp(0, 3),
                (index) => Transform.translate(
                  offset: Offset(index == 0 ? 0 : -6.0 * index, 0),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor:
                        index == 0 ? ExplorerColors.navy : ExplorerColors.gold,
                    foregroundColor:
                        index == 0 ? Colors.white : ExplorerColors.navy,
                    child: Text(
                      index == 0 ? 'ME' : '${index + 1}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              if (members.length > 3)
                Text(
                  '+${members.length - 3}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const Spacer(),
              if (isLeader)
                const ExplorerStatusBadge(
                  label: 'LEADER',
                  tone: ExplorerStatusTone.navy,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${group['name'] ?? 'Travel Group'}',
            style: const TextStyle(
              color: ExplorerColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          if ('${group['description'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${group['description']}',
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailsPage(
                        groupId: groupId,
                        group: group,
                      ),
                    ),
                  ),
                  child: Text(isLeader ? 'Add Member' : 'Manage'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupDetailsPage(
                        groupId: groupId,
                        group: group,
                      ),
                    ),
                  ),
                  child: const Text('Open Map'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFDCEAF2)
      ..strokeWidth = 2;
    final minorPaint = Paint()
      ..color = const Color(0xFFE8F1F5)
      ..strokeWidth = 1;

    for (double y = 55; y < size.height; y += 85) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 28), roadPaint);
    }
    for (double x = 35; x < size.width; x += 78) {
      canvas.drawLine(Offset(x, 0), Offset(x + 42, size.height), minorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
