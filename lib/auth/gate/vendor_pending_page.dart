
part of '../auth_gate.dart';

class VendorPendingPage extends StatelessWidget {
  const VendorPendingPage({
    super.key,
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: AppServices.auth.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                ExplorerCard(
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: ExplorerColors.warningSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          color: ExplorerColors.goldDark,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Pending Verification',
                        style: TextStyle(
                          color: ExplorerColors.navy,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const ExplorerStatusBadge(
                        label: 'PENDING VERIFICATION',
                        tone: ExplorerStatusTone.warning,
                        icon: Icons.schedule,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Your business account is currently waiting for administrator approval. We are reviewing your submitted details to ensure they meet our heritage stewardship guidelines.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ExplorerColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ExplorerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ExplorerSectionTitle('Business Summary'),
                      const SizedBox(height: 18),
                      _pendingRow(
                        'Business Name',
                        '${profile['businessName'] ?? profile['displayName'] ?? '-'}',
                      ),
                      _pendingRow(
                        'Owner',
                        '${profile['ownerName'] ?? '-'}',
                      ),
                      _pendingRow(
                        'Category',
                        '${profile['businessCategory'] ?? '-'}',
                      ),
                      _pendingRow(
                        'Location',
                        '${profile['shopLocation'] ?? '-'}',
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ExplorerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FEATURES AVAILABLE UPON APPROVAL',
                        style: TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _feature(Icons.confirmation_number_outlined, 'Voucher Publishing'),
                      _feature(Icons.qr_code_scanner, 'QR Redemption'),
                      _feature(Icons.analytics_outlined, 'Analytics'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Business Information'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: AppServices.auth.signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: ExplorerColors.border),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ExplorerColors.navySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: ExplorerColors.navy),
          ),
          const SizedBox(width: 11),
          Text(
            label,
            style: const TextStyle(
              color: ExplorerColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
