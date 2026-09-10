part of '../auth_pages.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, this.role, this.timedOut = false});

  final String? role;
  final bool timedOut;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.timedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTimeoutNoticeDialog();
      });
    }
  }

  void _showTimeoutNoticeDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              'Session Timeout',
              style: TextStyle(
                color: ExplorerColors.navy,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Your session has timed out due to inactivity. Please click OK to log in again.',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ExplorerColors.navy,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> adminLogin() async {
    final emailText = email.text.trim();
    final passText = password.text;

    if (emailText.isEmpty || passText.isEmpty) {
      showMessage(context, 'Enter your administrator email and password.', error: true);
      return;
    }
    if (!isValidEmail(emailText)) {
      showMessage(context, 'Enter a valid email address.', error: true);
      return;
    }

    setState(() => busy = true);
    try {
      // 1. Unlock session BEFORE signing in so AuthGate stream doesn't reject new login
      await AdminSessionManager.updateActivity();

      final credential = await AppServices.auth.signInWithEmailAndPassword(
        email: emailText,
        password: passText,
      );

      final uid = credential.user!.uid;

      // 2. Fetch admin profile directly from admins collection
      var adminData = await AppServices.profileForRole(uid, 'admin');

      // 3. Attempt admin profile recovery if missing
      if (adminData == null) {
        final recovered = await AppServices.recoverRoleProfileFromEmail('admin');
        if (recovered) {
          adminData = await AppServices.profileForRole(uid, 'admin');
        }
      }

      // 4. Verify administrator role
      if (adminData == null || adminData['role'] != 'admin') {
        await AdminSessionManager.lockSession();
        await AppServices.signOut();
        throw Exception(
          'This account does not have administrator privileges. Please sign in with an administrator account.',
        );
      }

      // 5. Check status
      final status = '${adminData['status'] ?? 'active'}'.toLowerCase();
      if (status == 'disabled' || status == 'suspended') {
        await AdminSessionManager.lockSession();
        await AppServices.signOut();
        throw Exception('This administrator account has been disabled.');
      }

      // 6. Refresh active timestamp
      await AdminSessionManager.updateActivity();

      if (mounted) {
        try {
          if (Navigator.canPop(context)) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        } catch (_) {}
      }
    } on FirebaseAuthException catch (e) {
      await AdminSessionManager.lockSession();
      if (mounted) {
        showMessage(context, _authMessage(e), error: true);
      }
    } catch (e) {
      await AdminSessionManager.lockSession();
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

  String _authMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' =>
        'No administrator account exists for this email. Please check your credentials.',
      'wrong-password' || 'invalid-credential' =>
        'Incorrect administrator email or password.',
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This administrator account has been disabled.',
      _ =>
        e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'Unable to sign in as administrator.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.companionBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                    onSubmitted: (_) => busy ? null : adminLogin(),
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
                    onPressed: busy ? null : adminLogin,
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
