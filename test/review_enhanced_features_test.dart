import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';

void main() {
  group('ReviewMlModel Multilingual & Expanded Dataset Tests', () {
    test('Correctly classifies authentic positive Malaysian food review', () {
      final prediction = ReviewMlModel.analyze(
        reviewText: 'Authentic BM salted vegetable duck soup paired with aromatic dark yam rice. Delicious!',
        rating: 5,
      );
      expect(prediction.sentiment, 'positive');
      expect(prediction.isSuspicious, isFalse);
    });

    test('Correctly classifies authentic Malay review', () {
      final prediction = ReviewMlModel.analyze(
        reviewText: 'Makanan sangat sedap dan staf peramah, layanan terbaik tiada tandingan!',
        rating: 5,
      );
      expect(prediction.sentiment, 'positive');
      expect(prediction.dominantLanguage, 'ms');
      expect(prediction.isSuspicious, isFalse);
    });

    test('Correctly classifies authentic Chinese review', () {
      final prediction = ReviewMlModel.analyze(
        reviewText: '食物非常好吃，服务态度很亲切，非常推荐大家来尝试！',
        rating: 5,
      );
      expect(prediction.sentiment, 'positive');
      expect(prediction.dominantLanguage, 'zh');
      expect(prediction.isSuspicious, isFalse);
    });

    test('Correctly handles negation positive review (not bad / tak mengecewakan)', () {
      final prediction = ReviewMlModel.analyze(
        reviewText: 'not bad at all, really enjoyed the heritage atmosphere and friendly guide',
        rating: 4,
      );
      expect(prediction.sentiment, 'positive');
      expect(prediction.isSuspicious, isFalse);
    });

    test('Correctly detects rating mismatch as suspicious', () {
      final prediction = ReviewMlModel.analyze(
        reviewText: 'Terrible meal. The dish lacked flavor and freshness, cold and soggy food.',
        rating: 5,
      );
      expect(prediction.sentiment, 'negative');
      expect(prediction.ratingMismatch, isTrue);
      expect(prediction.isSuspicious, isTrue);
    });

    test('Correctly detects promotional URL spam', () {
      final decision = ReviewModerationPolicy.decide(
        prediction: ReviewMlModel.analyze(
          reviewText: 'Claim your free 500 dollar hotel voucher at http://scam-promo.com right now!',
          rating: 5,
        ),
        ruleFlags: const ['Contains an external link'],
        reviewText: 'Claim your free 500 dollar hotel voucher at http://scam-promo.com right now!',
        rating: 5,
      );
      expect(decision.isFlagged, isTrue);
      expect(decision.riskLevel, 'high');
    });
  });
}
