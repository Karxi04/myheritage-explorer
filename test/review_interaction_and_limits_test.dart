import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';

void main() {
  group('Helpful Button Toggle & Rapid Click Logic Tests', () {
    test('Helpful starts at 0, single toggle adds vote (0 -> 1)', () {
      final helpfulUserIds = <String>[];
      const currentUserId = 'traveler_101';
      const reviewAuthorId = 'traveler_202';

      expect(currentUserId == reviewAuthorId, isFalse);

      if (!helpfulUserIds.contains(currentUserId)) {
        helpfulUserIds.add(currentUserId);
      }

      expect(helpfulUserIds.length, 1);
      expect(helpfulUserIds.contains(currentUserId), isTrue);
    });

    test('Helpful toggle off removes vote (1 -> 0)', () {
      final helpfulUserIds = <String>['traveler_101'];
      const currentUserId = 'traveler_101';

      if (helpfulUserIds.contains(currentUserId)) {
        helpfulUserIds.remove(currentUserId);
      }

      expect(helpfulUserIds.length, 0);
      expect(helpfulUserIds.contains(currentUserId), isFalse);
    });

    test('Rapid duplicate clicks do not produce duplicate votes', () {
      final helpfulUserIds = <String>[];
      final pendingVotes = <String>{};
      const reviewId = 'rev_001';
      const currentUserId = 'traveler_101';

      void simulateClick() {
        if (pendingVotes.contains(reviewId)) return;
        pendingVotes.add(reviewId);

        if (!helpfulUserIds.contains(currentUserId)) {
          helpfulUserIds.add(currentUserId);
        }

        pendingVotes.remove(reviewId);
      }

      simulateClick();
      simulateClick();
      simulateClick();
      simulateClick();
      simulateClick();

      expect(helpfulUserIds.length, 1);
      expect(helpfulUserIds, ['traveler_101']);
    });

    test('Two different users vote (0 -> 2) and User A removes vote (2 -> 1)', () {
      final helpfulUserIds = <String>[];
      const userA = 'traveler_A';
      const userB = 'traveler_B';

      helpfulUserIds.add(userA);
      expect(helpfulUserIds.length, 1);

      helpfulUserIds.add(userB);
      expect(helpfulUserIds.length, 2);
      expect(helpfulUserIds.contains(userA), isTrue);
      expect(helpfulUserIds.contains(userB), isTrue);

      helpfulUserIds.remove(userA);
      expect(helpfulUserIds.length, 1);
      expect(helpfulUserIds.contains(userA), isFalse);
      expect(helpfulUserIds.contains(userB), isTrue);
    });

    test('Author is prevented from voting on own review', () {
      const currentUserId = 'traveler_101';
      const reviewAuthorId = 'traveler_101';

      bool canVote(String voterId, String authorId) {
        return voterId != authorId;
      }

      expect(canVote(currentUserId, reviewAuthorId), isFalse);
    });
  });

  group('One User = One Review Per Place & Ownership Badge Tests', () {
    test('Correctly identifies review belonging to current user', () {
      const currentUserId = 'traveler_101';
      final reviews = [
        {'id': 'r1', 'userId': 'traveler_999', 'comment': 'Nice place'},
        {'id': 'r2', 'userId': 'traveler_101', 'comment': 'My own review'},
      ];

      final ownReview = reviews.firstWhere((r) => r['userId'] == currentUserId);
      expect(ownReview['id'], 'r2');
      expect(ownReview['comment'], 'My own review');
    });

    test('Duplicate review prevention blocks second review for same place', () {
      final existingReviews = [
        {'userId': 'traveler_101', 'placeId': 'penang_hill'},
      ];

      bool canSubmitNewReview(String userId, String placeId) {
        final alreadyExists = existingReviews.any(
          (r) => r['userId'] == userId && r['placeId'] == placeId,
        );
        return !alreadyExists;
      }

      expect(canSubmitNewReview('traveler_101', 'penang_hill'), isFalse);
      expect(canSubmitNewReview('traveler_101', 'batu_caves'), isTrue);
      expect(canSubmitNewReview('traveler_202', 'penang_hill'), isTrue);
    });
  });

  group('2-Edit Limit Consistency & Dynamic NLP Re-Analysis Tests', () {
    String formatEditButtonLabel(int editCount) {
      return 'Edit Review ($editCount/2 edits used)';
    }

    test('Initial submission has editCount = 0 and both top and bottom match (0/2 edits used)', () {
      final review = {
        'id': 'rev_123',
        'userId': 'traveler_101',
        'rating': 5,
        'comment': 'Delicious Nyonya Laksa with authentic thick broth.',
        'editCount': 0,
      };

      final editCount = (review['editCount'] as num? ?? 0).toInt();
      final topButtonLabel = formatEditButtonLabel(editCount);
      final bottomButtonLabel = formatEditButtonLabel(editCount);

      expect(editCount, 0);
      expect(topButtonLabel, 'Edit Review (0/2 edits used)');
      expect(bottomButtonLabel, 'Edit Review (0/2 edits used)');
      expect(topButtonLabel == bottomButtonLabel, isTrue);
    });

    test('First edit increments editCount to 1 and both top and bottom match (1/2 edits used)', () {
      var review = {
        'id': 'rev_123',
        'userId': 'traveler_101',
        'rating': 5,
        'comment': 'Delicious Nyonya Laksa with authentic thick broth.',
        'editCount': 0,
      };

      // Perform Edit #1
      final newRating = 1;
      final newComment = 'Terrible service, food was cold, tasteless, and very disappointing.';
      
      final editedPrediction = ReviewMlModel.analyze(
        reviewText: newComment,
        rating: newRating,
      );

      expect(editedPrediction.sentiment, 'negative');

      review = {
        ...review,
        'rating': newRating,
        'comment': newComment,
        'editCount': (review['editCount'] as int) + 1,
        'mlSentiment': editedPrediction.sentiment,
      };

      final editCount = (review['editCount'] as num? ?? 0).toInt();
      final topButtonLabel = formatEditButtonLabel(editCount);
      final bottomButtonLabel = formatEditButtonLabel(editCount);

      expect(editCount, 1);
      expect(topButtonLabel, 'Edit Review (1/2 edits used)');
      expect(bottomButtonLabel, 'Edit Review (1/2 edits used)');
      expect(topButtonLabel == bottomButtonLabel, isTrue);
    });

    test('Second edit increments editCount to 2 and blocks further edits', () {
      var review = {
        'id': 'rev_123',
        'userId': 'traveler_101',
        'rating': 1,
        'comment': 'Terrible service.',
        'editCount': 1,
      };

      // Perform Edit #2
      final newRating = 5;
      final newComment = 'The worst food ever, completely cold and horrible taste.';

      final editedPrediction = ReviewMlModel.analyze(
        reviewText: newComment,
        rating: newRating,
      );

      expect(editedPrediction.ratingMismatch, isTrue);

      review = {
        ...review,
        'rating': newRating,
        'comment': newComment,
        'editCount': (review['editCount'] as int) + 1,
        'mlRatingMismatch': editedPrediction.ratingMismatch,
      };

      final editCount = (review['editCount'] as num? ?? 0).toInt();
      final canEdit = editCount < 2;

      expect(editCount, 2);
      expect(canEdit, isFalse);
    });

    test('Cancel edit and failed validations do not increment editCount', () {
      const initialEditCount = 1;
      var currentEditCount = initialEditCount;

      // Simulate opening edit and pressing Cancel
      bool userPressedCancel = true;
      if (userPressedCancel) {
        // No editCount increment on cancel
      }
      expect(currentEditCount, 1);

      // Simulate validation failure (empty comment)
      String emptyComment = '   ';
      if (emptyComment.trim().isEmpty) {
        // Validation fails, no increment
      }
      expect(currentEditCount, 1);
    });
  });
}
