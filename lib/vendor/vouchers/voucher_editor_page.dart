
part of '../vendor_pages.dart';

class VoucherEditorPage extends StatefulWidget {
  const VoucherEditorPage({
    super.key,
    this.voucherId,
    this.voucher,
  });

  final String? voucherId;
  final Map<String, dynamic>? voucher;

  @override
  State<VoucherEditorPage> createState() =>
      _VoucherEditorPageState();
}

class _VoucherEditorPageState extends State<VoucherEditorPage> {
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController terms;
  late final TextEditingController pointCost;
  late final TextEditingController inventory;
  late DateTime expiry;
  GeoPoint? voucherLocation;
  double notificationRadiusMeters = 750.0;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final data = widget.voucher ?? {};
    title = TextEditingController(text: data['title'] ?? '');
    description =
        TextEditingController(text: data['description'] ?? '');
    terms = TextEditingController(text: data['terms'] ?? '');
    pointCost =
        TextEditingController(text: '${data['pointCost'] ?? 200}');
    inventory = TextEditingController(
      text: '${data['inventoryLimit'] ?? 50}',
    );
    expiry = asDate(data['expiresAt']) ??
        DateTime.now().add(const Duration(days: 30));
    voucherLocation = data['location'] is GeoPoint
        ? data['location'] as GeoPoint
        : null;
    notificationRadiusMeters =
        ((data['notificationRadiusMeters'] ?? 750.0) as num)
            .toDouble();
  }

  Future<void> save() async {
    final cost = int.tryParse(pointCost.text);
    final limit = int.tryParse(inventory.text);

    if (title.text.trim().isEmpty ||
        description.text.trim().isEmpty ||
        cost == null ||
        cost <= 0 ||
        limit == null ||
        limit <= 0 ||
        expiry.isBefore(DateTime.now())) {
      showMessage(
        context,
        'Enter valid voucher details, point cost, inventory and expiry date.',
        error: true,
      );
      return;
    }

    setState(() => busy = true);

    try {
      final data = {
        'vendorId': AppServices.auth.currentUser!.uid,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'terms': terms.text.trim(),
        'pointCost': cost,
        'inventoryLimit': limit,
        'expiresAt': Timestamp.fromDate(expiry),
        if (voucherLocation != null) 'location': voucherLocation,
        'notificationRadiusMeters': notificationRadiusMeters,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.voucherId == null) {
        await AppServices.db.collection('vouchers').add({
          ...data,
          'inventoryRemaining': limit,
          'claimCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final alreadyUsed =
            ((widget.voucher?['inventoryLimit'] ?? limit) as num) -
                ((widget.voucher?['inventoryRemaining'] ?? limit)
                    as num);
        await AppServices.db
            .collection('vouchers')
            .doc(widget.voucherId)
            .update({
          ...data,
          'inventoryRemaining':
              max(0, limit - alreadyUsed.toInt()),
        });
      }

      if (mounted) {
        showMessage(context, 'Voucher published successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    terms.dispose();
    pointCost.dispose();
    inventory.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.voucherId != null;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: Text(editing ? 'Edit Voucher' : 'Create New Voucher'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        children: [
          ExplorerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExplorerSectionTitle(
                  editing ? 'Edit Voucher Details' : 'Voucher Details',
                  subtitle:
                      'Create a clear and attractive reward for tourists.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Voucher Title',
                    hintText: 'e.g. RM5 Off Nyonya Kuih',
                  ),
                ),
                const SizedBox(height: 13),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText:
                        'Explain the reward and where it can be used.',
                  ),
                ),
                const SizedBox(height: 13),
                TextField(
                  controller: terms,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Terms and Conditions',
                    hintText:
                        'Minimum spending, redemption limits and exclusions.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ExplorerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExplorerSectionTitle('Reward Configuration'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pointCost,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Point Cost',
                          prefixIcon:
                              Icon(Icons.workspace_premium_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: inventory,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Inventory Limit',
                          prefixIcon:
                              Icon(Icons.inventory_2_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                DropdownButtonFormField<double>(
                  value: notificationRadiusMeters,
                  decoration: const InputDecoration(
                    labelText: 'Nearby Reward Radius',
                    prefixIcon: Icon(Icons.radar),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 250.0,
                      child: Text('250 metres'),
                    ),
                    DropdownMenuItem(
                      value: 500.0,
                      child: Text('500 metres'),
                    ),
                    DropdownMenuItem(
                      value: 750.0,
                      child: Text('750 metres'),
                    ),
                    DropdownMenuItem(
                      value: 1000.0,
                      child: Text('1 kilometre'),
                    ),
                    DropdownMenuItem(
                      value: 2000.0,
                      child: Text('2 kilometres'),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => notificationRadiusMeters =
                        value ?? notificationRadiusMeters,
                  ),
                ),
                const SizedBox(height: 13),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 730),
                      ),
                      initialDate: expiry,
                    );
                    if (picked != null) {
                      setState(() => expiry = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expiration Date',
                      prefixIcon:
                          Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      DateFormat.yMMMd().format(expiry),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final position = await determinePosition();
                      setState(
                        () => voucherLocation = GeoPoint(
                          position.latitude,
                          position.longitude,
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        showMessage(
                          context,
                          e.toString(),
                          error: true,
                        );
                      }
                    }
                  },
                  icon: Icon(
                    voucherLocation == null
                        ? Icons.my_location
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    voucherLocation == null
                        ? 'Use Current Shop Location'
                        : 'Shop Location Captured',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: busy ? null : save,
            child: Text(
              busy
                  ? 'Saving...'
                  : editing
                      ? 'Update Voucher'
                      : 'Publish Voucher',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
