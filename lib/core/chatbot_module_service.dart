import 'package:cloud_firestore/cloud_firestore.dart';
import 'services.dart';

class ChatbotModuleService {
  ChatbotModuleService._();

  static Future<Map<String, dynamic>>
  buildUserContext() async {
    final user = AppServices.auth.currentUser;

    if (user == null) {
      throw Exception('Please sign in first.');
    }

    final uid = user.uid;

    final results = await Future.wait([
      _profile(uid),
      _groups(uid),
      _rewards(uid),
      _culturalTasks(uid),
      _hazards(),
      _notifications(uid),
      _itineraries(uid),
    ]);

    return {
      'profile': results[0],
      'companion': results[1],
      'rewards': results[2],
      'cultural': results[3],
      'safety': results[4],
      'notifications': results[5],
      'itineraries': results[6],
    };
  }

  // ============================================================
  // PROFILE
  // ============================================================

  static Future<Map<String, dynamic>> _profile(
      String uid,
      ) async {
    try {
      final snapshot =
      await AppServices.travelerRef(uid).get();

      final data =
          snapshot.data() ??
              const <String, dynamic>{};

      return {
        'displayName':
        data['displayName'] ?? '',
        'points':
        (data['points'] as num?)?.toInt() ?? 0,
        'travelInterests':
        data['travelInterests'] ?? [],
        'budgetPreference':
        data['budgetPreference'],
        'travelPace':
        data['travelPace'],
        'rank':
        data['rank'],
      };
    } catch (error) {
      return {
        'error': '$error',
      };
    }
  }

  // ============================================================
  // COMPANION
  // ============================================================

  static Future<Map<String, dynamic>> _groups(
      String uid,
      ) async {
    try {
      final snapshot =
      await AppServices.db
          .collection('travel_groups')
          .where(
        'memberIds',
        arrayContains: uid,
      )
          .get();

      final groups = <Map<String, dynamic>>[];

      for (final document in snapshot.docs) {
        final data = document.data();

        if ('${data['status'] ?? ''}' !=
            'active') {
          continue;
        }

        final memberIds =
        List<String>.from(
          data['memberIds'] ??
              const <String>[],
        );

        final leaderId =
            '${data['leaderId'] ?? ''}';

        groups.add({
          'groupId': document.id,
          'name':
          data['name'] ?? 'Travel Group',
          'description':
          data['description'] ?? '',
          'code':
          data['code'] ?? '',
          'role':
          leaderId == uid
              ? 'leader'
              : 'member',
          'memberCount':
          memberIds.length,
          'memberNames':
          data['memberNames'] ?? {},
        });
      }

      return {
        'count': groups.length,
        'groups': groups,
      };
    } catch (error) {
      return {
        'count': 0,
        'groups': [],
        'error': '$error',
      };
    }
  }

  // ============================================================
  // REWARDS
  // ============================================================

  static Future<Map<String, dynamic>> _rewards(
      String uid,
      ) async {
    try {
      final profile =
      await AppServices
          .travelerRef(uid)
          .get();

      final points =
          (profile.data()?['points']
          as num?)
              ?.toInt() ??
              0;

      final snapshot =
      await AppServices.db
          .collection('vouchers')
          .where(
        'status',
        isEqualTo: 'active',
      )
          .get();

      final vouchers =
      <Map<String, dynamic>>[];

      for (final document in snapshot.docs) {
        final data = document.data();

        final cost =
            (data['pointCost']
            as num?)
                ?.toInt() ??
                0;

        final inventory =
            (data['inventoryRemaining']
            as num?)
                ?.toInt() ??
                0;

        final expiry =
        _toDate(data['expiresAt']);

        if (inventory <= 0 ||
            cost <= 0) {
          continue;
        }

        if (expiry != null &&
            expiry.isBefore(DateTime.now())) {
          continue;
        }

        vouchers.add({
          'voucherId':
          document.id,
          'title':
          data['title'] ?? '',
          'description':
          data['description'] ?? '',
          'vendorName':
          data['vendorName'] ?? '',
          'pointCost':
          cost,
          'canClaim':
          points >= cost,
          'pointsNeeded':
          points >= cost
              ? 0
              : cost - points,
        });
      }

      return {
        'points': points,
        'availableVoucherCount':
        vouchers.length,
        'vouchers':
        vouchers.take(8).toList(),
      };
    } catch (error) {
      return {
        'error': '$error',
      };
    }
  }

  // ============================================================
  // CULTURAL TASKS
  // ============================================================

  static Future<Map<String, dynamic>>
  _culturalTasks(
      String uid,
      ) async {
    try {
      final snapshot =
      await AppServices.db
          .collection('cultural_tasks')
          .where(
        'status',
        isEqualTo: 'active',
      )
          .get();

      final tasks =
      <Map<String, dynamic>>[];

      for (final document in snapshot.docs) {
        final data = document.data();

        final deadline =
        _toDate(
          data['deadline'],
        );

        if (deadline != null &&
            deadline.isBefore(
              DateTime.now(),
            )) {
          continue;
        }

        tasks.add({
          'taskId':
          document.id,
          'title':
          data['title'] ?? '',
          'category':
          data['category'] ?? '',
          'vendorName':
          data['vendorName'] ?? '',
          'rewardPoints':
          data['rewardPoints'] ?? 0,
          'description':
          data['description'] ?? '',
        });
      }

      return {
        'activeCount':
        tasks.length,
        'tasks':
        tasks.take(8).toList(),
      };
    } catch (error) {
      return {
        'activeCount': 0,
        'tasks': [],
        'error': '$error',
      };
    }
  }

  // ============================================================
  // SAFETY
  // ============================================================

  static Future<Map<String, dynamic>>
  _hazards() async {
    try {
      final snapshot =
      await AppServices.db
          .collection('hazards')
          .get();

      final hazards =
      <Map<String, dynamic>>[];

      for (final document in snapshot.docs) {
        final data =
        document.data();

        final status =
        '${data['status'] ?? ''}'
            .toLowerCase();

        // Only expose verified/current hazards.
        if (status != 'verified') {
          continue;
        }

        hazards.add({
          'hazardId':
          document.id,
          'category':
          data['category'] ?? '',
          'severity':
          data['severity'] ?? '',
          'description':
          data['description'] ?? '',
          'status':
          data['status'] ?? '',
        });
      }

      return {
        'verifiedCount':
        hazards.length,
        'hazards':
        hazards.take(10).toList(),
      };
    } catch (error) {
      return {
        'verifiedCount': 0,
        'hazards': [],
        'error': '$error',
      };
    }
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  static Future<Map<String, dynamic>>
  _notifications(
      String uid,
      ) async {
    try {
      final snapshot =
      await AppServices.db
          .collection('notifications')
          .where(
        'userId',
        isEqualTo: uid,
      )
          .get();

      final unread =
      snapshot.docs.where(
            (document) =>
        document.data()['read'] !=
            true,
      );

      return {
        'total':
        snapshot.docs.length,
        'unread':
        unread.length,
      };
    } catch (error) {
      return {
        'unread': 0,
        'error': '$error',
      };
    }
  }

  // ============================================================
  // ITINERARIES
  // ============================================================

  static Future<Map<String, dynamic>>
  _itineraries(
      String uid,
      ) async {
    try {
      final snapshot =
      await AppServices.db
          .collection('itineraries')
          .where(
        'userId',
        isEqualTo: uid,
      )
          .get();

      final itineraries =
      snapshot.docs.map(
            (document) {
          final data =
          document.data();

          return {
            'itineraryId':
            document.id,
            'title':
            data['title'] ?? '',
            'area':
            data['area'] ?? '',
            'status':
            data['status'] ?? '',
            'createdAt':
            _toDate(
              data['createdAt'],
            )
                ?.toIso8601String(),
          };
        },
      ).toList();

      itineraries.sort(
            (a, b) =>
            '${b['createdAt'] ?? ''}'
                .compareTo(
              '${a['createdAt'] ?? ''}',
            ),
      );

      return {
        'count':
        itineraries.length,
        'recent':
        itineraries.take(5).toList(),
      };
    } catch (error) {
      return {
        'count': 0,
        'recent': [],
        'error': '$error',
      };
    }
  }

  static DateTime? _toDate(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}