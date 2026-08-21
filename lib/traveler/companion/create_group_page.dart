part of '../traveler_pages.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _destination = TextEditingController();
  DateTime? _tripDate;
  bool _loading = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _tripDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tripDate == null) {
      showMessage(context, 'Please select a trip date.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = AppServices.auth.currentUser!.uid;
      final code = randomCode().toUpperCase();

      final docRef = await AppServices.db.collection('travel_groups').add({
        'name': _name.text.trim(),
        'destination': _destination.text.trim(),
        'tripDate': _tripDate,
        'code': code,
        'leaderId': uid,
        'memberIds': [uid],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Show success and the code
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Group Created Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your unique group code is:'),
                const SizedBox(height: 12),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: ExplorerColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share this code with your companions so they can join your group.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: ExplorerColors.muted),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to Companion Home
                },
                child: const Text('Finish'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Failed to create group: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Create Travel Group')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ExplorerSectionTitle(
                'Group Details',
                subtitle: 'Enter your trip information to get started.',
              ),
              const SizedBox(height: 20),
              ExplorerCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        hintText: 'e.g. Penang Foodies',
                        prefixIcon: Icon(Icons.groups_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Enter a group name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _destination,
                      decoration: const InputDecoration(
                        labelText: 'Trip Destination',
                        hintText: 'e.g. Georgetown, Penang',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Enter a destination' : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Trip Date',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          _tripDate == null
                              ? 'Select Date'
                              : DateFormat.yMMMd().format(_tripDate!),
                          style: TextStyle(
                            color: _tripDate == null
                                ? ExplorerColors.muted
                                : ExplorerColors.text,
                          ),
                        ),
                      ),
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
                    : const Text('Create Group'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
