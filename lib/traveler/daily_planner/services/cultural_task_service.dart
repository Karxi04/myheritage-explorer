import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services.dart';

class CulturalTaskService {
  static List<Map<String, dynamic>>? _cachedTasks;
  static DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Load active cultural tasks from Firestore
  static Future<List<Map<String, dynamic>>> loadActiveTasks({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedTasks != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedTasks!;
    }

    try {
      final snap = await AppServices.db
          .collection('cultural_tasks')
          .where('status', isEqualTo: 'active')
          .get();

      final now = DateTime.now();
      final tasks = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final expiresAt = data['expiresAt'];
        if (expiresAt is Timestamp && expiresAt.toDate().isBefore(now)) {
          continue; // Expired
        }

        tasks.add({
          'id': doc.id,
          'taskId': doc.id,
          'title': '${data['title'] ?? 'Cultural Heritage Task'}',
          'description': '${data['description'] ?? ''}',
          'rewardPoints': (data['rewardPoints'] as num?)?.toInt() ?? 100,
          'locationId': '${data['locationId'] ?? data['placeId'] ?? ''}'.trim(),
          'placeId': '${data['locationId'] ?? data['placeId'] ?? ''}'.trim(),
          'placeName': '${data['placeName'] ?? data['locationName'] ?? ''}'.trim(),
          'stateId': '${data['stateId'] ?? ''}'.trim(),
          'status': '${data['status'] ?? 'active'}',
          'category': '${data['category'] ?? 'Heritage'}',
        });
      }

      _cachedTasks = tasks;
      _cacheTime = DateTime.now();
      return tasks;
    } catch (_) {
      return _cachedTasks ?? const [];
    }
  }

  /// Match an active task for a specific place
  static Map<String, dynamic>? matchTaskForPlace(
    Map<String, dynamic> place,
    List<Map<String, dynamic>> activeTasks,
  ) {
    final placeId = '${place['placeId'] ?? ''}'.trim();
    final vendorId = '${place['vendorId'] ?? ''}'.trim();
    final placeName = '${place['name'] ?? ''}'.trim().toLowerCase();

    for (final task in activeTasks) {
      final taskLoc = '${task['locationId'] ?? task['placeId'] ?? ''}'.trim();
      final taskPlaceName = '${task['placeName'] ?? ''}'.trim().toLowerCase();

      if (placeId.isNotEmpty && taskLoc.isNotEmpty && (taskLoc == placeId || taskLoc == 'place_$placeId')) {
        return task;
      }
      if (vendorId.isNotEmpty && taskLoc.isNotEmpty && (taskLoc == vendorId || taskLoc == 'vendor_$vendorId')) {
        return task;
      }
      if (placeName.isNotEmpty && taskPlaceName.isNotEmpty && (placeName == taskPlaceName || placeName.contains(taskPlaceName))) {
        return task;
      }
    }
    return null;
  }

  static void clearCache() {
    _cachedTasks = null;
    _cacheTime = null;
  }
}
