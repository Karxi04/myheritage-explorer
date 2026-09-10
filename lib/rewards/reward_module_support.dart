class RewardInterestRecord {
  const RewardInterestRecord({required this.audienceId, required this.tags});

  final String audienceId;
  final Object? tags;
}

class RewardInterestSlice {
  const RewardInterestSlice({
    required this.label,
    required this.count,
    required this.ratio,
  });

  final String label;
  final int count;
  final double ratio;
}

class RewardInterestMetric {
  const RewardInterestMetric({
    required this.segments,
    required this.uniqueAudienceCount,
    required this.totalTagSelections,
  });

  final List<RewardInterestSlice> segments;
  final int uniqueAudienceCount;
  final int totalTagSelections;
}

RewardInterestMetric calculateRewardInterestMetric(
  Iterable<RewardInterestRecord> records, {
  int maximumSegments = 4,
}) {
  if (maximumSegments < 2) {
    throw ArgumentError.value(
      maximumSegments,
      'maximumSegments',
      'Use at least two segments so remaining interests can be grouped.',
    );
  }

  final tagsByAudience = <String, Map<String, String>>{};
  var anonymousRecordNumber = 0;

  for (final record in records) {
    final rawTags = record.tags;
    if (rawTags is! Iterable || rawTags is String) continue;

    final providedAudienceId = record.audienceId.trim();
    final audienceKey = providedAudienceId.isEmpty
        ? 'anonymous-${anonymousRecordNumber++}'
        : providedAudienceId;
    final normalizedTags = tagsByAudience.putIfAbsent(audienceKey, () => {});

    for (final rawTag in rawTags) {
      final label = '$rawTag'.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (label.isEmpty) continue;
      normalizedTags.putIfAbsent(label.toLowerCase(), () => label);
    }

    if (normalizedTags.isEmpty) tagsByAudience.remove(audienceKey);
  }

  final counts = <String, ({String label, int count})>{};
  for (final audienceTags in tagsByAudience.values) {
    for (final entry in audienceTags.entries) {
      final existing = counts[entry.key];
      counts[entry.key] = (
        label: existing?.label ?? entry.value,
        count: (existing?.count ?? 0) + 1,
      );
    }
  }

  final sorted = counts.values.toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0
          ? byCount
          : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  final totalSelections = sorted.fold<int>(
    0,
    (total, entry) => total + entry.count,
  );

  if (totalSelections == 0) {
    return const RewardInterestMetric(
      segments: [],
      uniqueAudienceCount: 0,
      totalTagSelections: 0,
    );
  }

  final visible = <({String label, int count})>[];
  if (sorted.length <= maximumSegments) {
    visible.addAll(sorted);
  } else {
    visible.addAll(sorted.take(maximumSegments - 1));
    visible.add((
      label: 'Other interests',
      count: sorted
          .skip(maximumSegments - 1)
          .fold<int>(0, (total, entry) => total + entry.count),
    ));
  }

  return RewardInterestMetric(
    segments: visible
        .map(
          (entry) => RewardInterestSlice(
            label: entry.label,
            count: entry.count,
            ratio: entry.count / totalSelections,
          ),
        )
        .toList(growable: false),
    uniqueAudienceCount: tagsByAudience.length,
    totalTagSelections: totalSelections,
  );
}

class RewardInputValidation {
  const RewardInputValidation._();

  static const int maximumVoucherTitleLength = 80;
  static const int maximumVoucherDescriptionLength = 500;
  static const int maximumVoucherTermsLength = 500;
  static const int maximumPointCost = 1000000;
  static const int maximumInventory = 100000;

  static String? voucherTitle(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a clear voucher title.';
    if (text.length > maximumVoucherTitleLength) {
      return 'Keep the voucher title to $maximumVoucherTitleLength characters or fewer.';
    }
    return null;
  }

  static String? voucherDescription(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Describe what the tourist will receive with this voucher.';
    }
    if (text.length > maximumVoucherDescriptionLength) {
      return 'Keep the description to $maximumVoucherDescriptionLength characters or fewer.';
    }
    return null;
  }

  static String? voucherTerms(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > maximumVoucherTermsLength) {
      return 'Keep the terms to $maximumVoucherTermsLength characters or fewer.';
    }
    return null;
  }

  static String? pointCost(String? value) => _positiveWholeNumber(
    value,
    fieldName: 'point cost',
    maximum: maximumPointCost,
  );

  static String? inventory(String? value) => _positiveWholeNumber(
    value,
    fieldName: 'total inventory',
    maximum: maximumInventory,
  );

  static String? claimLimit(String? value, {required int? totalInventory}) {
    final validation = _positiveWholeNumber(
      value,
      fieldName: 'claims allowed per tourist',
      maximum: maximumInventory,
    );
    if (validation != null) return validation;

    final parsed = int.parse(value!.trim());
    if (totalInventory != null &&
        totalInventory > 0 &&
        parsed > totalInventory) {
      return 'Claims per tourist cannot be greater than the total inventory of $totalInventory.';
    }
    return null;
  }

  static String? schedule({
    required DateTime startsAt,
    required DateTime expiresAt,
    required DateTime now,
  }) {
    if (!expiresAt.isAfter(now)) {
      return 'Choose an expiration date that is still in the future.';
    }
    if (!startsAt.isBefore(expiresAt)) {
      return 'The expiration date must be after the voucher start date.';
    }
    return null;
  }

  static String? redemptionCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) {
      return 'Scan the tourist\'s QR code or enter their 6-digit PIN.';
    }
    if (RegExp(r'^\d{6}$').hasMatch(code)) return null;

    final parts = code.split('|');
    if (parts.length == 3 &&
        parts.first == 'MHE1' &&
        parts[1].trim().isNotEmpty &&
        RegExp(r'^[A-Za-z0-9]{28}$').hasMatch(parts[2])) {
      return null;
    }
    if (RegExp(r'^\d+$').hasMatch(code)) {
      return 'The redemption PIN must contain exactly 6 digits.';
    }
    return 'This is not a valid MyHeritage voucher code. Scan the QR code again or enter the 6-digit PIN.';
  }

  static String? _positiveWholeNumber(
    String? value, {
    required String fieldName,
    required int maximum,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the $fieldName.';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'The $fieldName must be a whole number.';
    if (parsed <= 0) return 'The $fieldName must be at least 1.';
    if (parsed > maximum) {
      return 'The $fieldName cannot be greater than $maximum.';
    }
    return null;
  }
}

String rewardModuleErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw = error.toString().trim();
  final normalized = raw.toLowerCase();

  if (normalized.contains('permission-denied') ||
      normalized.contains('insufficient permission')) {
    return 'Your account is not allowed to perform this reward action. Check that you are signed in with the correct traveler or vendor account.';
  }
  if (normalized.contains('resource-exhausted') ||
      normalized.contains('quota exceeded') ||
      normalized.contains('quota reached')) {
    return 'Firebase has reached its request quota. Your voucher data is safe; please try again after the quota resets.';
  }
  if (normalized.contains('unavailable') ||
      normalized.contains('network') ||
      normalized.contains('socketexception')) {
    return 'The reward service cannot be reached right now. Check your internet connection and try again.';
  }
  if (normalized.contains('deadline-exceeded') ||
      normalized.contains('timed out') ||
      normalized.contains('timeout')) {
    return 'The reward service took too long to respond. Please try again.';
  }
  if (normalized.contains('unauthenticated') ||
      normalized.contains('no current user')) {
    return 'Your sign-in session has expired. Sign in again to continue.';
  }

  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
      .replaceFirst(
        RegExp(r'^\[cloud_firestore/[^\]]+\]\s*', caseSensitive: false),
        '',
      )
      .trim();
  if (cleaned.isEmpty || cleaned.toLowerCase().contains('firebaseexception')) {
    return fallback;
  }
  return cleaned;
}
