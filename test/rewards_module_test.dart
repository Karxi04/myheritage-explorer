import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/services.dart';
import 'package:myheritage_explorer/rewards/reward_module_support.dart';

void main() {
  test('nearby rewards use one fair range and bounded reads', () {
    expect(AppServices.nearbyRewardRadiusMeters, 750);
    expect(AppServices.rewardPageReadLimit, 25);
    expect(AppServices.notificationReadLimit, 25);
    expect(AppServices.redemptionPinMatchReadLimit, 2);
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

  group('vendor interest distribution', () {
    test('normalizes tags and counts each tourist once per interest', () {
      final metric = calculateRewardInterestMetric([
        const RewardInterestRecord(
          audienceId: 'traveler-1',
          tags: ['Food', 'Culture', 'food', ''],
        ),
        const RewardInterestRecord(audienceId: 'traveler-1', tags: ['Nature']),
        const RewardInterestRecord(
          audienceId: 'traveler-2',
          tags: [' food ', 'Shopping', 'History', 'Art'],
        ),
        const RewardInterestRecord(audienceId: 'traveler-3', tags: null),
      ]);

      expect(metric.uniqueAudienceCount, 2);
      expect(metric.totalTagSelections, 7);
      expect(metric.segments, hasLength(4));
      expect(metric.segments.first.label, 'Food');
      expect(metric.segments.first.count, 2);
      expect(metric.segments.last.label, 'Other interests');
      expect(metric.segments.last.count, 3);
      expect(
        metric.segments.fold<double>(0, (total, item) => total + item.ratio),
        closeTo(1, 0.000001),
      );
    });

    test('returns an empty metric when redemptions have no usable tags', () {
      final metric = calculateRewardInterestMetric([
        const RewardInterestRecord(audienceId: 'traveler-1', tags: null),
        const RewardInterestRecord(audienceId: 'traveler-2', tags: ['', '  ']),
        const RewardInterestRecord(audienceId: 'traveler-3', tags: 'Food'),
      ]);

      expect(metric.segments, isEmpty);
      expect(metric.uniqueAudienceCount, 0);
      expect(metric.totalTagSelections, 0);
    });
  });

  group('voucher input validation', () {
    test('requires clear text fields and enforces safe lengths', () {
      expect(
        RewardInputValidation.voucherTitle('   '),
        'Enter a clear voucher title.',
      );
      expect(
        RewardInputValidation.voucherTitle(
          List.filled(
            RewardInputValidation.maximumVoucherTitleLength + 1,
            'x',
          ).join(),
        ),
        contains('characters or fewer'),
      );
      expect(RewardInputValidation.voucherTitle('Museum meal offer'), isNull);
      expect(
        RewardInputValidation.voucherDescription(''),
        contains('what the tourist will receive'),
      );
      expect(
        RewardInputValidation.voucherDescription(
          List.filled(
            RewardInputValidation.maximumVoucherDescriptionLength + 1,
            'x',
          ).join(),
        ),
        contains('description'),
      );
      expect(
        RewardInputValidation.voucherDescription('A complete description.'),
        isNull,
      );
      expect(
        RewardInputValidation.voucherTerms(
          List.filled(
            RewardInputValidation.maximumVoucherTermsLength + 1,
            'x',
          ).join(),
        ),
        contains('terms'),
      );
      expect(RewardInputValidation.voucherTerms('Optional terms'), isNull);
    });

    test('accepts only positive whole-number limits', () {
      expect(RewardInputValidation.pointCost(''), 'Enter the point cost.');
      expect(
        RewardInputValidation.pointCost('2.5'),
        'The point cost must be a whole number.',
      );
      expect(
        RewardInputValidation.pointCost('0'),
        'The point cost must be at least 1.',
      );
      expect(RewardInputValidation.pointCost('-1'), contains('at least 1'));
      expect(
        RewardInputValidation.pointCost(
          '${RewardInputValidation.maximumPointCost + 1}',
        ),
        contains('cannot be greater'),
      );
      expect(RewardInputValidation.pointCost('250'), isNull);
      expect(RewardInputValidation.inventory(''), 'Enter the total inventory.');
      expect(
        RewardInputValidation.inventory('10.5'),
        'The total inventory must be a whole number.',
      );
      expect(RewardInputValidation.inventory('-3'), contains('at least 1'));
      expect(
        RewardInputValidation.inventory(
          '${RewardInputValidation.maximumInventory + 1}',
        ),
        contains('cannot be greater'),
      );
      expect(RewardInputValidation.inventory('50'), isNull);
      expect(
        RewardInputValidation.claimLimit('', totalInventory: 10),
        'Enter the claims allowed per tourist.',
      );
      expect(
        RewardInputValidation.claimLimit('one', totalInventory: 10),
        'The claims allowed per tourist must be a whole number.',
      );
      expect(
        RewardInputValidation.claimLimit('0', totalInventory: 10),
        'The claims allowed per tourist must be at least 1.',
      );
      expect(
        RewardInputValidation.claimLimit('11', totalInventory: 10),
        'Claims per tourist cannot be greater than the total inventory of 10.',
      );
      expect(RewardInputValidation.claimLimit('2', totalInventory: 10), isNull);
      expect(
        RewardInputValidation.claimLimit('2', totalInventory: null),
        isNull,
      );
    });

    test('requires a future expiry after the start date', () {
      final now = DateTime(2026, 9, 10, 12);
      expect(
        RewardInputValidation.schedule(
          startsAt: DateTime(2026, 9, 10),
          expiresAt: DateTime(2026, 9, 10, 11),
          now: now,
        ),
        contains('still in the future'),
      );
      expect(
        RewardInputValidation.schedule(
          startsAt: DateTime(2026, 9, 12),
          expiresAt: DateTime(2026, 9, 11, 23),
          now: now,
        ),
        contains('after the voucher start date'),
      );
      expect(
        RewardInputValidation.schedule(
          startsAt: DateTime(2026, 9, 10),
          expiresAt: DateTime(2026, 9, 30, 23),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('redemption input validation', () {
    test('accepts a six-digit PIN and a complete app QR payload', () {
      expect(RewardInputValidation.redemptionCode('123456'), isNull);
      expect(RewardInputValidation.redemptionCode(' 123456 '), isNull);
      expect(
        RewardInputValidation.redemptionCode(
          'MHE1|claim-123|abcdefghijklmnopqrstuvwx1234',
        ),
        isNull,
      );
    });

    test('rejects empty, short and unrelated codes with clear messages', () {
      expect(
        RewardInputValidation.redemptionCode(''),
        contains('Scan the tourist\'s QR code'),
      );
      expect(
        RewardInputValidation.redemptionCode('12345'),
        'The redemption PIN must contain exactly 6 digits.',
      );
      expect(
        RewardInputValidation.redemptionCode('1234567'),
        'The redemption PIN must contain exactly 6 digits.',
      );
      expect(
        RewardInputValidation.redemptionCode('MHE1|claim-123|short'),
        contains('not a valid MyHeritage voucher code'),
      );
      expect(
        RewardInputValidation.redemptionCode('not-a-voucher'),
        contains('not a valid MyHeritage voucher code'),
      );
    });
  });

  group('reward error messages', () {
    test('turns Firebase errors into actionable language', () {
      expect(
        rewardModuleErrorMessage(
          Exception('[cloud_firestore/permission-denied] denied'),
        ),
        contains('correct traveler or vendor account'),
      );
      expect(
        rewardModuleErrorMessage(
          Exception('resource-exhausted: quota reached'),
        ),
        contains('request quota'),
      );
      expect(
        rewardModuleErrorMessage(Exception('network is unavailable')),
        contains('internet connection'),
      );
      expect(
        rewardModuleErrorMessage(Exception('deadline-exceeded timeout')),
        contains('too long to respond'),
      );
      expect(
        rewardModuleErrorMessage(Exception('unauthenticated session')),
        contains('Sign in again'),
      );
    });

    test('keeps already meaningful module messages', () {
      expect(
        rewardModuleErrorMessage(Exception('This voucher has expired.')),
        'This voucher has expired.',
      );
    });
  });
}
