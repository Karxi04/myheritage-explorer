part of '../auth_pages.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final pinController = TextEditingController();
  final confirmController = TextEditingController();
  bool isConfirming = false;
  String? firstPin;
  String error = '';

  void _onNumberTap(String value) {
    setState(() => error = '');
    final controller = isConfirming ? confirmController : pinController;
    if (controller.text.length < 6) {
      setState(() {
        controller.text += value;
      });
    }

    if (controller.text.length == 6) {
      if (!isConfirming) {
        Future.delayed(const Duration(milliseconds: 300), () {
          setState(() {
            firstPin = pinController.text;
            isConfirming = true;
          });
        });
      } else {
        if (confirmController.text == firstPin) {
          _savePin();
        } else {
          setState(() {
            error = 'PINs do not match. Try again.';
            confirmController.clear();
            pinController.clear();
            isConfirming = false;
            firstPin = null;
          });
        }
      }
    }
  }

  void _onBackspace() {
    final controller = isConfirming ? confirmController : pinController;
    if (controller.text.isNotEmpty) {
      setState(() {
        controller.text =
            controller.text.substring(0, controller.text.length - 1);
      });
    }
  }

  Future<void> _savePin() async {
    await PinService.setPin(confirmController.text);
    PinService.authorizeSession();
    if (mounted) {
      showGlobalNotice(
        title: 'Security PIN Set',
        message: 'Your 6-digit security PIN has been saved locally on this device.',
        onConfirm: () => Navigator.popUntil(context, (route) => route.isFirst),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Setup Security PIN'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              isConfirming ? Icons.lock_outline : Icons.dialpad_outlined,
              size: 64,
              color: ExplorerColors.navy,
            ),
            const SizedBox(height: 24),
            Text(
              isConfirming ? 'Confirm your PIN' : 'Create a 6-Digit PIN',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ExplorerColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConfirming
                  ? 'Re-enter the PIN to confirm'
                  : 'Add an extra layer of local security to your account.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ExplorerColors.muted),
            ),
            const SizedBox(height: 32),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDisplay() {
    final text = isConfirming ? confirmController.text : pinController.text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final hasValue = index < text.length;
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
