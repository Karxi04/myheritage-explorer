part of '../auth_pages.dart';

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const LoginPage(role: 'admin');
    }
    return const LoginPage();
  }
}
