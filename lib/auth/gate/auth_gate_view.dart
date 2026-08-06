part of '../auth_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // userChanges() also emits after currentUser.reload(), so the UI can
      // immediately leave the email-verification page after verification.
      stream: AppServices.auth.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const RoleSelectPage();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: AppServices.userRef(user.uid).snapshots(),
          builder: (context, profileSnapshot) {
            if (!profileSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data!.data();
            if (profile == null) {
              return MissingProfilePage(uid: user.uid);
            }

            if (profile['status'] != 'active') {
              return const AccountDisabledPage();
            }

            final role = profile['role'] as String? ?? 'traveler';

            if (!user.emailVerified && role != 'admin') {
              return EmailVerificationPage(user: user);
            }

            if (role == 'admin') {
              if (!kIsWeb) {
                return const PlatformRestrictionPage(
                  title: 'Admin website only',
                  message:
                  'Open the Flutter Web version to access the administrator portal.',
                );
              }
              return AdminShell(profile: profile);
            }

            if (kIsWeb) {
              return const PlatformRestrictionPage(
                title: 'Mobile application only',
                message:
                'Traveler and vendor accounts must use the Android or iOS mobile application.',
              );
            }

            if (role == 'vendor') {
              if (profile['vendorStatus'] != 'verified') {
                return VendorPendingPage(profile: profile);
              }
              return VendorShell(profile: profile);
            }

            return TravelerShell(profile: profile);
          },
        );
      },
    );
  }
}
