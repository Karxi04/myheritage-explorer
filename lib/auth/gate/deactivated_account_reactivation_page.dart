part of '../auth_gate.dart';

class DeactivatedAccountReactivationPage extends StatefulWidget {
  const DeactivatedAccountReactivationPage({
    super.key,
    required this.user,
    required this.profile,
    required this.role,
  });

  final User user;
  final Map<String, dynamic> profile;
  final String role;

  @override
  State<DeactivatedAccountReactivationPage> createState() =>
      _DeactivatedAccountReactivationPageState();
}

class _DeactivatedAccountReactivationPageState
    extends State<DeactivatedAccountReactivationPage> {
  bool _busy = false;

  Future<void> _reactivateAccount() async {
    setState(() => _busy = true);
    try {
      await AppServices.reactivateOwnAccount();
      if (mounted) {
        showMessage(
            context, 'Welcome back! Your account has been reactivated.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Failed to reactivate account: $e', error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${widget.profile['displayName'] ?? widget.profile['businessName'] ?? widget.user.displayName ?? 'Explorer'}';
    final email = '${widget.profile['email'] ?? widget.user.email ?? ''}';
    final rank = '${widget.profile['rank'] ?? 'Bronze'}';
    final points = widget.profile['points'] ?? 0;
    final roleLabel = widget.role.toUpperCase();

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
                      color: ExplorerColors.goldDark.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_circle_outlined,
                      size: 38,
                      color: ExplorerColors.goldDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Account Found (Deactivated)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'An existing account matching your credentials was found, but it is currently deactivated.',
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
                      color: ExplorerColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ExplorerColors.border),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: ExplorerColors.navySoft,
                          foregroundColor: ExplorerColors.navy,
                          child: Text(
                            name.trim().isEmpty
                                ? 'E'
                                : name.trim()[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            Chip(
                              label: Text(roleLabel),
                              backgroundColor: ExplorerColors.navySoft,
                              labelStyle: const TextStyle(
                                color: ExplorerColors.navy,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (widget.profile.containsKey('rank'))
                              Chip(
                                label: Text('$rank ($points pts)'),
                                backgroundColor:
                                    ExplorerColors.goldDark.withOpacity(0.15),
                                labelStyle: const TextStyle(
                                  color: ExplorerColors.goldDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Color(0xFFF57F17),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Reactivating your account will make your profile and data accessible again. Note that reactivating adds a 72-hour cooldown before you can deactivate your account again.',
                            style: TextStyle(
                              color: Color(0xFF5D4037),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _reactivateAccount,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.power_settings_new),
                      label: Text(
                          _busy ? 'Reactivating...' : 'Reactivate Account'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _busy ? null : AppServices.signOut,
                      child: const Text('Sign Out'),
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
