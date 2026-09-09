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
  bool unlimitedClaimsPerTourist = true;
  bool locatingShop = false;
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
  }

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59);

  Future<void> _useCurrentShopLocation() async {
    if (locatingShop) return;
    setState(() => locatingShop = true);
    try {
      final position = await determinePosition();
      if (!mounted) return;
      setState(
        () => voucherLocation = GeoPoint(position.latitude, position.longitude),
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
      if (mounted) setState(() => locatingShop = false);
    }
  }

  Future<void> _chooseShopLocationOnMap() async {
    if (locatingShop) return;
    setState(() => locatingShop = true);

    var initialLocation = voucherLocation;
    if (initialLocation == null) {
      try {
        final position = await determinePosition();
        initialLocation = GeoPoint(position.latitude, position.longitude);
      } catch (_) {
        initialLocation = const GeoPoint(5.4141, 100.3288);
      }
    }

    if (!mounted) return;
    setState(() => locatingShop = false);
    final selected = await Navigator.push<GeoPoint>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _VoucherLocationPickerPage(initialLocation: initialLocation!),
      ),
    );
    if (selected != null && mounted) {
      setState(() => voucherLocation = selected);
    }
  }

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
        'notificationRadiusMeters': AppServices.nearbyRewardRadiusMeters,
        'nearbyLocationCell': AppServices.nearbyRewardLocationCell(
          voucherLocation!,
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        ExplorerCard(
          backgroundColor: ExplorerColors.navySoft,
          borderColor: const Color(0xFFC8D6EA),
          child: Row(
            children: [
              const Icon(
                Icons.tips_and_updates_outlined,
                color: ExplorerColors.navy,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.voucherId == null
                      ? 'Complete the sections below to publish a clear, discoverable reward.'
                      : 'Update the offer details. Existing claims will remain in tourist wallets.',
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const ExplorerSectionTitle(
          'Offer details',
          subtitle: 'Explain exactly what the tourist will receive.',
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 20),
        const ExplorerSectionTitle(
          'Cost and availability',
          subtitle: 'Set the point price and total number of vouchers.',
        ),
        const SizedBox(height: 10),
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
          decoration: const InputDecoration(
            labelText: 'Total voucher inventory',
            helperText: 'The maximum number of claims across all tourists.',
          ),
        ),
        const SizedBox(height: 20),
        const ExplorerSectionTitle(
          'Nearby discovery',
          subtitle:
              'Set the shop location used for nearby searches and alerts.',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locatingShop ? null : _useCurrentShopLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Use Current'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: locatingShop ? null : _chooseShopLocationOnMap,
                icon: locatingShop
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt_outlined),
                label: const Text('Pick on Map'),
              ),
            ),
          ],
        ),
        if (voucherLocation != null) ...[
          const SizedBox(height: 10),
          ExplorerCard(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            backgroundColor: ExplorerColors.successSoft,
            borderColor: const Color(0xFFB9E2D3),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white,
                  foregroundColor: ExplorerColors.success,
                  child: Icon(Icons.location_on_rounded, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shop location selected',
                        style: TextStyle(
                          color: ExplorerColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${voucherLocation!.latitude.toStringAsFixed(5)}, ${voucherLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: ExplorerColors.success),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const ExplorerCard(
          backgroundColor: ExplorerColors.navySoft,
          borderColor: Color(0xFFC8D6EA),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.balance_outlined, color: ExplorerColors.navy),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fixed nearby range: 750 metres',
                      style: TextStyle(
                        color: ExplorerColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'The same range applies to every vendor for fair discovery and reward alerts.',
                      style: TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const ExplorerSectionTitle(
          'Claim policy',
          subtitle: 'Control repeat claims by the same tourist.',
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 20),
        const ExplorerSectionTitle(
          'Publishing schedule',
          subtitle: 'Choose when tourists can start and stop claiming.',
        ),
        const SizedBox(height: 10),
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
        ElevatedButton.icon(
          onPressed: busy ? null : save,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  widget.voucherId == null
                      ? Icons.publish_outlined
                      : Icons.save_outlined,
                ),
          label: Text(
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

class _VoucherLocationPickerPage extends StatefulWidget {
  const _VoucherLocationPickerPage({required this.initialLocation});

  final GeoPoint initialLocation;

  @override
  State<_VoucherLocationPickerPage> createState() =>
      _VoucherLocationPickerPageState();
}

class _VoucherLocationPickerPageState
    extends State<_VoucherLocationPickerPage> {
  GoogleMapController? mapController;
  late LatLng selectedLocation;
  bool findingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    selectedLocation = LatLng(
      widget.initialLocation.latitude,
      widget.initialLocation.longitude,
    );
  }

  void _selectLocation(LatLng location) {
    setState(() => selectedLocation = location);
  }

  Future<void> _moveToCurrentLocation() async {
    if (findingCurrentLocation) return;
    setState(() => findingCurrentLocation = true);
    try {
      final position = await determinePosition();
      final location = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      _selectLocation(location);
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 17),
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
      if (mounted) setState(() => findingCurrentLocation = false);
    }
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      GeoPoint(selectedLocation.latitude, selectedLocation.longitude),
    );
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Pinpoint Shop Location')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: ExplorerCard(
                backgroundColor: ExplorerColors.navySoft,
                borderColor: Color(0xFFC8D6EA),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined, color: ExplorerColors.navy),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap anywhere on the map or drag the pin to the exact voucher redemption location.',
                        style: TextStyle(
                          color: ExplorerColors.navy,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: selectedLocation,
                      zoom: 16,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('voucher-shop-location'),
                        position: selectedLocation,
                        draggable: true,
                        onDragEnd: _selectLocation,
                        infoWindow: const InfoWindow(
                          title: 'Voucher redemption location',
                        ),
                      ),
                    },
                    compassEnabled: true,
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    onTap: _selectLocation,
                    onMapCreated: (controller) => mapController = controller,
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: FloatingActionButton.small(
                      heroTag: 'voucher-location-current',
                      tooltip: 'Move pin to my current location',
                      onPressed: findingCurrentLocation
                          ? null
                          : _moveToCurrentLocation,
                      child: findingCurrentLocation
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: ExplorerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected coordinates',
                      style: TextStyle(
                        color: ExplorerColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _confirmLocation,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Use This Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
