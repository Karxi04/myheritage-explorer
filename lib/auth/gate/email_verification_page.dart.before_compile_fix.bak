
part of '../auth_gate.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.user,
  });

  final User user;

  @override
  State<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool busy = false;
  bool resendBusy = false;

  Future<void> refreshVerificationStatus() async {
    if (busy) return;
    setState(() => busy = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You are no longer signed in. Please sign in again.');
      }

      await currentUser.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser?.emailVerified == true) {
        await AppServices.userRef(refreshedUser!.uid).set(
          {
            'emailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (mounted) {
          showMessage(context, 'Email verified successfully.');
        }
      } else {
        if (mounted) {
          showMessage(
            context,
            'Firebase still shows this email as unverified. Open the newest verification email, tap the link, then return and press Verify Account.',
            error: true,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showMessage(context, e.message ?? e.code, error: true);
      }
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

  Future<void> resendVerificationEmail() async {
    if (resendBusy) return;
    setState(() => resendBusy = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You are no longer signed in. Please sign in again.');
      }

      await currentUser.sendEmailVerification();
      if (mounted) {
        showMessage(context, 'A new verification email was sent.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showMessage(context, e.message ?? e.code, error: true);
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => resendBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = kIsWeb;

    return Scaffold(
      backgroundColor: isAdmin
          ? ExplorerColors.companionBackground
          : ExplorerColors.background,
      appBar: isAdmin
          ? null
          : AppBar(
              title: const Text('Email Verification'),
              actions: [
                TextButton(
                  onPressed: AppServices.auth.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ExplorerCard(
              padding: const EdgeInsets.fromLTRB(30, 34, 30, 30),
              child: Column(
                children: [
                  if (isAdmin) ...[
                    const ExplorerBrand(),
                    const SizedBox(height: 26),
                  ],
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: ExplorerColors.navySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: ExplorerColors.navy,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isAdmin ? 'Verify Your Email' : 'Email Verification',
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We have sent a verification link to ${widget.user.email ?? 'your email address'}. Open the newest email, tap the link, then return here to activate your account.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 26),
                  ElevatedButton(
                    onPressed: busy ? null : refreshVerificationStatus,
                    child: Text(
                      busy ? 'Checking Verification...' : 'Verify Account',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Didn\'t receive the email?',
                        style: TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      TextButton(
                        onPressed: resendBusy ? null : resendVerificationEmail,
                        child: Text(
                          resendBusy ? 'Sending...' : 'Resend Email',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: AppServices.auth.signOut,
                    icon: const Icon(Icons.logout, size: 17),
                    label: const Text('Use another account'),
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
