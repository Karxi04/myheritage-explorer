part of '../auth_pages.dart';

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final newEmail = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool hidePassword = true;

  @override
  void dispose() {
    newEmail.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> updateEmail() async {
    final emailValue = newEmail.text.trim().toLowerCase();
    if (emailValue.isEmpty || !isValidEmail(emailValue)) {
      showMessage(context, 'Enter a valid new email address.', error: true);
      return;
    }

    if (password.text.isEmpty) {
      showMessage(context, 'Enter your password to confirm the change.', error: true);
      return;
    }

    if (emailValue == AppServices.auth.currentUser?.email) {
      showMessage(context, 'New email must be different from the current one.', error: true);
      return;
    }

    setState(() => busy = true);
    try {
      // 1. Re-authenticate (Required for email updates)
      await AppServices.reauthenticate(password.text);

      // 2. Send verification to new email
      // This triggers the "Email address change" template flow
      await AppServices.auth.currentUser!.verifyBeforeUpdateEmail(emailValue);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Verification Sent'),
            content: Text(
              'A verification link has been sent to $emailValue. '
              'The email address for your account will update once you click the link in that email.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to profile
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = e.message ?? 'Unable to update email.';
        if (e.code == 'email-already-in-use') {
          msg = 'This email is already associated with another account.';
        } else if (e.code == 'wrong-password') {
          msg = 'The password you entered is incorrect.';
        }
        showMessage(context, msg, error: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = AppServices.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Change Email',
              subtitle: 'Update the email associated with your account.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ExplorerCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: ExplorerColors.navySoft,
                            foregroundColor: ExplorerColors.navy,
                            child: Icon(Icons.alternate_email_rounded, size: 28),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Currently: $currentEmail',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: newEmail,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'New Email Address',
                              prefixIcon: Icon(Icons.mail_outline),
                              hintText: 'new.email@example.com',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: password,
                            obscureText: hidePassword,
                            obscuringCharacter: '*',
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => hidePassword = !hidePassword),
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: busy ? null : updateEmail,
                            child: Text(busy ? 'Processing...' : 'Send Verification Link'),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Note: You will need to verify the new email address before the change takes effect.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
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
