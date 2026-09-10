import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services.dart';

class ReviewService {
  /// Calculate public rating excluding hidden, filtered, or deleted reviews
  static Future<Map<String, dynamic>> calculatePublicRatingForPlace({
    required String placeId,
    String vendorId = '',
  }) async {
    try {
      Query<Map<String, dynamic>> query = AppServices.db.collection('reviews');
      if (vendorId.isNotEmpty) {
        query = query.where('vendorId', isEqualTo: vendorId);
      } else if (placeId.isNotEmpty) {
        query = query.where('placeId', isEqualTo: placeId);
      } else {
        return {'averageRating': 4.5, 'reviewCount': 0, 'trustLabel': 'Not Rated'};
      }

      final snap = await query.get();
      final validReviews = snap.docs.where((doc) {
        final data = doc.data();
        final status = '${data['status'] ?? 'active'}'.toLowerCase();
        return status != 'hidden' && status != 'filtered' && status != 'deleted';
      }).toList();

      if (validReviews.isEmpty) {
        return {'averageRating': 4.5, 'reviewCount': 0, 'trustLabel': 'Insufficient Data'};
      }

      double total = 0.0;
      for (final doc in validReviews) {
        final r = (doc.data()['rating'] as num?)?.toDouble() ?? 5.0;
        total += r;
      }
      final avg = double.parse((total / validReviews.length).toStringAsFixed(1));
      final count = validReviews.length;
      final trust = count >= 5 ? 'High Trust' : (count >= 2 ? 'Medium Trust' : 'Low Trust');

      return {
        'averageRating': avg,
        'reviewCount': count,
        'trustLabel': trust,
      };
    } catch (_) {
      return {'averageRating': 4.5, 'reviewCount': 0, 'trustLabel': 'Verified Place'};
    }
  }

  /// Check if user has already reviewed this place/vendor
  static Future<bool> hasUserReviewedPlace({
    required String userId,
    required String placeId,
    String vendorId = '',
  }) async {
    try {
      if (userId.trim().isEmpty) return false;
      Query<Map<String, dynamic>> query = AppServices.db
          .collection('reviews')
          .where('userId', isEqualTo: userId.trim());

      if (vendorId.trim().isNotEmpty) {
        query = query.where('vendorId', isEqualTo: vendorId.trim());
      } else if (placeId.trim().isNotEmpty) {
        query = query.where('placeId', isEqualTo: placeId.trim());
      } else {
        return false;
      }

      final snap = await query.limit(1).get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Fetch the existing review map if the user has already reviewed this place
  static Future<Map<String, dynamic>?> getUserReviewForPlace({
    required String userId,
    required String placeId,
    String vendorId = '',
  }) async {
    try {
      if (userId.trim().isEmpty) return null;
      Query<Map<String, dynamic>> query = AppServices.db
          .collection('reviews')
          .where('userId', isEqualTo: userId.trim());

      if (vendorId.trim().isNotEmpty) {
        query = query.where('vendorId', isEqualTo: vendorId.trim());
      } else if (placeId.trim().isNotEmpty) {
        query = query.where('placeId', isEqualTo: placeId.trim());
      } else {
        return null;
      }

      final snap = await query.limit(1).get();
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return {'id': doc.id, ...doc.data()};
    } catch (_) {
      return null;
    }
  }

  /// Toggle helpful vote atomically.
  /// Returns `true` if the vote was added (marked helpful), or `false` if the vote was removed (unmarked).
  /// Throws an exception if the user attempts to upvote their own review or review is missing.
  static Future<bool> toggleHelpfulVote({
    required String reviewId,
    required String userId,
  }) async {
    final cleanReviewId = reviewId.trim();
    final cleanUserId = userId.trim();
    if (cleanReviewId.isEmpty || cleanUserId.isEmpty) {
      throw Exception('Invalid review or user ID for helpful vote.');
    }

    final docRef = AppServices.db.collection('reviews').doc(cleanReviewId);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw Exception('Review not found.');
    }

    final data = snap.data() ?? const <String, dynamic>{};
    if ('${data['userId'] ?? ''}' == cleanUserId) {
      throw Exception('You cannot mark your own review as helpful.');
    }

    final currentHelpfulUserIds = List<String>.from(
      data['helpfulUserIds'] ?? const <String>[],
    );
    final isAlreadyVoted = currentHelpfulUserIds.contains(cleanUserId);

    if (isAlreadyVoted) {
      // Toggle OFF: remove user UID and decrement helpfulCount safely
      await docRef.update({
        'helpfulUserIds': FieldValue.arrayRemove([cleanUserId]),
        'helpfulCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return false;
    } else {
      // Toggle ON: add user UID and increment helpfulCount
      await docRef.update({
        'helpfulUserIds': FieldValue.arrayUnion([cleanUserId]),
        'helpfulCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }

  /// Submit review with validation, aspect tags, and duplicate prevention.
  /// Enforces: 1 user + 1 place = maximum 1 review.
  static Future<String> submitReview({
    required String userId,
    required String userName,
    required String placeId,
    String vendorId = '',
    required int rating,
    required String comment,
    String placeName = '',
    String placeNameKey = '',
    String source = '',
    String geoapifyPlaceId = '',
    List<String> aspectTags = const [],
    bool isVerified = true,
    Map<String, dynamic>? mlData,
  }) async {
    final cleanUserId = userId.trim();
    final cleanComment = comment.trim();

    if (cleanUserId.isEmpty) {
      throw Exception('You must be signed in to submit a review.');
    }
    if (rating < 1 || rating > 5) {
      throw Exception('Please select a star rating between 1 and 5.');
    }
    if (cleanComment.isEmpty) {
      throw Exception('Please write a brief comment describing your experience.');
    }

    final alreadyReviewed = await hasUserReviewedPlace(
      userId: cleanUserId,
      placeId: placeId,
      vendorId: vendorId,
    );
    if (alreadyReviewed) {
      throw Exception('You have already submitted a review for this location. You can edit your existing review.');
    }

    final reviewRef = AppServices.db.collection('reviews').doc();
    final Map<String, dynamic> docData = {
      'userId': cleanUserId,
      'userName': userName,
      'reviewerName': userName,
      'placeId': placeId,
      'vendorId': vendorId,
      'placeName': placeName,
      'placeNameKey': placeNameKey,
      'source': source.isNotEmpty ? source : 'registered_vendor',
      'geoapifyPlaceId': geoapifyPlaceId,
      'rating': rating,
      'comment': cleanComment,
      'aspectTags': aspectTags,
      'helpfulCount': 0,
      'helpfulUserIds': <String>[],
      'editCount': 0,
      'isVerified': isVerified,
      'status': mlData?['status'] ?? 'valid',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (mlData != null) {
      docData.addAll(mlData);
    }

    final batch = AppServices.db.batch();
    batch.set(reviewRef, docData);

    if (placeId.isNotEmpty && !placeId.startsWith('vendor_')) {
      final placeRef = AppServices.db.collection('places').doc(placeId);
      batch.update(placeRef, {
        'validReviewCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return reviewRef.id;
  }

  /// Edit existing review with maximum 2-edit limit and re-run ML fields.
  /// Preserves reviewId, userId, placeId, original createdAt, and helpful votes.
  static Future<void> editReview({
    required String reviewId,
    required String userId,
    required int newRating,
    required String newComment,
    List<String> newAspectTags = const [],
    required Map<String, dynamic> mlData,
  }) async {
    final cleanReviewId = reviewId.trim();
    final cleanUserId = userId.trim();
    final cleanComment = newComment.trim();

    if (cleanReviewId.isEmpty || cleanUserId.isEmpty) {
      throw Exception('Invalid review or user ID for editing.');
    }
    if (newRating < 1 || newRating > 5) {
      throw Exception('Please select a star rating between 1 and 5.');
    }
    if (cleanComment.isEmpty) {
      throw Exception('Please provide a review comment.');
    }

    final docRef = AppServices.db.collection('reviews').doc(cleanReviewId);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw Exception('Review not found.');
    }

    final data = snap.data() ?? const <String, dynamic>{};
    if ('${data['userId'] ?? ''}' != cleanUserId) {
      throw Exception('Unauthorized: You can only edit your own review.');
    }

    final currentEditCount = (data['editCount'] as num? ?? 0).toInt();
    if (currentEditCount >= 2) {
      throw Exception('You have reached the maximum of 2 review edits.');
    }

    final Map<String, dynamic> updateData = {
      'rating': newRating,
      'comment': cleanComment,
      'aspectTags': newAspectTags,
      'editCount': currentEditCount + 1,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    updateData.addAll(mlData);

    await docRef.update(updateData);
  }
}
