import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/services.dart';
import '../models/app_notification.dart';

class NotificationService {
  const NotificationService();

  Query<Map<String, dynamic>> _queryForUser(String userId) {
    return AppServices.db
        .collection('notifications')
        .where('userId', isEqualTo: userId);
  }

  Stream<List<AppNotification>> watchForUser(String userId) {
    return _queryForUser(userId).snapshots().map((snapshot) {
      final notifications = snapshot.docs.map(AppNotification.fromDoc).toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        );
      return notifications;
    });
  }

  /// Emits only notifications created after this listener's initial snapshot.
  Stream<AppNotification> watchNewForUser(String userId) async* {
    var initialSnapshot = true;
    await for (final snapshot in _queryForUser(userId).snapshots()) {
      if (initialSnapshot) {
        initialSnapshot = false;
        continue;
      }
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          yield AppNotification.fromDoc(change.doc);
        }
      }
    }
  }

  Future<void> markRead(String notificationId) {
    return AppServices.db
        .collection('notifications')
        .doc(notificationId)
        .update({
          'isRead': true,
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
  }
}
