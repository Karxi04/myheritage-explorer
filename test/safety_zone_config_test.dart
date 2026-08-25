import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/explorer_ui.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/services/hazard_map_service.dart';

void main() {
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
