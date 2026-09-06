import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/services/itinerary_safety_service.dart';

void main() {
  const service = ItinerarySafetyService();
  const stops = [
    {
      'name': 'Armenian Street',
      'location': {'latitude': 5.4141, 'longitude': 100.3288},
    },
  ];

  HazardReport hazard(
    String id, {
    String severity = 'Medium',
    String status = HazardReportStatus.verified,
    double latitudeOffset = .001,
  }) {
    return HazardReport(
      id: id,
      userId: 'traveler',
      category: 'Flooding',
      severity: severity,
      description: 'Water across the road',
      latitude: 5.4141 + latitudeOffset,
      longitude: 100.3288,
      status: status,
    );
  }

  test(
    'malformed coordinates and non-Verified statuses produce no warning',
    () {
      expect(
        service.checkStops(
          [
            {'latitude': 'bad', 'longitude': 100},
            {'latitude': double.nan, 'longitude': 100},
            {'latitude': 95, 'longitude': 100},
          ],
          [hazard('valid')],
        ),
        isEmpty,
      );
      for (final status in [
        'Pending Review',
        'Rejected',
        'Resolved',
        'verified',
      ]) {
        expect(
          service.checkStops(stops, [hazard('inactive', status: status)]),
          isEmpty,
        );
      }
    },
  );

  test('no nearby verified hazard produces no warning', () {
    final warnings = service.checkStops(stops, [
      hazard('far', latitudeOffset: .02),
    ]);

    expect(warnings, isEmpty);
  });

  test('nearby high-severity verified hazard produces warning', () {
    final warnings = service.checkStops(stops, [
      hazard('high', severity: 'High', latitudeOffset: .00162),
    ]);

    expect(warnings, hasLength(1));
    expect(warnings.single.distanceMeters, closeTo(180, 5));
  });

  test('resolved hazard disappears from active warnings', () {
    final warnings = service.checkStops(stops, [
      hazard('resolved', status: HazardReportStatus.resolved),
    ]);

    expect(warnings, isEmpty);
  });

  test('multiple hazards are returned with highest severity first', () {
    final warnings = service.checkStops(stops, [
      hazard('low', severity: 'Low', latitudeOffset: .0004),
      hazard('medium', latitudeOffset: .0008),
      hazard('high', severity: 'High', latitudeOffset: .0012),
    ]);

    expect(warnings, hasLength(3));
    expect(warnings.first.hazard.id, 'high');
  });
}
