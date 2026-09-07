
part of '../auth_pages.dart';

class RoleSelectPage extends StatefulWidget {
  const RoleSelectPage({super.key});

  @override
  State<RoleSelectPage> createState() => _RoleSelectPageState();
}

class _RoleSelectPageState extends State<RoleSelectPage> {
  bool busy = false;

  Future<void> _registerWithGoogle(
    BuildContext context, {
    required String targetRole,
  }) async {
    setState(() => busy = true);
    try {
      final userCredential = await AppServices.signInWithGoogle();
      if (!mounted || userCredential == null) return;

      final email = userCredential.user?.email;

      // 1. Check if a profile already exists for this UID
      final profile = await AppServices.currentAccountProfile();
      if (!mounted) return;

      if (profile != null) {
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
          await AppServices.signOut();
          if (!mounted) return;
          showMessage(
            context,
            'The email $email is already in use by a ${AppServices.labelForRole(existingProfile['role'] ?? 'user')} account. Please use the Login screen.',
            error: true,
          );
          return;
        }
      }

      // 3. New user, proceed to complete profile for targetRole
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

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const LoginPage(role: 'admin');
    }

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const ExplorerPageHeader(
              title: 'MyHeritage Explorer',
              leading: Icon(
                Icons.account_balance_outlined,
                color: ExplorerColors.navy,
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 38, 18, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      children: [
                        const Text(
                          'Select Your Role',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 34,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Welcome to MyHeritage Explorer. Please select how you intend to use the platform to customize your experience.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _RoleSelectionCard(
                          title: 'Tourist',
                          description:
                              'Plan trips, complete cultural experiences, earn rewards, and stay safe during travel. Discover the rich heritage tailored to your journey.',
                          icon: Icons.explore,
                          iconBackground: ExplorerColors.navy,
                          iconForeground: const Color(0xFF8FB2E8),
                          accent: ExplorerColors.navy,
                          loginLabel: 'Tourist Login',
                          registerLabel: 'Tourist Register',
                          onLogin: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(role: 'traveler'),
                            ),
                          ),
                          onRegister: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RegistrationPage(role: 'traveler'),
                            ),
                          ),
                          onGoogleRegister: () =>
                              _registerWithGoogle(context, targetRole: 'traveler'),
                        ),
                        const SizedBox(height: 24),
                        _RoleSelectionCard(
                          title: 'Vendor',
                          description:
                              'Manage your business profile, connect with tourists, offer services, and participate in cultural events to grow your local presence.',
                          icon: Icons.storefront,
                          iconBackground: const Color(0xFFFFD181),
                          iconForeground: ExplorerColors.goldDark,
                          accent: ExplorerColors.goldDark,
                          loginLabel: 'Vendor Login',
                          registerLabel: 'Vendor Register',
                          onLogin: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(role: 'vendor'),
                            ),
                          ),
                          onRegister: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RegistrationPage(role: 'vendor'),
                            ),
                          ),
                          onGoogleRegister: () =>
                              _registerWithGoogle(context, targetRole: 'vendor'),
                        ),
                      ],
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

class _RoleSelectionCard extends StatelessWidget {
  const _RoleSelectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.accent,
    required this.loginLabel,
    required this.registerLabel,
    required this.onLogin,
    required this.onRegister,
    this.onGoogleRegister,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final Color accent;
  final String loginLabel;
  final String registerLabel;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback? onGoogleRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 38, 26, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ExplorerColors.border, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconForeground, size: 34),
          ),
          const SizedBox(height: 25),
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ExplorerColors.muted,
              fontSize: 15,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: const StadiumBorder(),
              ),
              child: Text(loginLabel),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRegister,
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
                shape: const StadiumBorder(),
              ),
              child: Text(registerLabel),
            ),
          ),
          if (onGoogleRegister != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onGoogleRegister,
                icon: Image.network(
                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                  height: 18,
                  width: 18,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.account_circle_outlined, size: 18),
                ),
                label: const Text('Register with Google'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ExplorerColors.text,
                  side: const BorderSide(color: ExplorerColors.border),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
