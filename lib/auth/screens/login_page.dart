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

      // Determine user's role profile automatically
      final targetRole = widget.role;
      AccountProfile? account;

      if (targetRole != null) {
        final profileData = await AppServices.profileForRole(
          credential.user!.uid,
          targetRole,
        );
        if (profileData != null) {
          account = AccountProfile(role: targetRole, data: profileData);
        }
      }

      account ??= await AppServices.currentAccountProfile();

      // If no profile found directly, attempt role profile recovery
      if (account == null) {
        final rolesToTry = targetRole != null 
            ? [targetRole, 'traveler', 'vendor', 'admin']
            : ['traveler', 'vendor', 'admin'];
        for (final r in rolesToTry) {
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

      final email = userCredential.user?.email;

      // Check if profile exists for target role or any role
      AccountProfile? account;
      if (widget.role != null) {
        final profileData = await AppServices.profileForRole(
          userCredential.user!.uid,
          widget.role!,
        );
        if (profileData != null) {
          account = AccountProfile(role: widget.role!, data: profileData);
        }
      }
      account ??= await AppServices.currentAccountProfile();

      if (!mounted) return;

      if (!mounted) return;
      if (account == null) {
        if (email != null) {
          final existing = await AppServices.findProfileByEmail(email);
          if (!mounted) return;
          if (existing != null) {
            await AppServices.signOut();
            final roleLabel = AppServices.labelForRole(existing['role'] ?? 'user');
            throw Exception(
              'The email $email is registered as a $roleLabel. Please sign in with email/password.',
            );
          }
        }

        if (!mounted) return;

        // New Google user -> Ask whether Tourist or Vendor
        final selectedRole = widget.role ?? await _promptRoleSelection(
          context,
          title: 'Complete Google Sign In',
          message: 'Welcome! Please select your account type to finish setting up your account.',
        );

        if (!mounted || selectedRole == null) {
          await AppServices.signOut();
          return;
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RegistrationPage(
                role: selectedRole,
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

  Future<String?> _promptRoleSelection(
    BuildContext context, {
    String title = 'Choose Account Type',
    String message = 'Select how you want to use MyHeritage Explorer.',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ExplorerColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ExplorerColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: ExplorerColors.border),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.explore_outlined, color: ExplorerColors.navy),
                ),
                title: const Text(
                  'I am a Tourist',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Discover cultural sites, itineraries, and travel safely.'),
                onTap: () => Navigator.pop(sheetContext, 'traveler'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: ExplorerColors.border),
                ),
                leading: const CircleAvatar(
                  backgroundColor: ExplorerColors.goldSoft,
                  child: Icon(Icons.storefront_outlined, color: ExplorerColors.goldDark),
                ),
                title: const Text(
                  'I am a Vendor',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Manage your business, offer vouchers, and scan rewards.'),
                onTap: () => Navigator.pop(sheetContext, 'vendor'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegisterTap() async {
    final selectedRole = await _promptRoleSelection(
      context,
      title: 'Join MyHeritage Explorer',
      message: 'Select whether you want to register as a Tourist or a Vendor.',
    );

    if (!mounted) return;
    if (selectedRole != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationPage(role: selectedRole),
        ),
      );
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
    if (widget.role == 'admin') {
      return _buildAdminLogin(context);
    }
    return _buildMobileLogin(context);
  }

  Widget _buildMobileLogin(BuildContext context) {
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

  Widget _buildAdminLogin(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.companionBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Admin Portal'),
      ),
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
