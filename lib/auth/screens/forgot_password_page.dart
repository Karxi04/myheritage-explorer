
part of '../auth_pages.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.initialEmail = '',
    this.admin = false,
  });

  final String initialEmail;
  final bool admin;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController email;
  bool busy = false;
  bool sent = false;

  @override
  void initState() {
    super.initState();
    email = TextEditingController(text: widget.initialEmail);
  }

  Future<void> sendReset() async {
    if (email.text.trim().isEmpty) {
      showMessage(context, 'Enter your email address.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      await AppServices.auth.sendPasswordResetEmail(email: email.text.trim());
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.admin
          ? ExplorerColors.companionBackground
          : ExplorerColors.background,
      appBar: widget.admin
          ? null
          : AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ExplorerCard(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  if (widget.admin)
                    const ExplorerBrand()
                  else
                    Container(
                      width: 62,
                      height: 62,
                      decoration: const BoxDecoration(
                        color: ExplorerColors.navySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        color: ExplorerColors.navy,
                        size: 30,
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    sent ? 'Check Your Email' : 'Reset Password',
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sent
                        ? 'A secure password reset link was sent to ${email.text.trim()}.'
                        : widget.admin
                            ? 'Enter your administrator email and we will send you a secure link to reset your password.'
                            : 'Enter your email and we will send you a secure password reset link.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!sent) ...[
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: busy ? null : sendReset,
                      child: Text(busy ? 'Sending...' : 'Send Reset Link'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(sent ? 'Back to Login' : 'Back to Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
