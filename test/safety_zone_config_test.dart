import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myheritage_explorer/services/location_service.dart';
import 'package:myheritage_explorer/core/explorer_ui.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/services/hazard_map_service.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';

void main() {
  test('GPS fix must be fresh, accurate and geographically valid', () {
    final now = DateTime(2026, 9, 5, 12);
    Position fix({
      double accuracy = 10,
      double latitude = 5.4,
      Duration age = Duration.zero,
    }) => Position(
      latitude: latitude,
      longitude: 100.3,
      timestamp: now.subtract(age),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    expect(LocationService.isUsablePosition(fix(), now: now), isTrue);
    expect(
      LocationService.isUsablePosition(fix(accuracy: 100), now: now),
      isTrue,
    );
    expect(
      LocationService.isUsablePosition(fix(accuracy: 101), now: now),
      isFalse,
    );
    expect(
      LocationService.isUsablePosition(fix(accuracy: double.nan), now: now),
      isFalse,
    );
    expect(
      LocationService.isUsablePosition(fix(latitude: 91), now: now),
      isFalse,
    );
    expect(
      LocationService.isUsablePosition(
        fix(age: const Duration(minutes: 2)),
        now: now,
      ),
      isTrue,
    );
    expect(
      LocationService.isUsablePosition(
        fix(age: const Duration(seconds: 121)),
        now: now,
      ),
      isFalse,
    );
    expect(
      LocationService.isUsablePosition(
        fix(age: const Duration(seconds: -6)),
        now: now,
      ),
      isFalse,
    );
  });
  test(
    'proximity boundaries exclude negative, nonfinite and outside values',
    () {
      for (final entry in <double, String>{
        70: 'STRONG',
        100: 'STRONG',
        250: 'NORMAL',
        300: 'NORMAL',
        450: 'WEAK',
        500: 'WEAK',
        500.01: 'OUTSIDE',
        800: 'OUTSIDE',
        -1: 'OUTSIDE',
      }.entries) {
        expect(SafetyConfig.proximityBand(entry.key), entry.value);
      }
      expect(SafetyConfig.proximityBand(double.nan), 'OUTSIDE');
      expect(SafetyConfig.proximityBand(double.infinity), 'OUTSIDE');
    },
  );
  test('map only includes unique Verified reports with valid coordinates', () {
    HazardReport report(String status, {String id = 'r', double lat = 5}) =>
        HazardReport(
          id: id,
          userId: 'u',
          category: 'Flooding',
          severity: 'High',
          description: 'Water',
          latitude: lat,
          longitude: 100,
          status: status,
        );
    final verified = report('Verified');
    final reports = [
      verified,
      verified,
      report('Pending Review'),
      report('Rejected'),
      report('Resolved'),
      report('verified'),
      report('Verified', id: 'bad', lat: double.nan),
    ];
    expect(HazardMapService.activeReports(reports), [verified]);
    expect(
      const HazardMapService().buildDangerZoneCircles(reports: reports),
      hasLength(1),
    );
    expect(
      const HazardMapService().buildHazardMarkers(
        reports: reports,
        onTap: (_) {},
      ),
      hasLength(1),
    );
  });
  test('missing coordinates do not become a real location at zero', () {
    expect(
      HazardReport.fromMap('missing', {'status': 'Verified'}).hasValidLocation,
      isFalse,
    );
    expect(
      HazardReport.fromMap('legacy', {'status': 'verified'}).isVerified,
      isFalse,
    );
  });

  test('danger-zone radii increase with severity', () {
    expect(SafetyConfig.dangerRadiusForSeverity('Low'), 150);
    expect(SafetyConfig.dangerRadiusForSeverity('Medium'), 300);
    expect(SafetyConfig.dangerRadiusForSeverity('High'), 500);
  });

  test('each severity has the intended map color', () {
    expect(HazardMapService.severityColor('Low'), ExplorerColors.success);
    expect(HazardMapService.severityColor('Medium'), ExplorerColors.warning);
    expect(HazardMapService.severityColor('High'), ExplorerColors.danger);
  });
}
