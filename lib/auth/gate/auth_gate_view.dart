part of '../auth_gate.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashComplete = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() => _splashComplete = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashComplete) {
      return const AppSplashScreen();
    }

    return StreamBuilder<User?>(
      stream: AppServices.auth.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _ProfileLoadingPage(
            message: 'Checking authentication...',
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          MobileNotificationService.instance.clearPendingPayload();
          return const LoginPage();
        }

        return _ResolvedRoleGate(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.navy,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      size: 52,
                      color: ExplorerColors.navy,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'MyHeritage Explorer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Smart Cultural Tourism Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .3,
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
}

class _ResolvedRoleGate extends StatefulWidget {
  const _ResolvedRoleGate({super.key, required this.user});

  final User user;

  @override
  State<_ResolvedRoleGate> createState() => _ResolvedRoleGateState();
}

class _ResolvedRoleGateState extends State<_ResolvedRoleGate> {
  late final Stream<AccountProfile?> _profileStream;
  bool? _isPinSet;
  bool _checkingPin = false;

  @override
  void initState() {
    super.initState();
    _profileStream = AppServices.accountProfileStream(widget.user.uid);
  }

  Future<void> _checkPinOnce() async {
    if (_isPinSet != null || _checkingPin) return;
    _checkingPin = true;
    final isSet = await PinService.isPinSet();
    if (mounted) {
      setState(() {
        _isPinSet = isSet;
        _checkingPin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AccountProfile?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const _ProfileLoadingPage(
            message: 'Loading account profile...',
          );
        }

        if (profileSnapshot.hasError) {
          return _ProfileLoadErrorPage(
            message: '${profileSnapshot.error}'.replaceFirst('Exception: ', ''),
            onRetry: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AuthGate()),
              );
            },
          );
        }

        final account = profileSnapshot.data;
        if (account == null) {
          // If no profile exists, check if user is a Google user who needs to complete setup
          final isGoogle = widget.user.providerData.any((p) => p.providerId == 'google.com');
          if (isGoogle) {
            return _GoogleRoleSetupGate(user: widget.user);
          }
          return MissingProfilePage(uid: widget.user.uid);
        }

        final profile = account.data;
        final role = account.role;

        // 1. Status Check (Inactive/Suspended)
        final String status = profile['status'] ?? 'active';
        if (status == 'inactive') {
          return DeactivatedAccountReactivationPage(
            user: widget.user,
            profile: profile,
            role: role,
          );
        } else if (status == 'suspended' || status == 'disabled') {
          return const AccountDisabledPage();
        }

        // 1.5 Pending Warning Check (One-Time Warning Notice)
        if (profile['hasPendingWarning'] == true) {
          return _UserPendingWarningGate(
            user: widget.user,
            profile: profile,
            role: role,
          );
        }

        // 2. Email Verification Check
        // Non-admins must verify their email before proceeding
        if (profile['emailVerified'] != true && role != 'admin') {
          return EmailVerificationPage(user: widget.user);
        }

        // 3. Security Questions Check
        // Non-admins must answer security questions before setup PIN / entering portal
        final secQuestions = profile['securityQuestions'];
        final hasSecurityQuestions = secQuestions is List && secQuestions.isNotEmpty;
        if (!hasSecurityQuestions && role != 'admin') {
          return _SecurityQuestionsSetupGate(
            uid: widget.user.uid,
            role: role,
          );
        }

        // 4. Security Check (PIN Security)
        // If they haven't authorized this session, we either prompt for PIN or ask to setup
        if (!PinService.isSessionAuthorized) {
          if (_isPinSet == null) {
            _checkPinOnce();
            return const _ProfileLoadingPage(message: 'Checking security...');
          }

          // If a PIN is set, show the entry page
          if (_isPinSet == true) {
            return PinEntryPage(
              onAuthorized: () {
                setState(() {}); // Rebuild to proceed to Shell
              },
            );
          }

          // If no PIN is set, prompt for setup (for non-admins)
          if (role != 'admin') {
            return _PinSecurityGate(
              onDecision: () {
                setState(() {
                  _isPinSet = null; // Force re-check pin status after decision
                }); 
              },
            );
          }
        }

        // 4. Final Shell Route
        return _routeShell(context, role: role, profile: profile);
      },
    );
  }

  Widget _routeShell(
    BuildContext context, {
    required String role,
    required Map<String, dynamic> profile,
  }) {
    final profileRole = '${profile['role'] ?? ''}'.trim().toLowerCase();
    if (profileRole != role) {
      return _ProfileLoadErrorPage(
        message:
            'The $role profile for this account is missing role == $role. '
            'Check the ${role}s/${widget.user.uid} document.',
        onRetry: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AuthGate()),
          );
        },
      );
    }

    if (profile['status'] != 'active') {
      return const AccountDisabledPage();
    }

    if (!widget.user.emailVerified && role != 'admin') {
      return EmailVerificationPage(user: widget.user);
    }

    if (role != 'traveler') {
      MobileNotificationService.instance.clearPendingPayload();
    }
    if (role == 'admin') {
      if (!kIsWeb) {
        return const PlatformRestrictionPage(
          title: 'Admin website only',
          message:
              'Open the web application to access the administrator portal.',
        );
      }
      return AdminShell(profile: profile);
    }

    if (kIsWeb) {
      return const PlatformRestrictionPage(
        title: 'Mobile application only',
        message:
            'Traveler and vendor accounts must use the mobile application.',
      );
    }

    if (role == 'vendor') {
      if (profile['vendorStatus'] != 'verified') {
        return VendorPendingPage(profile: profile);
      }
      return VendorShell(profile: profile);
    }

    if (role == 'traveler') {
      return TravelerShell(profile: profile);
    }

    return _ProfileLoadErrorPage(
      message: 'Unsupported account role: $role',
      onRetry: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      },
    );
  }
}

class _GoogleRoleSetupGate extends StatelessWidget {
  const _GoogleRoleSetupGate({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                children: [
                  const ExplorerBrand(),
                  const SizedBox(height: 32),
                  const Text(
                    'Complete Your Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome, ${user.displayName ?? 'Explorer'}! Please choose your role to finish setting up your account.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ExplorerColors.muted),
                  ),
                  const SizedBox(height: 40),
                  _RoleSelectionButton(
                    title: 'I am a Tourist',
                    icon: Icons.explore_outlined,
                    onPressed: () => _navigateToRegistration(context, 'traveler'),
                  ),
                  const SizedBox(height: 16),
                  _RoleSelectionButton(
                    title: 'I am a Vendor',
                    icon: Icons.storefront_outlined,
                    onPressed: () => _navigateToRegistration(context, 'vendor'),
                  ),
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        // Delete the Firebase Auth user to avoid ghost accounts 
                        // without a Firestore profile.
                        await AppServices.deleteCurrentUser();
                      } catch (_) {
                        // If deletion fails, we still want to sign out.
                      }
                      await AppServices.signOut();
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Cancel & Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToRegistration(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationPage(
          role: role,
          initialName: user.displayName,
          initialEmail: user.email,
          isGoogle: true,
        ),
      ),
    );
  }
}

class _RoleSelectionButton extends StatelessWidget {
  const _RoleSelectionButton({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _PinSecurityGate extends StatefulWidget {
  const _PinSecurityGate({required this.onDecision});
  final VoidCallback onDecision;

  @override
  State<_PinSecurityGate> createState() => _PinSecurityGateState();
}

class _PinSecurityGateState extends State<_PinSecurityGate> {
  bool _setupStarted = false;
  bool _showingPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPrompt());
  }

  void _showPrompt() async {
    if (!mounted || _showingPrompt) return;
    _showingPrompt = true;

    // Add a very small delay to allow any pending transitions to finish
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) {
      _showingPrompt = false;
      return;
    }

    final decision = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Secure Your Account?'),
        content: const Text(
          'Would you like to set up a 6-digit security PIN for this device? '
          'This adds an extra layer of protection to your profile.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Setup PIN'),
          ),
        ],
      ),
    );

    _showingPrompt = false;
    if (!mounted) return;

    if (decision == true) {
      setState(() => _setupStarted = true);
    } else if (decision == false) {
      // User explicitly clicked "Maybe Later"
      PinService.authorizeSession();
      widget.onDecision();
    } else {
      // Dialog was dismissed somehow without a decision 
      // (shouldn't happen with barrierDismissible: false, but for safety)
      _showPrompt(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_setupStarted) {
      return PinSetupPage(
        onSetupComplete: widget.onDecision,
        onCancel: () {
          setState(() => _setupStarted = false);
          WidgetsBinding.instance.addPostFrameCallback((_) => _showPrompt());
        },
      );
    }

    if (!_showingPrompt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPrompt());
    }

    return const _ProfileLoadingPage(message: 'Securing account...');
  }
}

class _ProfileLoadingPage extends StatelessWidget {
  const _ProfileLoadingPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLoadErrorPage extends StatelessWidget {
  const _ProfileLoadErrorPage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load account profile',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        OutlinedButton.icon(
                          onPressed: AppServices.signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                        ),
                      ],
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

class _SecurityQuestionsSetupGate extends StatefulWidget {
  const _SecurityQuestionsSetupGate({
    required this.uid,
    required this.role,
  });

  final String uid;
  final String role;

  @override
  State<_SecurityQuestionsSetupGate> createState() =>
      _SecurityQuestionsSetupGateState();
}

class _SecurityQuestionsSetupGateState
    extends State<_SecurityQuestionsSetupGate> {
  final securityQuestions = [
    'What was the name of your first pet?',
    'In what city were you born?',
    'What was your mother\'s maiden name?',
    'What was the make of your first car?',
    'What was the name of your elementary school?',
    'What is your favorite book?',
  ];
  String? q1;
  String? q2;
  final a1 = TextEditingController();
  final a2 = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    a1.dispose();
    a2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final answer1 = a1.text.trim();
    final answer2 = a2.text.trim();

    if (q1 == null || q2 == null || answer1.isEmpty || answer2.isEmpty) {
      showMessage(context, 'Please answer both security questions.', error: true);
      return;
    }
    if (q1 == q2) {
      showMessage(context, 'Please select two different questions.', error: true);
      return;
    }
    if (answer1.length < 5 || answer2.length < 5) {
      showMessage(context, 'Each answer must be at least 5 characters long.', error: true);
      return;
    }

    setState(() => busy = true);
    try {
      final questionsData = [
        {'question': q1!, 'answer': answer1.toLowerCase()},
        {'question': q2!, 'answer': answer2.toLowerCase()},
      ];

      await AppServices.saveSecurityQuestions(
        uid: widget.uid,
        role: widget.role,
        securityQuestions: questionsData,
      );
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.security, size: 52, color: ExplorerColors.navy),
                      const SizedBox(height: 14),
                      const Text(
                        'Set Up Security Questions',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'These questions will help you recover your account if you ever lose access.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ExplorerColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: q1,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: const InputDecoration(
                          labelText: 'Question 1',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: securityQuestions
                            .where((q) => q != q2)
                            .map((q) => DropdownMenuItem(
                                value: q,
                                child: Text(
                                  q,
                                  style: const TextStyle(fontSize: 14),
                                )))
                            .toList(),
                        onChanged: (v) => setState(() => q1 = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: a1,
                        decoration: const InputDecoration(
                          labelText: 'Answer 1',
                          hintText: 'At least 5 characters',
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: q2,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: const InputDecoration(
                          labelText: 'Question 2',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: securityQuestions
                            .where((q) => q != q1)
                            .map((q) => DropdownMenuItem(
                                value: q,
                                child: Text(
                                  q,
                                  style: const TextStyle(fontSize: 14),
                                )))
                            .toList(),
                        onChanged: (v) => setState(() => q2 = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: a2,
                        decoration: const InputDecoration(
                          labelText: 'Answer 2',
                          hintText: 'At least 5 characters',
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: busy ? null : _submit,
                        child: Text(busy ? 'Saving...' : 'Save & Continue'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: AppServices.signOut,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserPendingWarningGate extends StatefulWidget {
  const _UserPendingWarningGate({
    required this.user,
    required this.profile,
    required this.role,
  });

  final User user;
  final Map<String, dynamic> profile;
  final String role;

  @override
  State<_UserPendingWarningGate> createState() =>
      __UserPendingWarningGateState();
}

class __UserPendingWarningGateState extends State<_UserPendingWarningGate> {
  bool _dismissing = false;

  Future<void> _acknowledgeWarning() async {
    setState(() => _dismissing = true);
    try {
      final ref = AppServices.profileRefForRole(widget.user.uid, widget.role);
      await ref.update({
        'hasPendingWarning': false,
        'warningMessage': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Error acknowledging warning: $e', error: true);
        setState(() => _dismissing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final warningMsg = '${widget.profile['warningMessage'] ?? 'You have received an official warning notice from the moderation team.'}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: AppServices.signOut,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ExplorerCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 38,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Administrator Warning Notice',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account has received a formal warning notice regarding community guidelines.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.report_problem_outlined,
                                size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Warning Details',
                              style: TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          warningMsg,
                          style: const TextStyle(
                            color: Color(0xFF5D4037),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ExplorerColors.navy,
                      ),
                      onPressed: _dismissing ? null : _acknowledgeWarning,
                      icon: _dismissing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(_dismissing
                          ? 'Updating...'
                          : 'I Understand and Acknowledge'),
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
}
