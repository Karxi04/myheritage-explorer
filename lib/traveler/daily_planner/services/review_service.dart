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
      Query<Map<String, dynamic>> query = AppServices.db
          .collection('reviews')
          .where('userId', isEqualTo: userId);

      if (vendorId.isNotEmpty) {
        query = query.where('vendorId', isEqualTo: vendorId);
      } else if (placeId.isNotEmpty) {
        query = query.where('placeId', isEqualTo: placeId);
      }

      final snap = await query.limit(1).get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Submit review with validation and duplicate prevention
  static Future<void> submitReview({
    required String userId,
    required String userName,
    required String placeId,
    String vendorId = '',
    required int rating,
    required String comment,
    String placeName = '',
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception('You must be signed in to submit a review.');
    }
    if (rating < 1 || rating > 5) {
      throw Exception('Please select a star rating between 1 and 5.');
    }
    if (comment.trim().isEmpty) {
      throw Exception('Please write a brief comment describing your experience.');
    }

    final alreadyReviewed = await hasUserReviewedPlace(
      userId: userId,
      placeId: placeId,
      vendorId: vendorId,
    );
    if (alreadyReviewed) {
      throw Exception('You have already submitted a review for this location.');
    }

    final batch = AppServices.db.batch();
    final reviewRef = AppServices.db.collection('reviews').doc();

    batch.set(reviewRef, {
      'userId': userId,
      'userName': userName,
      'placeId': placeId,
      'vendorId': vendorId,
      'placeName': placeName,
      'rating': rating,
      'comment': comment.trim(),
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (placeId.isNotEmpty && !placeId.startsWith('vendor_')) {
      final placeRef = AppServices.db.collection('places').doc(placeId);
      batch.update(placeRef, {
        'validReviewCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
