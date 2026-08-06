part of '../auth_gate.dart';

class AccountDisabledPage extends StatelessWidget {
  const AccountDisabledPage({super.key});
  @override
  Widget build(BuildContext context) => PlatformRestrictionPage(
        title: 'Account unavailable',
        message: 'This account is inactive or suspended. Contact the administrator for assistance.',
        showSignOut: true,
      );
}

