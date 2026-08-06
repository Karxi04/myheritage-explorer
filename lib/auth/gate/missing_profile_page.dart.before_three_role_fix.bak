part of '../auth_gate.dart';

class MissingProfilePage extends StatelessWidget {
  const MissingProfilePage({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: ExplorerCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ExplorerBrand(),
                    const SizedBox(height: 26),
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: ExplorerColors.warningSoft,
                      foregroundColor: ExplorerColors.goldDark,
                      child: Icon(Icons.person_search_outlined, size: 36),
                    ),
                    const SizedBox(height: 17),
                    const Text(
                      'Profile Setup Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your sign-in account exists, but the system profile is missing. Contact the administrator and provide the UID below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ExplorerColors.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ExplorerColors.subtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SelectableText(
                        'UID: $uid',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ExplorerColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: AppServices.auth.signOut,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign out'),
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
