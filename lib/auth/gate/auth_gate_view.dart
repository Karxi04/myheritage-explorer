part of '../auth_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AppServices.auth.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _ProfileLoadingPage(
            message: 'Checking authentication...',
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const RoleSelectPage();

        return _ResolvedRoleGate(key: ValueKey(user.uid), user: user);
      },
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
  late Future<AccountProfile?> profileFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    profileFuture = AppServices.currentAccountProfile().timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw Exception(
        'The role profile took too long to load. '
        'Check Firestore rules and the account role document.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountProfile?>(
      future: profileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState != ConnectionState.done) {
          return const _ProfileLoadingPage(
            message: 'Loading account profile...',
          );
        }

        if (profileSnapshot.hasError) {
          return _ProfileLoadErrorPage(
            message: '${profileSnapshot.error}'.replaceFirst('Exception: ', ''),
            onRetry: () => setState(_reload),
          );
        }

        final account = profileSnapshot.data;
        if (account == null) {
          return MissingProfilePage(uid: widget.user.uid);
        }

        final reference = AppServices.profileRefForRole(
          widget.user.uid,
          account.role,
        );

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: reference.snapshots(),
          builder: (context, liveSnapshot) {
            if (liveSnapshot.hasError) {
              return _ProfileLoadErrorPage(
                message: '${liveSnapshot.error}'.replaceFirst(
                  'Exception: ',
                  '',
                ),
                onRetry: () => setState(_reload),
              );
            }

            if (!liveSnapshot.hasData) {
              return const _ProfileLoadingPage(
                message: 'Opening your account...',
              );
            }

            final profile = liveSnapshot.data!.data();
            if (profile == null) {
              return MissingProfilePage(uid: widget.user.uid);
            }

            return _routeProfile(context, role: account.role, profile: profile);
          },
        );
      },
    );
  }

  Widget _routeProfile(
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
        onRetry: () => setState(_reload),
      );
    }

    if (profile['status'] != 'active') {
      return const AccountDisabledPage();
    }

    if (!widget.user.emailVerified && role != 'admin') {
      return EmailVerificationPage(user: widget.user);
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
      onRetry: () => setState(_reload),
    );
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
                          onPressed: AppServices.auth.signOut,
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
