part of '../auth_pages.dart';

class PinEntryPage extends StatefulWidget {
  const PinEntryPage({super.key, this.onAuthorized});

  final VoidCallback? onAuthorized;

  @override
  State<PinEntryPage> createState() => _PinEntryPageState();
}

class _PinEntryPageState extends State<PinEntryPage> {
  final pinController = TextEditingController();
  String error = '';
  bool busy = false;

  void _onNumberTap(String value) {
    if (busy) return;
    setState(() => error = '');
    if (pinController.text.length < 6) {
      setState(() {
        pinController.text += value;
      });
    }

    if (pinController.text.length == 6) {
      _verify();
    }
  }

  void _onBackspace() {
    if (busy) return;
    if (pinController.text.isNotEmpty) {
      setState(() {
        pinController.text =
            pinController.text.substring(0, pinController.text.length - 1);
      });
    }
  }

  Future<void> _verify() async {
    setState(() => busy = true);
    final isValid = await PinService.verifyPin(pinController.text);
    if (isValid) {
      PinService.authorizeSession();
      if (widget.onAuthorized != null) {
        widget.onAuthorized!();
      } else if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } else {
      setState(() {
        error = 'Incorrect PIN. Please try again.';
        pinController.clear();
        busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Security Verification'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => AppServices.auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(
              Icons.lock_person_outlined,
              size: 72,
              color: ExplorerColors.navy,
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter Security PIN',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ExplorerColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enter your 6-digit PIN to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ExplorerColors.muted),
            ),
            const SizedBox(height: 40),
            _buildPinDisplay(),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error,
                  style: const TextStyle(color: ExplorerColors.danger, fontSize: 13),
                ),
              ),
            const Spacer(),
            _buildKeyboard(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final hasValue = index < pinController.text.length;
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasValue ? ExplorerColors.navy : Colors.grey.shade300,
            border: Border.all(
              color: hasValue ? ExplorerColors.navy : Colors.grey.shade400,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeyboard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildKeyboardRow(['1', '2', '3']),
          const SizedBox(height: 20),
          _buildKeyboardRow(['4', '5', '6']),
          const SizedBox(height: 20),
          _buildKeyboardRow(['7', '8', '9']),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 60),
              _buildKeyboardButton('0'),
              SizedBox(
                width: 60,
                child: IconButton(
                  onPressed: _onBackspace,
                  icon: const Icon(Icons.backspace_outlined, color: ExplorerColors.navy),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildKeyboardButton(n)).toList(),
    );
  }

  Widget _buildKeyboardButton(String label) {
    return InkWell(
      onTap: () => _onNumberTap(label),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ExplorerColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: ExplorerColors.navy,
          ),
        ),
      ),
    );
  }
}
