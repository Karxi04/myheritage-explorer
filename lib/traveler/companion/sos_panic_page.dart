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
    setState(() => _sending = true);
    try {
      final pos = await determinePosition();
      final uid = AppServices.auth.currentUser!.uid;
      final profile = await AppServices.currentProfile();
      final name = profile?['displayName'] ?? 'A Companion';
      
      final leaderId = widget.group['leaderId'];

      final sosRef =
      await AppServices.db
          .collection('sos_alerts')
          .add({
        'senderId': uid,
        'senderName': name,
        'groupId': widget.groupId,
        'groupName': widget.group['name'],
        'leaderId': leaderId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'location': GeoPoint(
          pos.latitude,
          pos.longitude,
        ),
      });

      // Also update user_locations for the shared view
      await AppServices.db.collection('user_locations').doc(uid).set({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
        'activeGroupId': widget.groupId,
        'sharingEnabled': true,
      }, SetOptions(merge: true));

      if ('$leaderId'.isNotEmpty &&
          '$leaderId' != uid) {
        await AppServices.notify(
          userId: '$leaderId',

          title:
          'Emergency SOS from $name',

          message:
          '$name triggered an SOS in '
              '${widget.group['name'] ?? 'your travel group'}. '
              'Open the app to view their emergency location.',

          type: 'sos',

          referenceId:
          sosRef.id,

          groupId:
          widget.groupId,
        );
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('SOS Sent'),
            content: const Text('Your group leader has been notified of your emergency and location.'),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Back to details
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Failed to send SOS: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: ExplorerColors.danger, size: 80),
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
                'Pressing the button below will send your current GPS coordinates to your group leader.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ExplorerColors.muted, fontSize: 16),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _sending ? null : _triggerSos,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: ExplorerColors.danger,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ExplorerColors.danger.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _sending
                        ? const CircularProgressIndicator(color: Colors.white)
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
              const Text(
                'Stay calm and find a safe place if possible.',
                style: TextStyle(fontStyle: FontStyle.italic, color: ExplorerColors.muted),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
