part of '../traveler_pages.dart';

class DangerZoneMapPage extends StatefulWidget {
  const DangerZoneMapPage({
    super.key,
    required this.reports,
    this.onReportSelected,
    this.height = 225,
    this.locationService,
  });

  final List<HazardReport> reports;
  final void Function(HazardReport report)? onReportSelected;
  final double height;
  final LocationService? locationService;

  @override
  State<DangerZoneMapPage> createState() => _DangerZoneMapPageState();
}

class _DangerZoneMapPageState extends State<DangerZoneMapPage> {
  final _mapController = fm.MapController();
  final _mapService = const HazardMapService();
  late final _locationService =
      widget.locationService ?? const LocationService();
  latlng.LatLng? _userPosition;
  bool _loadingLocation = true;
  String? _locationError;
  bool _tileLoadFailed = false;
  bool _mapReady = false;
  int _tileRevision = 0;

  @override
  void initState() {
    super.initState();
    _loadUserPosition();
  }

  Future<void> _loadUserPosition() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userPosition = latlng.LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
        _locationError = null;
      });
      if (_mapReady) _mapController.move(_userPosition!, 14);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationError = friendlySafetyActionError(
          error,
          fallback: 'Location is unavailable. You can still browse the map.',
        );
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onTileError(fm.TileImage tile, Object error, StackTrace? stackTrace) {
    if (_tileLoadFailed || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _tileLoadFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hazardMarkers = _mapService.buildHazardMarkers(
      reports: HazardMapService.activeReports(widget.reports),
      onTap: (report) => widget.onReportSelected?.call(report),
    );
    final dangerZoneCircles = _mapService.buildDangerZoneCircles(
      reports: widget.reports,
    );
    final userMarker = _mapService.buildUserMarker(_userPosition);
    final markers = [...hazardMarkers, ?userMarker];

    final active = HazardMapService.activeReports(widget.reports);
    final center =
        _userPosition ??
        (active.isNotEmpty
            ? latlng.LatLng(active.first.latitude, active.first.longitude)
            : HazardMapService.defaultCenter);

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: fm.FlutterMap(
                mapController: _mapController,
                options: fm.MapOptions(
                  initialCenter: center,
                  onMapReady: () {
                    _mapReady = true;
                    if (_userPosition != null) {
                      _mapController.move(_userPosition!, 14);
                    }
                  },
                  initialZoom: HazardMapService.defaultZoom,
                  interactionOptions: const fm.InteractionOptions(
                    flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  fm.TileLayer(
                    key: ValueKey(_tileRevision),
                    urlTemplate: HazardMapService.osmTileUrl,
                    userAgentPackageName: 'com.myheritage.explorer',
                    errorTileCallback: _onTileError,
                  ),
                  fm.CircleLayer(circles: dangerZoneCircles),
                  fm.MarkerLayer(markers: markers),
                  const fm.RichAttributionWidget(
                    alignment: fm.AttributionAlignment.bottomLeft,
                    showFlutterMapAttribution: false,
                    attributions: [
                      fm.TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Material(
              color: Colors.white,
              elevation: 2,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              child: IconButton(
                tooltip: 'Recenter on my location',
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                padding: EdgeInsets.zero,
                onPressed: _loadingLocation
                    ? null
                    : () {
                        setState(() => _loadingLocation = true);
                        _loadUserPosition();
                      },
                icon: const Icon(
                  Icons.my_location,
                  color: ExplorerColors.navy,
                  size: 20,
                ),
              ),
            ),
          ),
          if (_loadingLocation)
            const Positioned(
              top: 10,
              left: 10,
              child: _MapMessage(
                icon: Icons.my_location,
                text: 'Finding your location...',
              ),
            ),
          if (active.isNotEmpty && !_loadingLocation && _locationError == null)
            const Positioned(top: 10, right: 10, child: _DangerZoneLegend()),
          if (!_loadingLocation && _locationError != null)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: _MapMessage(
                icon: Icons.location_off_outlined,
                text: _locationError!,
                actionLabel: 'Retry',
                onAction: () {
                  setState(() {
                    _loadingLocation = true;
                    _locationError = null;
                  });
                  _loadUserPosition();
                },
              ),
            ),
          if (_tileLoadFailed)
            Positioned(
              top: 10,
              left: 10,
              right:
                  active.isNotEmpty &&
                      !_loadingLocation &&
                      _locationError == null
                  ? 76
                  : 10,
              child: _MapMessage(
                icon: Icons.cloud_off_outlined,
                text: 'Map tiles could not load.',
                actionLabel: 'Retry',
                onAction: () => setState(() {
                  _tileLoadFailed = false;
                  _tileRevision++;
                }),
              ),
            )
          else if (active.isEmpty &&
              !_loadingLocation &&
              _locationError == null)
            const Positioned(
              top: 10,
              left: 10,
              child: _MapMessage(
                icon: Icons.health_and_safety_outlined,
                text: 'No verified hazards are active right now.',
              ),
            ),
        ],
      ),
    );
  }
}

class _DangerZoneLegend extends StatelessWidget {
  const _DangerZoneLegend();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      shadowColor: Colors.black12,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DangerZoneLegendItem(color: ExplorerColors.success, label: 'Low'),
            SizedBox(height: 3),
            _DangerZoneLegendItem(
              color: ExplorerColors.warning,
              label: 'Medium',
            ),
            SizedBox(height: 3),
            _DangerZoneLegendItem(color: ExplorerColors.danger, label: 'High'),
          ],
        ),
      ),
    );
  }
}

class _DangerZoneLegendItem extends StatelessWidget {
  const _DangerZoneLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: ExplorerColors.navy,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: ExplorerColors.navy),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ExplorerColors.navy,
                ),
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ExplorerColors.navy,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
