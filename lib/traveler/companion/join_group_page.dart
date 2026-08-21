part of '../traveler_pages.dart';

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _code = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      showMessage(context, 'Please enter a group code.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final snap = await AppServices.db
          .collection('travel_groups')
          .where('code', isEqualTo: code)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        throw Exception('Invalid group code or group is no longer active.');
      }

      final groupDoc = snap.docs.first;
      final memberIds = List<String>.from(groupDoc.data()['memberIds'] ?? []);
      final uid = AppServices.auth.currentUser!.uid;

      if (memberIds.contains(uid)) {
        throw Exception('You are already a member of this group.');
      }

      await groupDoc.reference.update({
        'memberIds': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage(context, 'Joined group successfully.');
        Navigator.pop(context); // Return to Companion Home
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Join Travel Group')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ExplorerSectionTitle(
              'Enter Group Code',
              subtitle: 'Ask your group leader for the 6-character code.',
            ),
            const SizedBox(height: 20),
            ExplorerCard(
              child: Column(
                children: [
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'CODE',
                      counterText: '',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The code is case-insensitive.',
                    style: TextStyle(fontSize: 12, color: ExplorerColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Join Group'),
            ),
            const SizedBox(height: 40),
            const ExplorerSectionTitle(
              'Recent Groups',
              subtitle: 'Groups you have previously joined.',
            ),
            const SizedBox(height: 12),
            // For now, showing a simple placeholder as per instructions to keep it simple.
            // In a real app, this could fetch from local storage or a user's group history.
            const ExplorerCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No recently joined groups available.',
                    style: TextStyle(color: ExplorerColors.muted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
