import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/services/safety_alert_priority_service.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';

void main() {
  const service = SafetyAlertPriorityService();
  SafetyAlertCandidate candidate(
    String id,
    String severity,
    double distance, {
    String status = 'Verified',
    double? community,
  }) {
    final report = HazardReport(
      id: id,
      userId: 'u',
      category: 'Flooding',
      severity: severity,
      description: 'Water',
      latitude: 5,
      longitude: 100,
      status: status,
    );
    return SafetyAlertCandidate(
      report: report,
      distanceMeters: distance,
      priority: service.calculate(
        severity: severity,
        distanceMeters: distance,
        existsConfirmationScore: community,
      ),
    );
  }

  test('highest priority wins even when a lower severity hazard is closer', () {
    final selected = service.selectAlert(
      [candidate('low', 'Low', 10), candidate('high', 'High', 50)],
      lastAlertedAt: {},
      lastPriority: {},
    );
    expect(selected!.report.id, 'high');
  });
  test('cooling nearest hazard does not mask another eligible hazard', () {
    final now = DateTime(2026, 9, 5);
    final selected = service.selectAlert(
      [candidate('near', 'High', 10), candidate('next', 'Medium', 100)],
      lastAlertedAt: {'near': now},
      lastPriority: {'near': 1},
      now: now,
    );
    expect(selected!.report.id, 'next');
  });
  test(
    'cooldown allows material priority escalation but suppresses repeats',
    () {
      final now = DateTime(2026, 9, 5),
          c = candidate('r', 'High', 50, community: 1);
      expect(
        service.selectAlert(
          [c],
          lastAlertedAt: {'r': now},
          lastPriority: {'r': .4},
          now: now,
        ),
        c,
      );
      expect(
        service.selectAlert(
          [c],
          lastAlertedAt: {'r': now},
          lastPriority: {'r': c.priority.priorityScore},
          now: now,
        ),
        isNull,
      );
      expect(
        service.selectAlert(
          [c],
          lastAlertedAt: {'r': now.subtract(const Duration(minutes: 30))},
          lastPriority: {'r': c.priority.priorityScore},
          now: now,
        ),
        c,
      );
    },
  );
  test('resolved hazards and Low severity at 450m never alert', () {
    expect(
      service.selectAlert(
        [
          candidate('r', 'High', 50, status: 'Resolved'),
          candidate('low', 'Low', 450),
        ],
        lastAlertedAt: {},
        lastPriority: {},
      ),
      isNull,
    );
  });
  test('unknown community is neutral and invalid distance is rejected', () {
    expect(
      service.calculate(severity: 'High', distanceMeters: 50).communityScore,
      .5,
    );
    expect(
      () => service.calculate(severity: 'High', distanceMeters: double.nan),
      throwsArgumentError,
    );
  });
  test('nearby high hazard with exists evidence is critical', () {
    final result = service.calculate(
      severity: 'High',
      distanceMeters: 50,
      existsConfirmationScore: 1,
    );
    expect(result.priorityLevel, 'CRITICAL');
  });
  test('distant low hazard with little evidence is low', () {
    final result = service.calculate(
      severity: 'Low',
      distanceMeters: 480,
      existsConfirmationScore: 0,
    );
    expect(result.priorityLevel, 'LOW');
  });
}
