part of '../admin_pages.dart';

class AdminCulturalPage extends StatelessWidget {
  const AdminCulturalPage({super.key});

  Future<void> createTask(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _TaskEditor(),
    );
    if (result == null) return;
    await AppServices.db.collection('cultural_tasks').add({
      ...result,
      'createdBy': AppServices.auth.currentUser!.uid,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> moderateSubmission(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool approve,
  ) async {
    final data = doc.data();
    final userId = '${data['userId'] ?? ''}';
    final points = (data['rewardPoints'] ?? 0) as num;
    if (userId.isEmpty) return;

    if (approve) {
      final duplicate = await AppServices.db
          .collection('task_submissions')
          .where('userId', isEqualTo: userId)
          .where('taskId', isEqualTo: data['taskId'])
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      if (duplicate.docs.isNotEmpty) {
        await doc.reference.update({
          'status': 'rejected',
          'reviewNote': 'Duplicate completion',
          'reviewedAt': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          showMessage(context, 'Duplicate submission rejected.', error: true);
        }
        return;
      }
      await AppServices.db.runTransaction((tx) async {
        final userRef = AppServices.userRef(userId);
        final userSnap = await tx.get(userRef);
        final currentPoints = ((userSnap.data()?['points'] ?? 0) as num) + points;
        final impact =
            ((userSnap.data()?['localImpactScore'] ?? 0) as num) + points;
        final rank = impact >= 1000
            ? 'Gold'
            : impact >= 500
                ? 'Silver'
                : 'Bronze';
        tx.update(doc.reference, {
          'status': 'approved',
          'reviewedBy': AppServices.auth.currentUser!.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
        tx.update(userRef, {
          'points': currentPoints,
          'localImpactScore': impact,
          'rank': rank,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      await AppServices.notify(
        userId: userId,
        title: 'Cultural task approved',
        message:
            '${data['taskTitle']} was approved. $points reward points were added.',
        type: 'cultural_task',
        referenceId: doc.id,
      );
    } else {
      await doc.reference.update({
        'status': 'rejected',
        'reviewedBy': AppServices.auth.currentUser!.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      await AppServices.notify(
        userId: userId,
        title: 'Cultural task rejected',
        message: '${data['taskTitle']} did not meet the task requirements.',
        type: 'cultural_task',
        referenceId: doc.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: ExplorerAdminPageTitle(
              title: 'Cultural Experiences',
              subtitle:
                  'Publish cultural tasks, maintain heritage places and review tourist submissions.',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPlacesPage()),
                  ),
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: const Text('Manage Places'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => createTask(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Task'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ExplorerCard(
              padding: EdgeInsets.zero,
              child: const TabBar(
                tabs: [
                  Tab(text: 'Published Tasks'),
                  Tab(text: 'Pending Submissions'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _PublishedTasks(createTask: () => createTask(context)),
                _PendingCulturalSubmissions(
                  onModerate: (doc, approve) =>
                      moderateSubmission(context, doc, approve),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishedTasks extends StatelessWidget {
  const _PublishedTasks({required this.createTask});

  final VoidCallback createTask;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db.collection('cultural_tasks').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              ExplorerCard(
                child: Column(
                  children: [
                    const ExplorerEmptyState(
                      title: 'No cultural tasks',
                      subtitle: 'Create the first cultural experience task.',
                      icon: Icons.account_balance_outlined,
                    ),
                    FilledButton.icon(
                      onPressed: createTask,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Task'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final taskStatus = '${data['status'] ?? 'active'}';
            return ExplorerCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: ExplorerColors.goldSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: ExplorerColors.goldDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${data['title'] ?? 'Cultural Task'}',
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            ExplorerStatusBadge(
                              label: taskStatus.toUpperCase(),
                              tone: taskStatus == 'active'
                                  ? ExplorerStatusTone.success
                                  : ExplorerStatusTone.neutral,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${data['description'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 5,
                          children: [
                            _CulturalMeta(
                              icon: Icons.category_outlined,
                              text: '${data['category'] ?? '-'}',
                            ),
                            _CulturalMeta(
                              icon: Icons.place_outlined,
                              text: '${data['locationName'] ?? '-'}',
                            ),
                            _CulturalMeta(
                              icon: Icons.stars_outlined,
                              text: '${data['rewardPoints'] ?? 0} points',
                            ),
                            _CulturalMeta(
                              icon: Icons.event_outlined,
                              text: asDate(data['deadline']) == null
                                  ? 'No deadline'
                                  : DateFormat.yMMMd()
                                      .format(asDate(data['deadline'])!),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        await doc.reference.delete();
                      } else {
                        await doc.reference.update({
                          'status': value,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: taskStatus == 'active' ? 'inactive' : 'active',
                        child: Text(
                          taskStatus == 'active' ? 'Deactivate' : 'Activate',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PendingCulturalSubmissions extends StatelessWidget {
  const _PendingCulturalSubmissions({required this.onModerate});

  final Future<void> Function(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool approve,
  ) onModerate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('task_submissions')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: const [
              ExplorerCard(
                child: ExplorerEmptyState(
                  title: 'No pending submissions',
                  subtitle: 'New tourist evidence will appear here.',
                  icon: Icons.fact_check_outlined,
                ),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return ExplorerCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (data['imageUrl'] ?? '').toString().isNotEmpty
                        ? Image.network(
                            '${data['imageUrl']}',
                            width: 128,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _submissionPlaceholder(),
                          )
                        : _submissionPlaceholder(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['taskTitle'] ?? 'Task Submission'}',
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 14,
                          runSpacing: 5,
                          children: [
                            _CulturalMeta(
                              icon: Icons.person_outline,
                              text: 'User: ${data['userId'] ?? '-'}',
                            ),
                            _CulturalMeta(
                              icon: Icons.image_search_outlined,
                              text:
                                  'Expected: ${data['expectedCategory'] ?? '-'}',
                            ),
                            _CulturalMeta(
                              icon: Icons.auto_awesome_outlined,
                              text:
                                  'AI: ${data['aiResult'] ?? '-'} (${data['confidence'] ?? 0})',
                            ),
                            _CulturalMeta(
                              icon: Icons.stars_outlined,
                              text: '${data['rewardPoints'] ?? 0} points',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      FilledButton.icon(
                        onPressed: () => onModerate(doc, true),
                        icon: const Icon(Icons.check, size: 17),
                        label: const Text('Approve'),
                      ),
                      const SizedBox(height: 7),
                      OutlinedButton.icon(
                        onPressed: () => onModerate(doc, false),
                        icon: const Icon(Icons.close, size: 17),
                        label: const Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _submissionPlaceholder() => Container(
        width: 128,
        height: 96,
        color: ExplorerColors.navySoft,
        child: const Icon(
          Icons.image_outlined,
          color: ExplorerColors.navy,
          size: 38,
        ),
      );
}

class _CulturalMeta extends StatelessWidget {
  const _CulturalMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ExplorerColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: ExplorerColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor();

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  final title = TextEditingController();
  final description = TextEditingController();
  final locationName = TextEditingController();
  final vendorId = TextEditingController();
  final photoCategory = TextEditingController(text: 'landmark');
  final points = TextEditingController(text: '150');
  String category = 'Heritage';
  DateTime deadline = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    locationName.dispose();
    vendorId.dispose();
    photoCategory.dispose();
    points.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Cultural Task'),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Task title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description and requirements',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['Heritage', 'Food', 'Craft', 'Landmark', 'Local Business']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => category = value!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationName,
                decoration: const InputDecoration(
                  labelText: 'Location / vendor name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: vendorId,
                decoration: const InputDecoration(
                  labelText: 'Linked vendor UID (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: photoCategory,
                decoration: const InputDecoration(
                  labelText: 'Required photo category',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: points,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reward points'),
              ),
              const SizedBox(height: 10),
              ListTile(
                tileColor: ExplorerColors.subtle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: const Text('Deadline'),
                subtitle: Text(DateFormat.yMMMd().format(deadline)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: deadline,
                  );
                  if (picked != null) setState(() => deadline = picked);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (title.text.trim().isEmpty ||
                locationName.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(context, {
              'title': title.text.trim(),
              'description': description.text.trim(),
              'category': category,
              'locationName': locationName.text.trim(),
              'vendorId':
                  vendorId.text.trim().isEmpty ? null : vendorId.text.trim(),
              'requiredPhotoCategory': photoCategory.text.trim(),
              'rewardPoints': int.tryParse(points.text) ?? 0,
              'deadline': Timestamp.fromDate(deadline),
            });
          },
          child: const Text('Publish'),
        ),
      ],
    );
  }
}
