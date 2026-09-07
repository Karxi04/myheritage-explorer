part of '../auth_pages.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.role});

  final String role;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      showMessage(context, 'Enter your email and password.', error: true);
      return;
    }
    if (!isValidEmail(email.text)) {
      showMessage(context, 'Enter a valid email address.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final credential = await AppServices.auth.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      var profile = await AppServices.profileForRole(
        credential.user!.uid,
        widget.role,
      );

      // 1. Check if email changed in background (Verified)
      if (profile != null &&
          credential.user!.email != null &&
          profile['email'] != credential.user!.email) {
        await AppServices.profileRefForRole(credential.user!.uid, widget.role)
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
      if (profile != null && profile['emailChangePending'] == true) {
        // Reload to check if verification or revert happened
        await credential.user!.reload();
        final freshUser = AppServices.auth.currentUser!;

        if (freshUser.email != profile['email']) {
          // Case A: Verified. Email updated to new one.
          await AppServices.profileRefForRole(credential.user!.uid, widget.role)
              .update({
            'email': freshUser.email,
            'emailChangePending': false,
            'pendingEmail': FieldValue.delete(),
            'oldEmail': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          profile['email'] = freshUser.email;
          profile['emailChangePending'] = false;
        } else {
          // Case B: Original Email. 
          // They signed in with the original email, but a change is still pending.
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
                  'Would you like to continue waiting for verification, or cancel this request and restore access to your current email?'
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
            // User chose to cancel the request in-app.
            await AppServices.profileRefForRole(credential.user!.uid, widget.role)
                .update({
              'emailChangePending': false,
              'pendingEmail': FieldValue.delete(),
              'oldEmail': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            profile['emailChangePending'] = false;
            // Login proceeds!
          } else {
            // Still pending. Force logout.
            await AppServices.signOut();
            throw Exception(
              'Please verify the link sent to $pending to complete the change, '
              'or cancel the request during your next login attempt.'
            );
          }
        }
      }

      if (profile == null || profile['role'] != widget.role) {
        try {
          final recovered = await AppServices.recoverRoleProfileFromEmail(
            widget.role,
          );
          if (recovered) {
            profile = await AppServices.profileForRole(
              credential.user!.uid,
              widget.role,
            );
          }
        } catch (_) {
          // If Firestore rules block the email lookup, keep the clearer
          // profile-missing message below.
        }
      }

      if (profile == null || profile['role'] != widget.role) {
        final account = await AppServices.currentAccountProfile();
        await AppServices.signOut();

        if (account != null) {
          throw Exception(
            'This email is registered as ${AppServices.labelForRole(account.role)}. '
            'Open the ${AppServices.labelForRole(account.role)} login screen.',
          );
        }

        throw Exception(
          'Firebase login found, but the ${AppServices.labelForRole(widget.role)} '
          'profile is missing in ${AppServices.collectionNameForRole(widget.role)}/'
          '${credential.user!.uid}. Ask the administrator to repair the role profile.',
        );
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

  Future<void> _loginWithGoogle(BuildContext context) async {
    setState(() => busy = true);
    try {
      final userCredential = await AppServices.signInWithGoogle();
      if (!mounted || userCredential == null) return;

      final email = userCredential.user?.email;

      // Check if profile exists for target role
      var profile = await AppServices.profileForRole(
        userCredential.user!.uid,
        widget.role,
      );
      if (!mounted) return;

      if (profile == null) {
        // Check if registered under another role
        final account = await AppServices.currentAccountProfile();
        if (account != null) {
          await AppServices.signOut();
          throw Exception(
            'This Google account is registered as ${AppServices.labelForRole(account.role)}. Please sign in on the ${AppServices.labelForRole(account.role)} login screen.',
          );
        }

        // New Google user -> Navigate to complete profile for widget.role
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RegistrationPage(
                role: widget.role,
                initialName: userCredential.user?.displayName,
                initialEmail: email,
                isGoogle: true,
              ),
            ),
          );
        }
        return;
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

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  String _authMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' =>
        'No Firebase Authentication account exists for this email. If this email appears in Firestore, run the Auth/profile repair script or recreate the Auth account.',
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
    if (widget.role == 'admin') {
      return _buildAdminLogin(context);
    }
    return _buildMobileLogin(context);
  }

  Widget _buildMobileLogin(BuildContext context) {
    final tourist = widget.role == 'traveler';
    final title = tourist ? 'MyHeritage\nExplorer' : 'Vendor Login';
    final subtitle = tourist
        ? 'Sign in to continue your journey.'
        : 'Manage your business profile and reward redemptions.';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(tourist ? 'Tourist Login' : 'Vendor Login'),
      ),
      body: Center(
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
                  if (tourist)
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 30,
                        height: 1.02,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    )
                  else ...[
                    Container(
                      width: 62,
                      height: 62,
                      decoration: const BoxDecoration(
                        color: ExplorerColors.goldSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: ExplorerColors.goldDark,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                        Text(
                          busy
                              ? 'Signing in...'
                              : tourist
                              ? 'Login'
                              : 'Login as Vendor',
                        ),
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
                      onPressed: busy ? null : () => _loginWithGoogle(context),
                      icon: Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 18,
                        width: 18,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.account_circle_outlined, size: 18),
                      ),
                      label: Text(
                        tourist
                            ? 'Sign in with Google'
                            : 'Sign in as Vendor with Google',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ExplorerColors.text,
                        side: const BorderSide(color: ExplorerColors.border),
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
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegistrationPage(role: widget.role),
                      ),
                    ),
                    child: Text(
                      tourist
                          ? 'New to Explorer? Register here'
                          : 'New Vendor? Register your business here',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.companionBackground,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Container(
              padding: const EdgeInsets.fromLTRB(42, 42, 42, 34),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ExplorerColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x16101828),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const ExplorerBrand(),
                  const SizedBox(height: 14),
                  const Text(
                    'Smart Cultural Tourism Platform',
                    style: TextStyle(color: ExplorerColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Administrative Portal',
                    style: TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'admin@myheritage.com',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    obscuringCharacter: '*',
                    onSubmitted: (_) => busy ? null : login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordPage(
                            initialEmail: email.text.trim(),
                            admin: true,
                          ),
                        ),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: busy ? null : login,
                    child: Text(busy ? 'Signing in...' : 'Login as Admin'),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: ExplorerColors.muted,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'SECURE ACCESS ONLY',
                        style: TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Powered by Contemporary Stewardship Engine',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF98A2B3), fontSize: 10),
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
