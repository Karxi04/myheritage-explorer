import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';

void main() {
  test('basic Flutter test environment works', () {
    expect(1 + 1, 2);
  });

  test('review model flags negative text with a high star rating', () {
    final prediction = ReviewMlModel.analyze(
      reviewText:
          'Terrible experience, dirty display, rude service and not recommended.',
      rating: 5,
    );

    expect(prediction.ratingMismatch, isTrue);
    expect(prediction.isSuspicious, isTrue);
  });

  test('review model flags positive text with a low star rating', () {
    final prediction = ReviewMlModel.analyze(
      reviewText:
          'Excellent cultural stop with friendly staff and a wonderful visit.',
      rating: 1,
    );

    expect(prediction.ratingMismatch, isTrue);
    expect(prediction.isSuspicious, isTrue);
  });
}
