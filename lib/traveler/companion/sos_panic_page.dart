part of '../traveler_pages.dart';

class SosPanicPage extends StatefulWidget {
  const SosPanicPage({
    super.key,
    required this.groupId,
    required this.group,
  });

  final String groupId;
  final Map<String, dynamic> group;

  @override
  State<SosPanicPage> createState() => _SosPanicPageState();
}

class _SosPanicPageState extends State<SosPanicPage> {
  bool _sending = false;

  Future<void> _triggerSos() async {
    if (_sending) return;

    setState(() => _sending = true);

    try {
      final user = AppServices.auth.currentUser;

      if (user == null) {
        throw Exception('Please sign in first.');
      }

      final position = await determinePosition();
      final profile = await AppServices.currentProfile();

      final senderName =
      '${profile?['displayName'] ?? user.displayName ?? 'A Companion'}'
          .trim();

      final leaderId =
      '${widget.group['leaderId'] ?? ''}'.trim();

      final groupName =
      '${widget.group['name'] ?? 'Travel Group'}'.trim();

      if (leaderId.isEmpty) {
        throw Exception(
          'This travel group does not have a valid leader.',
        );
      }

      final existingSnapshot = await AppServices.db
          .collection('sos_alerts')
          .where(
        'groupId',
        isEqualTo: widget.groupId,
      )
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? existing;

      for (final document in existingSnapshot.docs) {
        final data = document.data();

        if ('${data['senderId'] ?? ''}' == user.uid &&
            '${data['status'] ?? 'active'}'.toLowerCase() !=
                'resolved') {
          existing = document;
          break;
        }
      }

      late final DocumentReference<Map<String, dynamic>> sosRef;

      if (existing != null) {
        sosRef = existing.reference;

        await sosRef.set(
          {
            'senderId': user.uid,
            'senderName': senderName,
            'groupId': widget.groupId,
            'groupName': groupName,
            'leaderId': leaderId,
            'recipientId': leaderId,
            'recipientIds': [leaderId],
            'latitude': position.latitude,
            'longitude': position.longitude,
            'location': GeoPoint(
              position.latitude,
              position.longitude,
            ),
            'status': 'active',
            'timestamp': FieldValue.serverTimestamp(),
            'lastTriggeredAt': FieldValue.serverTimestamp(),
            'triggerCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      } else {
        sosRef =
        await AppServices.db.collection('sos_alerts').add({
          'senderId': user.uid,
          'senderName': senderName,
          'groupId': widget.groupId,
          'groupName': groupName,
          'leaderId': leaderId,
          'recipientId': leaderId,
          'recipientIds': [leaderId],
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location': GeoPoint(
            position.latitude,
            position.longitude,
          ),
          'status': 'active',
          'triggerCount': 1,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastTriggeredAt': FieldValue.serverTimestamp(),
          'acknowledgedAt': null,
          'acknowledgedBy': null,
          'acknowledgedByName': null,
          'routeStartedAt': null,
          'resolvedAt': null,
          'resolvedBy': null,
          'resolvedByName': null,
          'resolutionType': null,
          'resolutionNote': null,
          'adminOverride': false,
        });
      }

      final groupLocationRef = AppServices.db
          .collection('travel_groups')
          .doc(widget.groupId)
          .collection('locations')
          .doc(user.uid);

      await groupLocationRef.set(
        {
          'userId': user.uid,
          'displayName': senderName,
          'role': user.uid == leaderId ? 'leader' : 'member',
          'groupId': widget.groupId,
          'groupName': groupName,
          'location': GeoPoint(
            position.latitude,
            position.longitude,
          ),
          'latitude': position.latitude,
          'longitude': position.longitude,
          'approvedViewerIds': user.uid == leaderId
              ? [user.uid]
              : [user.uid, leaderId],
          'sharingEnabled': true,
          'sosActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await AppServices.db
          .collection('user_locations')
          .doc(user.uid)
          .set(
        {
          'userId': user.uid,
          'displayName': senderName,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location': GeoPoint(
            position.latitude,
            position.longitude,
          ),
          'updatedAt': FieldValue.serverTimestamp(),
          'activeGroupId': widget.groupId,
          'sharingEnabled': true,
          'sosActive': true,
        },
        SetOptions(merge: true),
      );

      if (leaderId != user.uid) {
        try {
          await AppServices.notify(
            userId: leaderId,
            title: 'Emergency SOS from $senderName',
            message:
            '$senderName triggered an SOS in $groupName. '
                'Open Companion to view their emergency location.',
            type: 'sos',
            referenceId: sosRef.id,
            groupId: widget.groupId,
          );
        } catch (error) {
          debugPrint(
            'Unable to send SOS notification: $error',
          );
        }
      }

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.sos_rounded,
            color: ExplorerColors.danger,
            size: 46,
          ),
          title: const Text('SOS Sent'),
          content: Text(
            '$senderName, your group leader has been notified. '
                'Your current GPS location is attached to this emergency incident.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Failed to send SOS: '
              '${error.toString().replaceFirst('Exception: ', '')}',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.dangerSoft,
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                const Icon(
                  Icons.warning_amber_rounded,
                  color: ExplorerColors.danger,
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Are you in danger?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: ExplorerColors.navy,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Press SOS to send your current GPS location and an emergency alert to your group leader.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: _sending ? null : _triggerSos,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: _sending
                          ? ExplorerColors.muted
                          : ExplorerColors.danger,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                          ExplorerColors.danger.withOpacity(.35),
                          blurRadius: 24,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 4,
                        ),
                      )
                          : const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.86),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF0B8B3),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: ExplorerColors.danger,
                        size: 19,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Stay calm and move to a safe place if possible. '
                              'Repeated SOS presses update the same active incident and notify the leader again.',
                          style: TextStyle(
                            color: ExplorerColors.text,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
