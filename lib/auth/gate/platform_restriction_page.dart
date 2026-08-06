part of '../auth_gate.dart';

class PlatformRestrictionPage extends StatelessWidget {
  const PlatformRestrictionPage({
    super.key,
    required this.title,
    required this.message,
    this.showSignOut = true,
  });

  final String title;
  final String message;
  final bool showSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ExplorerCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExplorerBrand(),
                    const SizedBox(height: 28),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: ExplorerColors.navySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.devices_outlined,
                        color: ExplorerColors.navy,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        height: 1.5,
                      ),
                    ),
                    if (showSignOut) ...[
                      const SizedBox(height: 22),
                      OutlinedButton.icon(
                        onPressed: AppServices.auth.signOut,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sign out'),
                      ),
                    ],
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
