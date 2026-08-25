part of '../traveler_pages.dart';

class DangerZoneMapPage extends StatefulWidget {
  const DangerZoneMapPage({
    super.key,
    required this.reports,
    this.onReportSelected,
    this.height = 225,
  });

  final List<HazardReport> reports;
  final void Function(HazardReport report)? onReportSelected;
  final double height;

  @override
  State<DangerZoneMapPage> createState() => _DangerZoneMapPageState();
}

class _DangerZoneMapPageState extends State<DangerZoneMapPage> {
  final _mapController = fm.MapController();
  final _mapService = const HazardMapService();
  final _locationService = const LocationService();
  latlng.LatLng? _userPosition;
  bool _loadingLocation = true;
  String? _locationError;
  bool _tileLoadFailed = false;

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
      _mapController.move(_userPosition!, 14);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationError = error.toString().replaceFirst('Exception: ', '');
      });
    }
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
      reports: widget.reports,
      onTap: (report) => widget.onReportSelected?.call(report),
    );
    final dangerZoneCircles = _mapService.buildDangerZoneCircles(
      reports: widget.reports,
    );
    final userMarker = _mapService.buildUserMarker(_userPosition);
    final markers = [...hazardMarkers, ?userMarker];

    final center =
        _userPosition ??
        (widget.reports.isNotEmpty
            ? latlng.LatLng(
                widget.reports.first.latitude,
                widget.reports.first.longitude,
              )
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
                  initialZoom: HazardMapService.defaultZoom,
                  interactionOptions: const fm.InteractionOptions(
                    flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  fm.TileLayer(
                    urlTemplate: HazardMapService.osmTileUrl,
                    userAgentPackageName: 'com.myheritage.explorer',
                    errorTileCallback: _onTileError,
                  ),
                  fm.CircleLayer(circles: dangerZoneCircles),
                  fm.MarkerLayer(markers: markers),
                ],
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
          if (widget.reports.isNotEmpty)
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
            const Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: _MapMessage(
                icon: Icons.cloud_off_outlined,
                text:
                    'Some map tiles could not be loaded. Check your connection.',
              ),
            )
          else if (widget.reports.isEmpty)
            const Positioned(
              bottom: 10,
              left: 10,
              right: 10,
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
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DangerZoneLegendItem(
              color: ExplorerColors.success,
              label: 'Low · 150 m',
            ),
            SizedBox(height: 4),
            _DangerZoneLegendItem(
              color: ExplorerColors.warning,
              label: 'Medium · 300 m',
            ),
            SizedBox(height: 4),
            _DangerZoneLegendItem(
              color: ExplorerColors.danger,
              label: 'High · 500 m',
            ),
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
          width: 9,
          height: 9,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: ExplorerColors.navy),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(width: 6),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
