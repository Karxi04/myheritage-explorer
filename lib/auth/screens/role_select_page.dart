
part of '../auth_pages.dart';

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

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
        ],
      ),
    );
  }
}
