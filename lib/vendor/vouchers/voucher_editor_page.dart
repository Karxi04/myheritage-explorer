part of '../vendor_pages.dart';

class VoucherEditorPage extends StatefulWidget {
  const VoucherEditorPage({super.key, this.voucherId, this.voucher});

  final String? voucherId;
  final Map<String, dynamic>? voucher;

  @override
  State<VoucherEditorPage> createState() => _VoucherEditorPageState();
}

class _VoucherEditorPageState extends State<VoucherEditorPage> {
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController terms;
  late final TextEditingController pointCost;
  late final TextEditingController inventory;
  late final TextEditingController claimLimit;
  late DateTime startsAt;
  late DateTime expiry;
  GeoPoint? voucherLocation;
  double notificationRadiusMeters = 750.0;
  bool unlimitedClaimsPerTourist = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();

    final data = widget.voucher ?? {};

    title = TextEditingController(text: '${data['title'] ?? ''}');
    description = TextEditingController(text: '${data['description'] ?? ''}');
    terms = TextEditingController(text: '${data['terms'] ?? ''}');
    pointCost = TextEditingController(text: '${data['pointCost'] ?? 200}');
    inventory = TextEditingController(text: '${data['inventoryLimit'] ?? 50}');
    final savedClaimLimit =
        (data['perTouristClaimLimit'] as num?)?.toInt() ?? 0;
    unlimitedClaimsPerTourist = savedClaimLimit <= 0;
    claimLimit = TextEditingController(
      text: savedClaimLimit > 0 ? '$savedClaimLimit' : '1',
    );
    startsAt =
        asDate(data['startsAt']) ??
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    expiry =
        asDate(data['expiresAt']) ??
        _endOfDay(DateTime.now().add(const Duration(days: 30)));
    voucherLocation = data['location'] is GeoPoint
        ? data['location'] as GeoPoint
        : null;
    notificationRadiusMeters =
        ((data['notificationRadiusMeters'] ?? 750.0) as num).toDouble();
  }

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59);

  Future<void> save() async {
    final cost = int.tryParse(pointCost.text);
    final limit = int.tryParse(inventory.text);
    final selectedClaimLimit = unlimitedClaimsPerTourist
        ? 0
        : int.tryParse(claimLimit.text);
    final normalizedExpiry = _endOfDay(expiry);
    final normalizedStart = DateTime(
      startsAt.year,
      startsAt.month,
      startsAt.day,
    );

    if (title.text.trim().isEmpty ||
        description.text.trim().isEmpty ||
        cost == null ||
        cost <= 0 ||
        limit == null ||
        limit <= 0 ||
        selectedClaimLimit == null ||
        selectedClaimLimit < 0 ||
        (!unlimitedClaimsPerTourist && selectedClaimLimit == 0) ||
        !normalizedStart.isBefore(normalizedExpiry) ||
        !normalizedExpiry.isAfter(DateTime.now())) {
      showMessage(
        context,
        'Enter valid voucher details. Point cost and inventory must be greater than zero.',
        error: true,
      );
      return;
    }

    setState(() => busy = true);

    try {
      final vendorId = AppServices.auth.currentUser!.uid;
      final vendorProfile =
          (await AppServices.vendorRef(vendorId).get()).data() ??
          const <String, dynamic>{};

      if (vendorProfile['role'] != 'vendor') {
        throw Exception('Vendor profile was not found.');
      }
      if (vendorProfile['status'] != 'active' ||
          vendorProfile['vendorStatus'] != 'verified') {
        throw Exception(
          'Only active, verified vendors can publish or edit vouchers.',
        );
      }

      final profileLocation = vendorProfile['location'];
      if (voucherLocation == null && profileLocation is GeoPoint) {
        voucherLocation = profileLocation;
      }
      if (voucherLocation == null) {
        throw Exception(
          'Set a shop location so tourists can receive nearby reward alerts.',
        );
      }

      final previousLimit =
          (widget.voucher?['inventoryLimit'] as num?)?.toInt() ?? limit;
      final previousRemaining =
          (widget.voucher?['inventoryRemaining'] as num?)?.toInt() ?? limit;
      final alreadyUsed = max(0, previousLimit - previousRemaining);
      if (widget.voucherId != null && limit < alreadyUsed) {
        throw Exception(
          'Inventory cannot be lower than the $alreadyUsed vouchers already claimed.',
        );
      }

      final data = {
        'vendorId': vendorId,
        'vendorName':
            '${vendorProfile['businessName'] ?? vendorProfile['displayName'] ?? 'Vendor'}',
        'vendorCategory': '${vendorProfile['businessCategory'] ?? ''}',
        'vendorAddress': '${vendorProfile['shopLocation'] ?? ''}',
        'title': title.text.trim(),
        'description': description.text.trim(),
        'terms': terms.text.trim(),
        'pointCost': cost,
        'inventoryLimit': limit,
        'startsAt': Timestamp.fromDate(normalizedStart),
        'perTouristClaimLimit': selectedClaimLimit,
        'expiresAt': Timestamp.fromDate(normalizedExpiry),
        if (voucherLocation != null) 'location': voucherLocation,
        'notificationRadiusMeters': notificationRadiusMeters,
        'status': widget.voucherId == null
            ? 'active'
            : '${widget.voucher?['status'] ?? 'active'}',
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
        await AppServices.db
            .collection('vouchers')
            .doc(widget.voucherId)
            .update({
              ...data,
              'inventoryRemaining': max(0, limit - alreadyUsed),
            });
      }

      if (!mounted) return;
      showMessage(
        context,
        widget.voucherId == null
            ? 'Voucher published successfully.'
            : 'Voucher updated successfully.',
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
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
    claimLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.voucherId == null ? 'Create New Voucher' : 'Edit Voucher',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Voucher title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: terms,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Terms and conditions'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pointCost,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Point cost',
            helperText:
                'Must be greater than zero. Travelers need this many approved-task points.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: inventory,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Inventory limit'),
        ),
        const SizedBox(height: 12),
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
            } catch (error) {
              if (context.mounted) {
                showMessage(context, error.toString(), error: true);
              }
            }
          },
          icon: const Icon(Icons.my_location),
          label: Text(
            voucherLocation == null
                ? 'Use current shop location'
                : 'Shop location captured',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<double>(
          initialValue: notificationRadiusMeters,
          decoration: const InputDecoration(labelText: 'Nearby reward radius'),
          items: const [
            DropdownMenuItem(value: 250.0, child: Text('250 metres')),
            DropdownMenuItem(value: 500.0, child: Text('500 metres')),
            DropdownMenuItem(value: 750.0, child: Text('750 metres')),
            DropdownMenuItem(value: 1000.0, child: Text('1 kilometre')),
            DropdownMenuItem(value: 2000.0, child: Text('2 kilometres')),
          ],
          onChanged: (value) =>
              setState(() => notificationRadiusMeters = value ?? 750.0),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: unlimitedClaimsPerTourist,
          onChanged: (value) =>
              setState(() => unlimitedClaimsPerTourist = value),
          title: const Text('Unlimited claims per tourist'),
          subtitle: const Text(
            'The voucher inventory still limits the total number available.',
          ),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        if (!unlimitedClaimsPerTourist) ...[
          const SizedBox(height: 12),
          TextField(
            controller: claimLimit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Claims allowed per tourist',
              helperText: 'Enter any whole number greater than zero.',
            ),
          ),
        ],
        const SizedBox(height: 12),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text('Available from'),
          subtitle: Text(DateFormat.yMMMd().format(startsAt)),
          trailing: const Icon(Icons.event_available_outlined),
          onTap: () async {
            final today = DateTime.now();
            final firstDate = DateTime(today.year, today.month, today.day);
            final picked = await showDatePicker(
              context: context,
              firstDate: firstDate,
              lastDate: DateTime.now().add(const Duration(days: 730)),
              initialDate: startsAt.isBefore(firstDate) ? firstDate : startsAt,
            );
            if (picked != null) setState(() => startsAt = picked);
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text('Expiration date'),
          subtitle: Text(DateFormat.yMMMd().format(expiry)),
          trailing: const Icon(Icons.calendar_month_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              initialDate: expiry,
            );

            if (picked != null) {
              setState(() => expiry = _endOfDay(picked));
            }
          },
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Saving...'
                : widget.voucherId == null
                ? 'Publish voucher'
                : 'Save changes',
          ),
        ),
      ],
    ),
  );
}
