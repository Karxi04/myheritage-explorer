import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/services.dart';

void main() {
  test('nearby rewards use one fair range and bounded reads', () {
    expect(AppServices.nearbyRewardRadiusMeters, 750);
    expect(AppServices.rewardPageReadLimit, 25);
    expect(AppServices.nearbyRewardCandidateReadLimit, 25);
    expect(AppServices.nearbyRewardCheckCooldown, const Duration(minutes: 10));
    expect(AppServices.nearbyRewardAlertCooldown, const Duration(hours: 6));
    expect(
      AppServices.repeatedNearbyRewardAlertCooldown,
      const Duration(hours: 24),
    );
  });

  test('nearby reward location cells group close vendor locations', () {
    final first = AppServices.nearbyRewardLocationCell(
      const GeoPoint(1.3521, 103.8198),
    );
    final second = AppServices.nearbyRewardLocationCell(
      const GeoPoint(1.3525, 103.8192),
    );

    expect(first, second);
  });
}
