part of '../auth_pages.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool busy = false;
  bool hideCurrent = true;
  bool hideNew = true;
  bool hideConfirm = true;

  @override
  void dispose() {
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> changePassword() async {
    if (newPassword.text.length < 8) {
      showMessage(
        context,
        'Use at least 8 characters for the new password.',
        error: true,
      );
      return;
    }
    if (newPassword.text != confirmPassword.text) {
      showMessage(context, 'New passwords do not match.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      await AppServices.reauthenticate(currentPassword.text);
      await AppServices.auth.currentUser!.updatePassword(newPassword.text);
      if (mounted) {
        showMessage(context, 'Password changed successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Change Password',
              subtitle: 'Keep your MyHeritage Explorer account secure.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ExplorerCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: ExplorerColors.navySoft,
                            foregroundColor: ExplorerColors.navy,
                            child: Icon(Icons.lock_reset_outlined),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Update your password',
                            style: TextStyle(
                              color: ExplorerColors.navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Use at least 8 characters and avoid reusing an old password.',
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: currentPassword,
                            obscureText: hideCurrent,
                            decoration: InputDecoration(
                              labelText: 'Current password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => hideCurrent = !hideCurrent),
                                icon: Icon(
                                  hideCurrent
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: newPassword,
                            obscureText: hideNew,
                            decoration: InputDecoration(
                              labelText: 'New password',
                              prefixIcon: const Icon(Icons.key_outlined),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => hideNew = !hideNew),
                                icon: Icon(
                                  hideNew
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: confirmPassword,
                            obscureText: hideConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirm new password',
                              prefixIcon: const Icon(Icons.verified_user_outlined),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => hideConfirm = !hideConfirm),
                                icon: Icon(
                                  hideConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: busy ? null : changePassword,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            icon: const Icon(Icons.security_outlined),
                            label: Text(
                              busy ? 'Updating Password...' : 'Change Password',
                            ),
                          ),
                        ],
                      ),
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
