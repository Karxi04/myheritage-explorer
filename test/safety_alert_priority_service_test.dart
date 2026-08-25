import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/services/safety_alert_priority_service.dart';

void main() {
  const service = SafetyAlertPriorityService();
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
