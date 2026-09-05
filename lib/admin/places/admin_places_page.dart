part of '../admin_pages.dart';

class AdminPlacesPage extends StatelessWidget {
  const AdminPlacesPage({super.key});

  Future<void> openEditor(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? initial,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PlaceEditor(initial: initial),
    );
    if (result == null) return;
    PlaceRepository.clearCache();
    if (id == null) {
      await AppServices.db.collection('places').add({
        ...result,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await AppServices.db.collection('places').doc(id).update({
        ...result,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _seedPlaces(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed Heritage Attractions'),
        content: const Text(
          'This will populate Firestore with verified heritage places across Malaysian states (Penang, Melaka, KL, etc.). Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Places'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final count = await PlaceRepository.seedInitialPlacesIfEmpty(force: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully seeded $count heritage destinations!'),
          backgroundColor: ExplorerColors.navy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEditor(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add Place'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Heritage Place Management',
              subtitle: 'Maintain destinations used by the Daily Planner across Malaysia.',
              leading: Navigator.canPop(context)
                  ? IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  : null,
              actions: [
                IconButton(
                  tooltip: 'Seed Heritage Catalogue',
                  icon: const Icon(Icons.cloud_sync_outlined),
                  onPressed: () => _seedPlaces(context),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db.collection('places').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ExplorerEmptyState(
                              title: 'No places found',
                              subtitle: 'Seed authentic Malaysian heritage places to make them available to travelers.',
                              icon: Icons.place_outlined,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _seedPlaces(context),
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('Seed Heritage Catalogue'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final status = '${data['status'] ?? 'active'}';
                      final imageUrl = '${data['primaryImageUrl'] ?? data['imageUrl'] ?? ''}'.trim();
                      final stateName = '${data['stateName'] ?? data['state'] ?? 'Malaysia'}';

                      return ExplorerCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: 106,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _placePlaceholder(),
                                    )
                                  : _placePlaceholder(),
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
                                          '${data['name'] ?? 'Heritage Place'}',
                                          style: const TextStyle(
                                            color: ExplorerColors.navy,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      ExplorerStatusBadge(
                                        label: status.toUpperCase(),
                                        tone: status == 'active'
                                            ? ExplorerStatusTone.success
                                            : ExplorerStatusTone.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$stateName • ${data['category'] ?? '-'} • ${data['area'] ?? '-'}',
                                    style: const TextStyle(
                                      color: ExplorerColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 5,
                                    children: [
                                      ExplorerStatusBadge(
                                        label: '${data['trustLabel'] ?? 'HIGH TRUST'}'.toUpperCase(),
                                        tone: data['trustLabel'] == 'High Trust'
                                            ? ExplorerStatusTone.success
                                            : ExplorerStatusTone.warning,
                                      ),
                                      ExplorerStatusBadge(
                                        label: '${data['score'] ?? data['publicRating'] ?? 4.5} SCORE',
                                        tone: ExplorerStatusTone.navy,
                                      ),
                                      ExplorerStatusBadge(
                                        label: '${data['durationMinutes'] ?? data['estimatedVisitMinutes'] ?? 60} MIN',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await openEditor(
                                    context,
                                    id: doc.id,
                                    initial: data,
                                  );
                                } else if (value == 'delete') {
                                  await doc.reference.delete();
                                  PlaceRepository.clearCache();
                                } else {
                                  await doc.reference.update({
                                    'status': value,
                                    'isActive': value == 'active',
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
                                  PlaceRepository.clearCache();
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: status == 'active' ? 'inactive' : 'active',
                                  child: Text(
                                    status == 'active' ? 'Deactivate' : 'Activate',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _placePlaceholder() => Container(
        width: 106,
        height: 84,
        color: ExplorerColors.navySoft,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: ExplorerColors.navy,
              size: 26,
            ),
            SizedBox(height: 2),
            Text(
              'No Image',
              style: TextStyle(fontSize: 9, color: ExplorerColors.muted),
            ),
          ],
        ),
      );
}

class _PlaceEditor extends StatefulWidget {
  const _PlaceEditor({this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  late final Map<String, TextEditingController> fields;
  String stateId = 'penang';
  String stateName = 'Penang';
  String category = 'Heritage';
  String trust = 'High Trust';
  String status = 'active';
  String budgetLevel = 'Medium';
  List<String> availableAreas = [];

  @override
  void initState() {
    super.initState();
    final data = widget.initial ?? {};
    fields = {
      for (final key in [
        'name',
        'description',
        'area',
        'score',
        'durationMinutes',
        'imageUrl',
        'additionalImages',
        'latitude',
        'longitude',
        'openingHours',
        'openingTime',
        'closingTime',
        'tags',
      ])
        key: TextEditingController(text: '${data[key] ?? ''}')
    };

    stateId = '${data['stateId'] ?? 'penang'}';
    stateName = '${data['stateName'] ?? data['state'] ?? 'Penang'}';
    category = data['category'] ?? 'Heritage';
    trust = data['trustLabel'] ?? 'High Trust';
    status = data['status'] ?? 'active';
    budgetLevel = data['budgetLevel'] ?? data['estimatedBudget'] ?? 'Medium';

    if (fields['durationMinutes']!.text.isEmpty) {
      fields['durationMinutes']!.text = '${data['estimatedVisitMinutes'] ?? 60}';
    }
    if (fields['score']!.text.isEmpty) {
      fields['score']!.text = '${data['publicRating'] ?? 4.8}';
    }
    if (fields['openingHours']!.text.isEmpty) {
      fields['openingHours']!.text = 'Daily 09:00 - 18:00';
    }
    if (fields['openingTime']!.text.isEmpty) {
      fields['openingTime']!.text = '09:00';
    }
    if (fields['closingTime']!.text.isEmpty) {
      fields['closingTime']!.text = '18:00';
    }
    if (data['tags'] is List) {
      fields['tags']!.text = (data['tags'] as List).join(', ');
    } else if (data['interestTags'] is List) {
      fields['tags']!.text = (data['interestTags'] as List).join(', ');
    }

    final geo = data['location'];
    if (geo is GeoPoint) {
      fields['latitude']!.text = '${geo.latitude}';
      fields['longitude']!.text = '${geo.longitude}';
    }

    _loadAreasForState(stateId);
  }

  Future<void> _loadAreasForState(String sId) async {
    final areas = await MalaysiaLocationService.getAreasForState(sId);
    if (mounted) {
      setState(() => availableAreas = areas);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'Add Place' : 'Edit Place'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: fields['name'],
                  decoration: const InputDecoration(labelText: 'Place Name *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: MalaysiaLocationService.defaultStates.any((s) => s.id == stateId)
                            ? stateId
                            : 'penang',
                        decoration: const InputDecoration(labelText: 'Malaysian State *'),
                        items: MalaysiaLocationService.defaultStates
                            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            stateId = v;
                            stateName = MalaysiaLocationService.getStateName(v);
                            _loadAreasForState(v);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: availableAreas.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              value: availableAreas.contains(fields['area']!.text)
                                  ? fields['area']!.text
                                  : null,
                              decoration: const InputDecoration(labelText: 'Area / City *'),
                              hint: const Text('Select Area'),
                              items: availableAreas
                                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => fields['area']!.text = v);
                                }
                              },
                            )
                          : TextField(
                              controller: fields['area'],
                              decoration: const InputDecoration(labelText: 'Area / City *'),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fields['description'],
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Category *'),
                        items: ['Heritage', 'Food', 'Culture', 'Art', 'Nature', 'Local Business']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => category = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: budgetLevel,
                        decoration: const InputDecoration(labelText: 'Estimated Budget'),
                        items: ['Low', 'Medium', 'High']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => budgetLevel = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fields['tags'],
                  decoration: const InputDecoration(
                    labelText: 'Interest Tags (comma-separated)',
                    hintText: 'e.g. Heritage, Culture, Museum, Architecture',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fields['durationMinutes'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Visit Duration (mins)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: fields['score'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Public Rating (1-5)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fields['openingHours'],
                        decoration: const InputDecoration(
                          labelText: 'Opening Hours',
                          hintText: 'e.g. Daily 09:00 - 18:00',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: trust,
                        decoration: const InputDecoration(labelText: 'Trust Classification'),
                        items: ['High Trust', 'Medium Trust', 'Low Trust', 'Insufficient Data']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => trust = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fields['imageUrl'],
                  decoration: const InputDecoration(
                    labelText: 'Primary Image URL',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fields['latitude'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: fields['longitude'],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Longitude'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['active', 'inactive']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => status = v!),
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
              if (fields['name']!.text.trim().isEmpty || fields['area']!.text.trim().isEmpty) {
                return;
              }
              final lat = double.tryParse(fields['latitude']!.text);
              final lng = double.tryParse(fields['longitude']!.text);
              final tags = fields['tags']!.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              if (tags.isEmpty) tags.add(category);

              final primaryImg = fields['imageUrl']!.text.trim();

              Navigator.pop(context, {
                'name': fields['name']!.text.trim(),
                'stateId': stateId,
                'stateName': stateName,
                'area': fields['area']!.text.trim(),
                'description': fields['description']!.text.trim(),
                'category': category,
                'interestTags': tags,
                'tags': tags,
                'score': double.tryParse(fields['score']!.text) ?? 4.8,
                'publicRating': double.tryParse(fields['score']!.text) ?? 4.8,
                'trustLabel': trust,
                'estimatedVisitMinutes': int.tryParse(fields['durationMinutes']!.text) ?? 60,
                'durationMinutes': int.tryParse(fields['durationMinutes']!.text) ?? 60,
                'primaryImageUrl': primaryImg,
                'imageUrl': primaryImg,
                'imageUrls': primaryImg.isNotEmpty ? [primaryImg] : [],
                'budgetLevel': budgetLevel,
                'estimatedBudget': budgetLevel,
                'openingHours': fields['openingHours']!.text.trim(),
                'location': lat == null || lng == null ? null : GeoPoint(lat, lng),
                'status': status,
                'isActive': status == 'active',
                'isVerified': true,
              });
            },
            child: const Text('Save Place'),
          ),
        ],
      );
}
