import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.hazardId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? hazardId;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      userId: '${data['userId'] ?? ''}',
      title: '${data['title'] ?? 'Update'}',
      message: '${data['message'] ?? ''}',
      type: '${data['type'] ?? 'general'}',
      isRead: data['isRead'] == true || data['read'] == true,
      hazardId: (data['hazardId'] ?? data['referenceId']) as String?,
      createdAt: asDate(data['createdAt']),
    );
  }
}
