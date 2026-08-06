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
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    bool approve,
  ) async {
    final data = document.data();
    final userId = data['userId'] as String;
    final points =
        (data['rewardPoints'] as num?)?.toInt() ?? 0;

    if (approve) {
      final duplicate = await AppServices.db
          .collection('task_submissions')
          .where('userId', isEqualTo: userId)
          .where('taskId', isEqualTo: data['taskId'])
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (duplicate.docs.isNotEmpty) {
        await document.reference.update({
          'status': 'rejected',
          'reviewNote': 'Duplicate completion',
          'reviewedAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          showMessage(
            context,
            'Duplicate submission rejected.',
            error: true,
          );
        }
        return;
      }

      await AppServices.db.runTransaction(
        (transaction) async {
          final travelerRef =
              AppServices.travelerRef(userId);
          final travelerSnapshot =
              await transaction.get(travelerRef);

          if (!travelerSnapshot.exists ||
              travelerSnapshot.data()?['role'] !=
                  'traveler') {
            throw Exception(
              'Traveler profile was not found.',
            );
          }

          final currentPoints =
              ((travelerSnapshot.data()?['points'] ?? 0)
                          as num)
                      .toInt() +
                  points;
          final impact =
              ((travelerSnapshot
                                  .data()?['localImpactScore'] ??
                              0)
                          as num)
                      .toInt() +
                  points;

          final rank = impact >= 1000
              ? 'Gold'
              : impact >= 500
                  ? 'Silver'
                  : 'Bronze';

          transaction.update(document.reference, {
            'status': 'approved',
            'reviewedBy':
                AppServices.auth.currentUser!.uid,
            'reviewedAt':
                FieldValue.serverTimestamp(),
          });

          transaction.update(travelerRef, {
            'points': currentPoints,
            'localImpactScore': impact,
            'rank': rank,
            'updatedAt':
                FieldValue.serverTimestamp(),
          });
        },
      );

      await AppServices.notify(
        userId: userId,
        title: 'Cultural task approved',
        message:
            '${data['taskTitle']} was approved. $points reward points were added.',
        type: 'cultural_task',
        referenceId: document.id,
      );
    } else {
      await document.reference.update({
        'status': 'rejected',
        'reviewedBy': AppServices.auth.currentUser!.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      await AppServices.notify(
        userId: userId,
        title: 'Cultural task rejected',
        message:
            '${data['taskTitle']} did not meet the task requirements.',
        type: 'cultural_task',
        referenceId: document.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const TabBar(
              tabs: [
                Tab(text: 'Published tasks'),
                Tab(text: 'Pending submissions'),
              ],
            ),
            actions: [
              Padding(
                padding:
                    const EdgeInsets.only(right: 16),
                child: FilledButton.icon(
                  onPressed: () => createTask(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create task'),
                ),
              ),
            ],
          ),
          body: TabBarView(
            children: [
              StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('cultural_tasks')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return emptyState(
                      'No cultural tasks',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final document = docs[index];
                      final data = document.data();

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(
                              Icons.task_alt_outlined,
                            ),
                          ),
                          title:
                              Text('${data['title'] ?? ''}'),
                          subtitle: Text(
                            '${data['category'] ?? ''} • '
                            '${data['taskType'] ?? 'Cultural discovery'}\n'
                            '${data['vendorName'] ?? data['locationName'] ?? ''} • '
                            '${data['difficulty'] ?? 'Easy'} • '
                            '${data['rewardPoints'] ?? 0} points • '
                            '${data['status'] ?? ''}\n'
                            'Deadline '
                            '${asDate(data['deadline']) == null ? '-' : DateFormat.yMMMd().format(asDate(data['deadline'])!)}',
                          ),
                          isThreeLine: true,
                          trailing:
                              PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'delete') {
                                await document.reference
                                    .delete();
                              } else {
                                await document.reference
                                    .update({
                                  'status': value,
                                  'updatedAt': FieldValue
                                      .serverTimestamp(),
                                });
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value:
                                    data['status'] == 'active'
                                        ? 'inactive'
                                        : 'active',
                                child: Text(
                                  data['status'] == 'active'
                                      ? 'Deactivate'
                                      : 'Activate',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('task_submissions')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return emptyState(
                      'No pending task submissions',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final document = docs[index];
                      final data = document.data();

                      return Card(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              if ('${data['imageUrl'] ?? ''}'
                                  .isNotEmpty)
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: Image.network(
                                    '${data['imageUrl']}',
                                    width: 130,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            const SizedBox(
                                      width: 130,
                                      child: Icon(
                                        Icons
                                            .broken_image_outlined,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(
                                  width: 130,
                                  child: Icon(
                                    Icons.image_outlined,
                                  ),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${data['taskTitle'] ?? ''}',
                                      style:
                                          const TextStyle(
                                        fontSize: 18,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Category: '
                                      '${data['taskCategory'] ?? '-'}',
                                    ),
                                    Text(
                                      'Traveler: '
                                      '${data['userId']}',
                                    ),
                                    Text(
                                      'Expected evidence: '
                                      '${data['expectedCategory'] ?? '-'}',
                                    ),
                                    Text(
                                      'Verification: '
                                      '${data['aiResult'] ?? '-'} '
                                      '(${data['confidence'] ?? 0})',
                                    ),
                                    Text(
                                      'Reward: '
                                      '${data['rewardPoints'] ?? 0} points',
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  FilledButton.icon(
                                    onPressed: () =>
                                        moderateSubmission(
                                      context,
                                      document,
                                      true,
                                    ),
                                    icon: const Icon(Icons.check),
                                    label:
                                        const Text('Approve'),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        moderateSubmission(
                                      context,
                                      document,
                                      false,
                                    ),
                                    icon: const Icon(Icons.close),
                                    label:
                                        const Text('Reject'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor();

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  static const categoryDetails = {
    'Heritage & History': {
      'taskType': 'Heritage Story Discovery',
      'photoCategory': 'heritage_feature',
      'difficulty': 'Easy',
      'points': '120',
      'learningOutcome':
          'Learn one verified fact about Penang history or built heritage.',
    },
    'Food Heritage': {
      'taskType': 'Local Dish Discovery',
      'photoCategory': 'local_food',
      'difficulty': 'Easy',
      'points': '100',
      'learningOutcome':
          'Recognise a Penang dish, ingredient or preparation tradition.',
    },
    'Traditional Craft': {
      'taskType': 'Craft Process Observation',
      'photoCategory': 'local_craft',
      'difficulty': 'Medium',
      'points': '150',
      'learningOutcome':
          'Understand one material or technique used by a Penang maker.',
    },
    'Arts & Performance': {
      'taskType': 'Cultural Art Appreciation',
      'photoCategory': 'cultural_art',
      'difficulty': 'Medium',
      'points': '140',
      'learningOutcome':
          'Identify the cultural meaning of an artwork, object or performance.',
    },
    'Nature & Conservation': {
      'taskType': 'Conservation Observation',
      'photoCategory': 'nature_feature',
      'difficulty': 'Medium',
      'points': '150',
      'learningOutcome':
          'Recognise one Penang habitat or conservation practice.',
    },
    'Community & Local Business': {
      'taskType': 'Local Product Discovery',
      'photoCategory': 'local_product',
      'difficulty': 'Easy',
      'points': '100',
      'learningOutcome':
          'Learn how a Penang local product or service supports the community.',
    },
  };

  final title = TextEditingController();
  final description = TextEditingController();
  final photoCategory =
      TextEditingController(text: 'heritage_feature');
  final points = TextEditingController(text: '120');
  final learningOutcome = TextEditingController(
    text:
        'Learn one verified fact about Penang history or built heritage.',
  );

  String category = 'Heritage & History';
  String taskType = 'Heritage Story Discovery';
  String difficulty = 'Easy';
  String? selectedVendorId;
  Map<String, dynamic>? selectedVendor;
  DateTime deadline =
      DateTime.now().add(const Duration(days: 30));

  void _applyCategory(String selected) {
    final details = categoryDetails[selected]!;

    setState(() {
      category = selected;
      taskType = '${details['taskType']}';
      difficulty = '${details['difficulty']}';
      photoCategory.text =
          '${details['photoCategory']}';
      points.text = '${details['points']}';
      learningOutcome.text =
          '${details['learningOutcome']}';
    });
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    photoCategory.dispose();
    points.dispose();
    learningOutcome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Create Vendor Cultural Task'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Task title',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText:
                        'Description and traveler instructions',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Cultural-task category',
                  ),
                  items: categoryDetails.keys
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _applyCategory(value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey(taskType),
                  initialValue: taskType,
                  decoration: const InputDecoration(
                    labelText: 'Task type',
                  ),
                  items: [
                    taskType,
                    'Photo and short explanation',
                    'Observation and reflection',
                    'Product or process discovery',
                  ]
                      .toSet()
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => taskType = value ?? taskType,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey(difficulty),
                  initialValue: difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Easy',
                      child: Text('Easy'),
                    ),
                    DropdownMenuItem(
                      value: 'Medium',
                      child: Text('Medium'),
                    ),
                    DropdownMenuItem(
                      value: 'Advanced',
                      child: Text('Advanced'),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => difficulty =
                        value ?? difficulty,
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  future: AppServices.db
                      .collection('vendors')
                      .get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }

                    final vendors =
                        snapshot.data!.docs.where((doc) {
                      final data = doc.data();
                      return data['status'] == 'active' &&
                          data['vendorStatus'] == 'verified';
                    }).toList()
                          ..sort(
                            (first, second) =>
                                '${first.data()['businessName'] ?? ''}'
                                    .compareTo(
                              '${second.data()['businessName'] ?? ''}',
                            ),
                          );

                    return DropdownButtonFormField<String>(
                      initialValue: selectedVendorId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Registered vendor',
                      ),
                      items: vendors
                          .map(
                            (doc) => DropdownMenuItem(
                              value: doc.id,
                              child: Text(
                                '${doc.data()['businessName'] ?? doc.data()['displayName'] ?? doc.id}',
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        final document =
                            vendors.firstWhere(
                          (doc) => doc.id == value,
                        );

                        setState(() {
                          selectedVendorId = value;
                          selectedVendor =
                              document.data();
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: photoCategory,
                  decoration: const InputDecoration(
                    labelText:
                        'Required photo evidence category',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: learningOutcome,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Learning outcome',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: points,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Reward points',
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: Colors.white,
                  title: const Text('Deadline'),
                  subtitle: Text(
                    DateFormat.yMMMd().format(deadline),
                  ),
                  trailing: const Icon(
                    Icons.calendar_month_outlined,
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 730)),
                      initialDate: deadline,
                    );

                    if (picked != null) {
                      setState(() => deadline = picked);
                    }
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
              final vendor = selectedVendor;
              final vendorId = selectedVendorId;
              final reward =
                  int.tryParse(points.text) ?? 0;

              if (title.text.trim().isEmpty ||
                  description.text.trim().isEmpty ||
                  vendor == null ||
                  vendorId == null ||
                  reward <= 0) {
                showMessage(
                  context,
                  'Enter the task details, select a verified vendor and use a positive reward value.',
                  error: true,
                );
                return;
              }

              final vendorName =
                  '${vendor['businessName'] ?? vendor['displayName'] ?? 'Vendor'}';

              Navigator.pop(context, {
                'title': title.text.trim(),
                'description':
                    description.text.trim(),
                'category': category,
                'categoryCode': category
                    .toLowerCase()
                    .replaceAll('&', 'and')
                    .replaceAll(
                      RegExp(r'[^a-z0-9]+'),
                      '_',
                    )
                    .replaceAll(
                      RegExp(r'^_+|_+$'),
                      '',
                    ),
                'taskType': taskType,
                'difficulty': difficulty,
                'locationName': vendorName,
                'vendorId': vendorId,
                'vendorName': vendorName,
                'vendorCategory':
                    vendor['businessCategory'],
                'placeId': 'vendor_$vendorId',
                'location': vendor['location'],
                'mapUrl': vendor['mapUrl'],
                'requiredPhotoCategory':
                    photoCategory.text.trim(),
                'evidenceType': 'photo_and_text',
                'learningOutcome':
                    learningOutcome.text.trim(),
                'rewardPoints': reward,
                'deadline':
                    Timestamp.fromDate(deadline),
                'optional': true,
              });
            },
            child: const Text('Publish'),
          ),
        ],
      );
}
