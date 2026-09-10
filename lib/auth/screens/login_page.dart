part of '../auth_pages.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.role});

  final String? role;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final emailText = email.text.trim();
    final passText = password.text;

    if (emailText.isEmpty || passText.isEmpty) {
      showMessage(context, 'Enter your email and password.', error: true);
      return;
    }
    if (!isValidEmail(emailText)) {
      showMessage(context, 'Enter a valid email address.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final credential = await AppServices.auth.signInWithEmailAndPassword(
        email: emailText,
        password: passText,
      );

      // Determine user's role profile automatically (traveler or vendor)
      var account = await AppServices.currentAccountProfile();

      // If no profile found directly, attempt role profile recovery
      if (account == null) {
        for (final r in const ['traveler', 'vendor']) {
          if (await AppServices.recoverRoleProfileFromEmail(r)) {
            account = await AppServices.currentAccountProfile();
            if (account != null) break;
          }
        }
      }

      if (account == null) {
        await AppServices.signOut();
        throw Exception(
          'Firebase login found, but no profile was found for this account. '
          'Please register a new account or contact support.',
        );
      }

      final profileRole = account.role;
      var profile = account.data;

      if (profileRole == 'admin') {
        await AppServices.signOut();
        throw Exception(
          'Administrator accounts must sign in using the Administrative Web Portal.',
        );
      }

      // 1. Check if email changed in background (Verified)
      if (credential.user!.email != null &&
          profile['email'] != credential.user!.email) {
        await AppServices.profileRefForRole(credential.user!.uid, profileRole)
            .update({
          'email': credential.user!.email,
          'emailChangePending': false,
          'pendingEmail': FieldValue.delete(),
          'oldEmail': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        profile['email'] = credential.user!.email;
        profile['emailChangePending'] = false;
      }

      // 2. Lockout check for pending email change
      if (profile['emailChangePending'] == true) {
        await credential.user!.reload();
        final freshUser = AppServices.auth.currentUser!;

        if (freshUser.email != profile['email']) {
          await AppServices.profileRefForRole(credential.user!.uid, profileRole)
              .update({
            'email': freshUser.email,
            'emailChangePending': false,
            'pendingEmail': FieldValue.delete(),
            'oldEmail': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          profile['email'] = freshUser.email;
        } else {
          final pending = profile['pendingEmail'] ?? 'your new address';
          bool? shouldCancel;
          if (mounted) {
            shouldCancel = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Email Change Pending'),
                content: Text(
                  'A request to change your email to $pending is unresolved.\n\n'
                  'Would you like to continue waiting for verification, or cancel this request and restore access to your current email?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Wait for Verification'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cancel Request'),
                  ),
                ],
              ),
            );
          }

          if (shouldCancel == true) {
            await AppServices.profileRefForRole(credential.user!.uid, profileRole)
                .update({
              'emailChangePending': false,
              'pendingEmail': FieldValue.delete(),
              'oldEmail': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            await AppServices.signOut();
            throw Exception(
              'Please verify the link sent to $pending to complete the change, '
              'or cancel the request during your next login attempt.',
            );
          }
        }
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showMessage(context, _authMessage(e), error: true);
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

  Future<void> _loginWithGoogle() async {
    setState(() => busy = true);
    try {
      final userCredential = await AppServices.signInWithGoogle();
      if (!mounted || userCredential == null) return;

      // Check if profile exists
      var account = await AppServices.currentAccountProfile();
      if (!mounted) return;

      if (account == null) {
        await AppServices.signOut();
        if (!mounted) return;
        showMessage(
          context,
          'No account found for this Google email. Please register first.',
          error: true,
        );
        return;
      }

      if (account.role == 'admin') {
        await AppServices.signOut();
        throw Exception(
          'Administrator accounts must sign in using the Administrative Web Portal.',
        );
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
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

  Future<void> _registerWithGoogle(String targetRole) async {
    setState(() => busy = true);
    AppServices.pendingGoogleRole = targetRole;
    try {
      final userCredential = await AppServices.signInWithGoogle();
      if (!mounted || userCredential == null) {
        AppServices.pendingGoogleRole = null;
        return;
      }

      final email = userCredential.user?.email;

      // 1. Check if a profile already exists for this UID
      final profile = await AppServices.currentAccountProfile();
      if (!mounted) return;

      if (profile != null) {
        AppServices.pendingGoogleRole = null;
        showMessage(
          context,
          'Welcome back! You are already registered as a ${AppServices.labelForRole(profile.role)}.',
        );
        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }

      // 2. Double check if this email is already taken by another account
      if (email != null) {
        final existingProfile = await AppServices.findProfileByEmail(email);
        if (!mounted) return;

        if (existingProfile != null) {
          AppServices.pendingGoogleRole = null;
          await AppServices.signOut();
          if (!mounted) return;
          showMessage(
            context,
            'The email $email is already in use by a ${AppServices.labelForRole(existingProfile['role'] ?? 'user')} account. Please sign in with email/password.',
            error: true,
          );
          return;
        }
      }

      // 3. New user, proceed to complete registration for targetRole
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationPage(
              role: targetRole,
              initialName: userCredential.user?.displayName,
              initialEmail: email,
              isGoogle: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = 'Google Registration Failed';
        if (e.toString().contains('account-exists-with-different-credential')) {
          message =
              'This email is already associated with a password account. Please log in with email/password first.';
        } else {
          message = '$message: $e';
        }
        showMessage(context, message, error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _handleRegisterTap() async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Join MyHeritage Explorer',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ExplorerColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select your account type and preferred registration method.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ExplorerColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // TOURIST REGISTRATION CARD
              _buildRoleRegistrationCard(
                title: 'Tourist',
                subtitle: 'Discover cultural sites, itineraries, and travel safely.',
                icon: Icons.explore,
                iconBg: const Color(0xFFE0F2FE),
                iconFg: ExplorerColors.navy,
                accentColor: ExplorerColors.navy,
                onEmailRegister: () {
                  Navigator.pop(sheetContext);
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegistrationPage(role: 'traveler'),
                      ),
                    );
                  }
                },
                onGoogleRegister: () {
                  Navigator.pop(sheetContext);
                  _registerWithGoogle('traveler');
                },
              ),

              const SizedBox(height: 16),

              // VENDOR REGISTRATION CARD
              _buildRoleRegistrationCard(
                title: 'Vendor',
                subtitle: 'Manage your business profile, offer vouchers, and scan rewards.',
                icon: Icons.storefront,
                iconBg: ExplorerColors.goldSoft,
                iconFg: ExplorerColors.goldDark,
                accentColor: ExplorerColors.goldDark,
                onEmailRegister: () {
                  Navigator.pop(sheetContext);
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegistrationPage(role: 'vendor'),
                      ),
                    );
                  }
                },
                onGoogleRegister: () {
                  Navigator.pop(sheetContext);
                  _registerWithGoogle('vendor');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleRegistrationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required Color accentColor,
    required VoidCallback onEmailRegister,
    required VoidCallback onGoogleRegister,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ExplorerColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: iconBg,
                foregroundColor: iconFg,
                child: Icon(icon, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEmailRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.mail_outline, size: 16),
                  label: const Text(
                    'Email Register',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGoogleRegister,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Image.network(
                    'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                    height: 16,
                    width: 16,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.account_circle_outlined, size: 16),
                  ),
                  label: const Text(
                    'Google Register',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _authMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' =>
        'No Firebase Authentication account exists for this email. Please check your spelling or register a new account.',
      'wrong-password' || 'invalid-credential' =>
        'The email or password is incorrect. Try Forgot Password if this is your account.',
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This login account has been disabled.',
      _ =>
        e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'Unable to sign in.',
    };
  }

  @override
  Widget build(BuildContext context) {
    const title = 'MyHeritage\nExplorer';
    const subtitle = 'Sign in to continue your journey or manage your business.';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 410),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ExplorerColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F101828),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 30,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Email Address',
                        style: TextStyle(
                          color: ExplorerColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'explorer@example.com',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Password',
                            style: TextStyle(
                              color: ExplorerColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordPage(
                                initialEmail: email.text.trim(),
                                admin: false,
                              ),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: password,
                      obscureText: obscure,
                      obscuringCharacter: '*',
                      onSubmitted: (_) => busy ? null : login(),
                      decoration: InputDecoration(
                        hintText: '********',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: busy ? null : login,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(busy ? 'Signing in...' : 'Sign In'),
                          if (!busy) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 17),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : _loginWithGoogle,
                        icon: Image.network(
                          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                          height: 18,
                          width: 18,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.account_circle_outlined, size: 18),
                        ),
                        label: const Text('Sign in with Google'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ExplorerColors.navy,
                          side: const BorderSide(color: ExplorerColors.navy),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: _handleRegisterTap,
                      child: const Text(
                        'New to Explorer? Register here',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
