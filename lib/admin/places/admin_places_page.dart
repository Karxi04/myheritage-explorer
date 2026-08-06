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
              subtitle: 'Maintain destinations used by the Daily Planner.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
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
                    return const ExplorerEmptyState(
                      title: 'No places found',
                      subtitle: 'Add a place to make it available to travelers.',
                      icon: Icons.place_outlined,
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
                      return ExplorerCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (data['imageUrl'] ?? '').toString().isNotEmpty
                                  ? Image.network(
                                      '${data['imageUrl']}',
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
                                    '${data['category'] ?? '-'} • ${data['area'] ?? '-'}',
                                    style: const TextStyle(
                                      color: ExplorerColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 5,
                                    children: [
                                      ExplorerStatusBadge(
                                        label: '${data['trustLabel'] ?? 'NOT RATED'}'.toUpperCase(),
                                        tone: data['trustLabel'] == 'High Trust'
                                            ? ExplorerStatusTone.success
                                            : ExplorerStatusTone.warning,
                                      ),
                                      ExplorerStatusBadge(
                                        label: '${data['score'] ?? '-'} SCORE',
                                        tone: ExplorerStatusTone.navy,
                                      ),
                                      ExplorerStatusBadge(
                                        label: '${data['durationMinutes'] ?? 60} MIN',
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
                                } else {
                                  await doc.reference.update({
                                    'status': value,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });
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
        child: const Icon(
          Icons.account_balance_outlined,
          color: ExplorerColors.navy,
          size: 38,
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
  String category = 'Heritage';
  String trust = 'High Trust';
  String status = 'active';

  @override
  void initState() {
    super.initState();
    final data = widget.initial ?? {};
    fields = {for (final key in ['name', 'description', 'area', 'score', 'durationMinutes', 'imageUrl', 'latitude', 'longitude', 'budgetLevel']) key: TextEditingController(text: '${data[key] ?? ''}')};
    category = data['category'] ?? 'Heritage';
    trust = data['trustLabel'] ?? 'High Trust';
    status = data['status'] ?? 'active';
    final geo = data['location'];
    if (geo is GeoPoint) { fields['latitude']!.text = '${geo.latitude}'; fields['longitude']!.text = '${geo.longitude}'; }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'Add Place' : 'Edit Place'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(children: [
              TextField(controller: fields['name'], decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: fields['description'], maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: TextField(controller: fields['area'], decoration: const InputDecoration(labelText: 'Area'))), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField(value: category, decoration: const InputDecoration(labelText: 'Category'), items: ['Heritage', 'Food', 'Culture', 'Nature', 'Local Business'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => category = v!)))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: TextField(controller: fields['score'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Score'))), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField(value: trust, decoration: const InputDecoration(labelText: 'Trust label'), items: ['High Trust', 'Medium Trust', 'Low Trust', 'Insufficient Data'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => trust = v!)))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: TextField(controller: fields['durationMinutes'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Visit duration (minutes)'))), const SizedBox(width: 10), Expanded(child: TextField(controller: fields['budgetLevel'], decoration: const InputDecoration(labelText: 'Budget level')))]),
              const SizedBox(height: 10),
              TextField(controller: fields['imageUrl'], decoration: const InputDecoration(labelText: 'Image URL')),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: TextField(controller: fields['latitude'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Latitude'))), const SizedBox(width: 10), Expanded(child: TextField(controller: fields['longitude'], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Longitude')))]),
              const SizedBox(height: 10),
              DropdownButtonFormField(value: status, decoration: const InputDecoration(labelText: 'Status'), items: ['active', 'inactive'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => status = v!)),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () {
          if (fields['name']!.text.trim().isEmpty || fields['area']!.text.trim().isEmpty) return;
          final lat = double.tryParse(fields['latitude']!.text);
          final lng = double.tryParse(fields['longitude']!.text);
          Navigator.pop(context, {
            'name': fields['name']!.text.trim(),
            'description': fields['description']!.text.trim(),
            'area': fields['area']!.text.trim(),
            'category': category,
            'tags': [category],
            'score': double.tryParse(fields['score']!.text) ?? 0,
            'trustLabel': trust,
            'durationMinutes': int.tryParse(fields['durationMinutes']!.text) ?? 60,
            'imageUrl': fields['imageUrl']!.text.trim(),
            'budgetLevel': fields['budgetLevel']!.text.trim().isEmpty ? 'Medium' : fields['budgetLevel']!.text.trim(),
            'location': lat == null || lng == null ? null : GeoPoint(lat, lng),
            'status': status,
          });
        }, child: const Text('Save'))],
      );
}

