import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/explorer_ui.dart';
import '../core/safety_config.dart';
import '../models/hazard_report.dart';

class HazardMapService {
  const HazardMapService();

  static const defaultCenter = LatLng(5.4141, 100.3288);
  static const defaultZoom = 13.0;

  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  List<CircleMarker> buildDangerZoneCircles({
    required List<HazardReport> reports,
  }) {
    return reports.map((report) {
      final color = severityColor(report.severity);
      return CircleMarker(
        point: LatLng(report.latitude, report.longitude),
        radius: SafetyConfig.dangerRadiusForSeverity(report.severity),
        useRadiusInMeter: true,
        color: color.withValues(alpha: .14),
        borderColor: color.withValues(alpha: .78),
        borderStrokeWidth: 2,
      );
    }).toList();
  }

  List<Marker> buildHazardMarkers({
    required List<HazardReport> reports,
    required void Function(HazardReport report) onTap,
  }) {
    return reports.map((report) {
      return Marker(
        point: LatLng(report.latitude, report.longitude),
        width: 52,
        height: 52,
        child: Tooltip(
          message:
              '${report.category} · ${report.severity}\nTap to view report',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(report),
            child: Center(
              child: Icon(
                Icons.location_on,
                color: severityColor(report.severity),
                size: 40,
                shadows: const [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Marker? buildUserMarker(LatLng? position) {
    if (position == null) return null;
    return Marker(
      point: position,
      width: 36,
      height: 36,
      child: Container(
        decoration: BoxDecoration(
          color: ExplorerColors.navy,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.person_pin_circle,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  static Color severityColor(String severity) {
    return switch (severity) {
      'High' => ExplorerColors.danger,
      'Medium' => ExplorerColors.warning,
      _ => ExplorerColors.success,
    };
  }
}
