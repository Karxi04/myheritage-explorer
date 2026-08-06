
part of '../traveler_pages.dart';

class CulturalTasksPage extends StatefulWidget {
  const CulturalTasksPage({super.key});

  @override
  State<CulturalTasksPage> createState() => _CulturalTasksPageState();
}

class _CulturalTasksPageState extends State<CulturalTasksPage> {
  String category = 'All';

  Future<void> submit(
    BuildContext context,
    String taskId,
    Map<String, dynamic> task,
  ) async {
    final uid = AppServices.auth.currentUser!.uid;
    final existing = await AppServices.db
        .collection('task_submissions')
        .where('userId', isEqualTo: uid)
        .where('taskId', isEqualTo: taskId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty &&
        existing.docs.first.data()['status'] != 'rejected') {
      if (context.mounted) {
        showMessage(
          context,
          'You already submitted this task.',
          error: true,
        );
      }
      return;
    }

    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image == null) return;

    if (context.mounted) {
      showMessage(context, 'Uploading evidence...');
    }

    try {
      final url = await AppServices.uploadImage(
        folder: 'cultural_submissions',
        uid: uid,
        bytes: await image.readAsBytes(),
        extension: image.name.split('.').last,
      );

      final data = {
        'taskId': taskId,
        'taskTitle': task['title'],
        'userId': uid,
        'vendorId': task['vendorId'],
        'imageUrl': url,
        'expectedCategory': task['requiredPhotoCategory'],
        'aiResult': 'manual_fallback',
        'confidence': 0,
        'status': 'pending',
        'rewardPoints': task['rewardPoints'] ?? 0,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isEmpty) {
        await AppServices.db.collection('task_submissions').add(data);
      } else {
        await existing.docs.first.reference.update(data);
      }

      if (context.mounted) {
        showMessage(
          context,
          'Photo submitted for administrator verification.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

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
          IconButton(
            tooltip: 'Search tasks',
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cultural Tasks',
                  style: TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['All', 'Food', 'Craft', 'Landmark']
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(item),
                              selected: category == item,
                              onSelected: (_) =>
                                  setState(() => category = item),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppServices.db
                  .collection('cultural_tasks')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, taskSnapshot) {
                if (!taskSnapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final tasks = taskSnapshot.data!.docs.where((doc) {
                  final deadline = asDate(doc.data()['deadline']);
                  if (deadline != null && deadline.isBefore(DateTime.now())) {
                    return false;
                  }
                  if (category == 'All') return true;
                  return '${doc.data()['category'] ?? ''}'
                      .toLowerCase()
                      .contains(category.toLowerCase());
                }).toList();

                if (tasks.isEmpty) {
                  return const ExplorerEmptyState(
                    title: 'No active cultural tasks',
                    subtitle:
                        'New cultural experiences will appear here after they are published.',
                    icon: Icons.assignment_outlined,
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: AppServices.db
                      .collection('task_submissions')
                      .where('userId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, submissionSnapshot) {
                    final submissions =
                        submissionSnapshot.data?.docs ?? const [];
                    final byTask =
                        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                    for (final submission in submissions) {
                      final taskId = '${submission.data()['taskId'] ?? ''}';
                      if (taskId.isNotEmpty) {
                        byTask[taskId] = submission;
                      }
                    }

                    tasks.sort((a, b) {
                      final aSubmission = byTask[a.id]?.data();
                      final bSubmission = byTask[b.id]?.data();
                      return _statusOrder(aSubmission?['status'])
                          .compareTo(_statusOrder(bSubmission?['status']));
                    });

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = tasks[index];
                        final task = doc.data();
                        final submission = byTask[doc.id]?.data();
                        return _taskCard(
                          context,
                          doc.id,
                          task,
                          submission,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int _statusOrder(dynamic status) {
    return switch ('$status') {
      'pending' => 1,
      'approved' => 2,
      'rejected' => 0,
      _ => 0,
    };
  }

  Widget _taskCard(
    BuildContext context,
    String taskId,
    Map<String, dynamic> task,
    Map<String, dynamic>? submission,
  ) {
    final status = '${submission?['status'] ?? 'available'}';
    final label = switch (status) {
      'pending' => 'PENDING REVIEW',
      'approved' => 'COMPLETED',
      'rejected' => 'REQUIRES RESUBMISSION',
      _ => 'AVAILABLE',
    };
    final tone = switch (status) {
      'pending' => ExplorerStatusTone.warning,
      'approved' => ExplorerStatusTone.success,
      'rejected' => ExplorerStatusTone.danger,
      _ => ExplorerStatusTone.navy,
    };
    final imageUrl =
        '${submission?['imageUrl'] ?? task['imageUrl'] ?? ''}'.trim();

    return ExplorerCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
            child: Row(
              children: [
                ExplorerStatusBadge(label: label, tone: tone),
                const Spacer(),
                Text(
                  '${task['rewardPoints'] ?? 0}',
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 3),
                const Text(
                  'PTS',
                  style: TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${task['title'] ?? 'Cultural Experience'}',
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${task['description'] ?? ''}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      color: ExplorerColors.muted,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${task['locationName'] ?? task['category'] ?? ''}',
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (submission?['confidence'] != null)
                      Text(
                        'Match: ${(((submission!['confidence'] ?? 0) as num) * 100).round()}%',
                        style: const TextStyle(
                          color: ExplorerColors.goldDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (imageUrl.startsWith('http'))
            Image.network(
              imageUrl,
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _taskImagePlaceholder(),
            )
          else
            _taskImagePlaceholder(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (status == 'approved')
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified,
                        color: ExplorerColors.success,
                        size: 18,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Task verified and reward awarded',
                        style: TextStyle(
                          color: ExplorerColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                else if (status == 'pending')
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        color: ExplorerColors.goldDark,
                        size: 18,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Your submission is being reviewed',
                        style: TextStyle(
                          color: ExplorerColors.goldDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  )
                else ...[
                  if (status == 'rejected') ...[
                    OutlinedButton.icon(
                      onPressed: () => submit(context, taskId, task),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Retake Photo'),
                    ),
                    const SizedBox(height: 9),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => submit(context, taskId, task),
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text(
                      status == 'rejected'
                          ? 'Submit Verification'
                          : 'Complete Task with Photo',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 135,
      color: ExplorerColors.companionBackground,
      child: const Icon(
        Icons.add_a_photo_outlined,
        color: ExplorerColors.navy,
        size: 42,
      ),
    );
  }
}
