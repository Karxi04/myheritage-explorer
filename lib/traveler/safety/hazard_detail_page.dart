part of '../traveler_pages.dart';

class HazardDetailPage extends StatefulWidget {
  const HazardDetailPage({
    super.key,
    required this.hazardId,
    this.showStatusHistory = false,
    this.reportService,
    this.locationService,
    this.geocodingService,
  });

  final String hazardId;
  final bool showStatusHistory;
  final HazardReportService? reportService;
  final LocationService? locationService;
  final PlaceGeocodingService? geocodingService;

  @override
  State<HazardDetailPage> createState() => _HazardDetailPageState();

  static ExplorerStatusTone _statusTone(String status) =>
      _HazardDetailPageState._statusTone(status);
}

class _HazardDetailPageState extends State<HazardDetailPage> {
  late final reportService = widget.reportService ?? HazardReportService();
  late final locationService =
      widget.locationService ?? const LocationService();
  late Stream<HazardReport?> _stream;
  Position? _currentPosition;
  bool _locationUnavailable = false;
  HazardAddressDetails? _addressDetails;
  String? _resolvedCoordinateKey;

  @override
  void initState() {
    super.initState();
    _stream = reportService.watchReport(widget.hazardId);
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final pos = await locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
        _locationUnavailable = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentPosition = null;
        _locationUnavailable = true;
      });
    }
  }

  void _maybeResolveAddress(double lat, double lon) {
    if (!SafetyConfig.validCoordinates(lat, lon)) return;
    final key = HazardAddressResolver.coordinateKey(lat, lon);
    if (_resolvedCoordinateKey == key) return;
    _resolvedCoordinateKey = key;
    HazardAddressResolver.resolve(
      latitude: lat,
      longitude: lon,
      geocodingService: widget.geocodingService,
    ).then((details) {
      if (mounted) {
        setState(() => _addressDetails = details);
      }
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m from your current location';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km from your current location';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Hazard Details')),
      body: SafeArea(
        child: StreamBuilder<HazardReport?>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SafetyErrorState(
                title: 'Unable to load hazard report',
                message: friendlySafetyError(
                  snapshot.error,
                  subject: 'this hazard report',
                ),
                onRetry: () => setState(
                  () => _stream = reportService.watchReport(widget.hazardId),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const SafetyLoadingState(label: 'Loading hazard details…');
            }

            final report = snapshot.data;
            if (report == null) {
              return Column(
                children: [
                  const Expanded(
                    child: ExplorerEmptyState(
                      title: 'Report not found',
                      subtitle: 'This hazard report may have been removed.',
                      icon: Icons.search_off_outlined,
                    ),
                  ),
                ],
              );
            }

            final isOwner = uid != null && report.userId == uid;
            final displayHistory = widget.showStatusHistory || isOwner;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    children: [
                      if (report.hasPhoto)
                        ExplorerCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: HazardEvidenceImage(
                              report: report,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                              placeholderBuilder: (_) => Container(
                                height: 180,
                                color: ExplorerColors.subtle,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: ExplorerColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (report.hasPhoto) const SizedBox(height: 12),
                      ExplorerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.category,
                                    style: const TextStyle(
                                      color: ExplorerColors.navy,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                ExplorerStatusBadge(
                                  label: report.status.toUpperCase(),
                                  tone: _statusTone(report.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ExplorerStatusBadge(
                                  label: report.severity.toUpperCase(),
                                  tone: report.severity == 'High'
                                      ? ExplorerStatusTone.danger
                                      : report.severity == 'Medium'
                                      ? ExplorerStatusTone.warning
                                      : ExplorerStatusTone.success,
                                ),
                                if (report.createdAt != null)
                                  _DetailChip(
                                    icon: Icons.schedule_outlined,
                                    label: DateFormat.yMMMd().add_jm().format(
                                      report.createdAt!,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExplorerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExplorerSectionTitle('Description'),
                            const SizedBox(height: 8),
                            Text(
                              report.description.isEmpty
                                  ? 'No description provided.'
                                  : report.description,
                              style: const TextStyle(
                                color: ExplorerColors.text,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExplorerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExplorerSectionTitle('Location'),
                            const SizedBox(height: 10),
                            if (report.hasValidLocation) ...[
                              Builder(
                                builder: (context) {
                                  _maybeResolveAddress(
                                    report.latitude,
                                    report.longitude,
                                  );
                                  final addressDetails =
                                      _addressDetails ??
                                      HazardAddressDetails.fromCoordinates(
                                        report.latitude,
                                        report.longitude,
                                      );
                                  final hazardLatLng = latlng.LatLng(
                                    report.latitude,
                                    report.longitude,
                                  );
                                  final userLatLng = _currentPosition != null
                                      ? latlng.LatLng(
                                          _currentPosition!.latitude,
                                          _currentPosition!.longitude,
                                        )
                                      : null;
                                  final distanceText = userLatLng != null
                                      ? _formatDistance(
                                          locationService.distanceBetween(
                                            startLatitude: userLatLng.latitude,
                                            startLongitude:
                                                userLatLng.longitude,
                                            endLatitude: report.latitude,
                                            endLongitude: report.longitude,
                                          ),
                                        )
                                      : null;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: ExplorerColors.navy
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.location_on,
                                              size: 18,
                                              color: ExplorerColors.navy,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  addressDetails.primaryName,
                                                  style: const TextStyle(
                                                    color: ExplorerColors.navy,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if (addressDetails
                                                            .secondaryAddress !=
                                                        null &&
                                                    addressDetails
                                                        .secondaryAddress!
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    addressDetails
                                                        .secondaryAddress!,
                                                    style: const TextStyle(
                                                      color:
                                                          ExplorerColors.muted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 3),
                                                Text(
                                                  addressDetails
                                                      .coordinatesText,
                                                  style: const TextStyle(
                                                    color: ExplorerColors.muted,
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 180,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: IgnorePointer(
                                            child: fm.FlutterMap(
                                              options: fm.MapOptions(
                                                initialCenter: hazardLatLng,
                                                initialZoom: 15,
                                                initialCameraFit:
                                                    userLatLng != null
                                                    ? fm.CameraFit.bounds(
                                                        bounds:
                                                            fm.LatLngBounds.fromPoints(
                                                              [
                                                                hazardLatLng,
                                                                userLatLng,
                                                              ],
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              32,
                                                            ),
                                                        maxZoom: 16,
                                                        minZoom: 10,
                                                      )
                                                    : null,
                                                interactionOptions:
                                                    const fm.InteractionOptions(
                                                      flags: fm
                                                          .InteractiveFlag
                                                          .none,
                                                    ),
                                              ),
                                              children: [
                                                fm.TileLayer(
                                                  urlTemplate: HazardMapService
                                                      .osmTileUrl,
                                                  userAgentPackageName:
                                                      'com.myheritage.explorer',
                                                ),
                                                fm.CircleLayer(
                                                  circles: [
                                                    fm.CircleMarker(
                                                      point: hazardLatLng,
                                                      radius:
                                                          SafetyConfig.dangerRadiusForSeverity(
                                                            report.severity,
                                                          ),
                                                      useRadiusInMeter: true,
                                                      color:
                                                          HazardMapService.severityColor(
                                                            report.severity,
                                                          ).withValues(
                                                            alpha: .14,
                                                          ),
                                                      borderColor:
                                                          HazardMapService.severityColor(
                                                            report.severity,
                                                          ).withValues(
                                                            alpha: .78,
                                                          ),
                                                      borderStrokeWidth: 2,
                                                    ),
                                                  ],
                                                ),
                                                fm.MarkerLayer(
                                                  markers: [
                                                    fm.Marker(
                                                      key: const ValueKey(
                                                        'hazard_map_marker',
                                                      ),
                                                      point: hazardLatLng,
                                                      width: 38,
                                                      height: 38,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color:
                                                              HazardMapService.severityColor(
                                                                report.severity,
                                                              ),
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors.white,
                                                            width: 2,
                                                          ),
                                                          boxShadow: const [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black26,
                                                              blurRadius: 4,
                                                              offset: Offset(
                                                                0,
                                                                2,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons
                                                                .warning_amber_rounded,
                                                            color: Colors.white,
                                                            size: 20,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (userLatLng != null)
                                                      fm.Marker(
                                                        key: const ValueKey(
                                                          'user_location_marker',
                                                        ),
                                                        point: userLatLng,
                                                        width: 32,
                                                        height: 32,
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFF1A73E8,
                                                            ),
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color:
                                                                  Colors.white,
                                                              width: 2.5,
                                                            ),
                                                            boxShadow: const [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black26,
                                                                blurRadius: 4,
                                                                offset: Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons.person,
                                                              color:
                                                                  Colors.white,
                                                              size: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const fm.RichAttributionWidget(
                                                  alignment: fm
                                                      .AttributionAlignment
                                                      .bottomLeft,
                                                  showFlutterMapAttribution:
                                                      false,
                                                  attributions: [
                                                    fm.TextSourceAttribution(
                                                      'OpenStreetMap contributors',
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 9,
                                                height: 9,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF1A73E8),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'You',
                                                style: TextStyle(
                                                  color: ExplorerColors.navy,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                size: 13,
                                                color:
                                                    HazardMapService.severityColor(
                                                      report.severity,
                                                    ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'Hazard',
                                                style: TextStyle(
                                                  color: ExplorerColors.navy,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          if (_locationUnavailable)
                                            const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.location_off_outlined,
                                                  size: 12,
                                                  color: ExplorerColors.muted,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Current location unavailable',
                                                  style: TextStyle(
                                                    color: ExplorerColors.muted,
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      if (distanceText != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.near_me_outlined,
                                              size: 14,
                                              color: ExplorerColors.navy,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                distanceText,
                                                style: const TextStyle(
                                                  color: ExplorerColors.navy,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: ExplorerColors.muted,
                                          ),
                                          SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              'Approximate report location',
                                              style: TextStyle(
                                                color: ExplorerColors.muted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ] else ...[
                              Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: ExplorerColors.subtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ExplorerColors.border,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_off_outlined,
                                      size: 32,
                                      color: ExplorerColors.muted,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Location unavailable',
                                      style: TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (displayHistory) ...[
                        const SizedBox(height: 12),
                        _StatusHistorySection(report: report),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static ExplorerStatusTone _statusTone(String status) => switch (status) {
    HazardReportStatus.verified ||
    HazardReportStatus.resolved => ExplorerStatusTone.success,
    HazardReportStatus.rejected => ExplorerStatusTone.danger,
    _ => ExplorerStatusTone.warning,
  };
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ExplorerColors.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: ExplorerColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StatusHistorySection extends StatelessWidget {
  const _StatusHistorySection({required this.report});

  final HazardReport report;

  @override
  Widget build(BuildContext context) {
    final entries = report.statusHistory.isEmpty
        ? [
            HazardStatusHistoryEntry(
              status: report.status,
              note: 'Current status',
            ),
          ]
        : report.statusHistory;

    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle('Status History'),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == entries.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: ExplorerColors.navy,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 36,
                        color: ExplorerColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ExplorerStatusBadge(
                              label: item.status.toUpperCase(),
                              tone: HazardDetailPage._statusTone(item.status),
                            ),
                            if (item.changedAt != null)
                              Text(
                                DateFormat.yMMMd().add_jm().format(
                                  item.changedAt!,
                                ),
                                style: const TextStyle(
                                  color: ExplorerColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                        if ((item.note ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.note!,
                            style: const TextStyle(
                              color: ExplorerColors.text,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
