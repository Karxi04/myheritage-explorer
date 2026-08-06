from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent

HELPERS = ROOT / "lib/core/helpers.dart"
AUTH_GATE = ROOT / "lib/auth/gate/auth_gate_view.dart"
DAILY = ROOT / "lib/traveler/daily_planner/daily_planner_page.dart"
PLACE_DETAIL = ROOT / "lib/traveler/daily_planner/place_detail_page.dart"
ITINERARY_DETAIL = ROOT / "lib/traveler/daily_planner/itinerary_detail_page.dart"

def backup(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Required file not found: {path}")

    backup_path = path.with_name(
        path.name + ".before_vendor_symbol_admin_fix.bak"
    )
    if not backup_path.exists():
        shutil.copy2(path, backup_path)

def save(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    print(f"Updated: {path.relative_to(ROOT)}")

backup(HELPERS)
helpers = HELPERS.read_text(encoding="utf-8")

if "String cleanDisplayText(" not in helpers:
    marker = "void showMessage("
    function_text = r'''
String cleanDisplayText(Object? value) {
  var text = '${value ?? ''}';

  const replacements = <String, String>{
    'â€¢': ' - ',
    'â€˘': ' - ',
    'â€¯': ' ',
    'â€“': '-',
    'â€”': '-',
    'â€˜': "'",
    'â€™': "'",
    'â€œ': '"',
    'â€': '"',
    'Â': '',
    '�': '',
    '•': ' - ',
  };

  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }

  return text
      .replaceAll(RegExp(r'\s+-\s+'), ' - ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

'''
    if marker not in helpers:
        raise RuntimeError(
            "Could not find showMessage() in lib/core/helpers.dart."
        )
    helpers = helpers.replace(marker, function_text + marker, 1)

save(HELPERS, helpers)

for path in [DAILY, PLACE_DETAIL, ITINERARY_DETAIL]:
    if not path.exists():
        print(f"Skipped missing optional file: {path.relative_to(ROOT)}")
        continue

    backup(path)
    text = path.read_text(encoding="utf-8")

    for bad, replacement in {
        " â€¢ ": " - ",
        "â€¢": " - ",
        "â€˘": " - ",
        " • ": " - ",
        "Â": "",
        "�": "",
    }.items():
        text = text.replace(bad, replacement)

    text = text.replace(
        "return reasons.take(3).join(' • ');",
        "return reasons.take(3).join(' - ');",
    )

    if path == DAILY:
        text = text.replace(
            "Text(\n                          '${data['suggestionReason']}',",
            "Text(\n                          cleanDisplayText(data['suggestionReason']),",
        )
        text = text.replace(
            "Text('${data['suggestionReason']}')",
            "Text(cleanDisplayText(data['suggestionReason']))",
        )

    if path == PLACE_DETAIL:
        text = re.sub(
            r"final suggestionReason\s*=\s*"
            r"'\$\{place\['suggestionReason'\]\s*\?\?\s*''\}';",
            "final suggestionReason = "
            "cleanDisplayText(place['suggestionReason']);",
            text,
            count=1,
        )

    text = text.replace(
        "'${stop['suggestionReason'] ?? ''}'",
        "cleanDisplayText(stop['suggestionReason'])",
    )
    text = text.replace(
        "'${data['suggestionReason'] ?? ''}'",
        "cleanDisplayText(data['suggestionReason'])",
    )

    save(path, text)

backup(AUTH_GATE)

auth_gate_text = r'''part of '../auth_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AppServices.auth.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const _ProfileLoadingPage(
            message: 'Checking authentication...',
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const RoleSelectPage();

        return _ResolvedRoleGate(
          key: ValueKey(user.uid),
          user: user,
        );
      },
    );
  }
}

class _ResolvedRoleGate extends StatefulWidget {
  const _ResolvedRoleGate({
    super.key,
    required this.user,
  });

  final User user;

  @override
  State<_ResolvedRoleGate> createState() =>
      _ResolvedRoleGateState();
}

class _ResolvedRoleGateState
    extends State<_ResolvedRoleGate> {
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
        if (profileSnapshot.connectionState !=
            ConnectionState.done) {
          return const _ProfileLoadingPage(
            message: 'Loading account profile...',
          );
        }

        if (profileSnapshot.hasError) {
          return _ProfileLoadErrorPage(
            message:
                '${profileSnapshot.error}'.replaceFirst(
              'Exception: ',
              '',
            ),
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

        return StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: reference.snapshots(),
          builder: (context, liveSnapshot) {
            if (!liveSnapshot.hasData) {
              if (liveSnapshot.hasError) {
                return _ProfileLoadErrorPage(
                  message:
                      '${liveSnapshot.error}'.replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  onRetry: () => setState(_reload),
                );
              }

              return const _ProfileLoadingPage(
                message: 'Opening your account...',
              );
            }

            final profile = liveSnapshot.data!.data();
            if (profile == null) {
              return MissingProfilePage(uid: widget.user.uid);
            }

            return _routeProfile(
              context,
              role: account.role,
              profile: profile,
            );
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
  const _ProfileLoadingPage({
    required this.message,
  });

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
              Text(
                message,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLoadErrorPage extends StatelessWidget {
  const _ProfileLoadErrorPage({
    required this.message,
    required this.onRetry,
  });

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
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load account profile',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                    ),
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
'''

save(AUTH_GATE, auth_gate_text)

for path in [
    HELPERS,
    AUTH_GATE,
    DAILY,
    PLACE_DETAIL,
    ITINERARY_DETAIL,
]:
    if not path.exists():
        continue

    text = path.read_text(encoding="utf-8")
    for opening, closing in [
        ("(", ")"),
        ("[", "]"),
        ("{", "}"),
    ]:
        if text.count(opening) != text.count(closing):
            raise RuntimeError(
                f"Delimiter mismatch in {path.name}: "
                f"{opening}={text.count(opening)}, "
                f"{closing}={text.count(closing)}"
            )

print()
print("Source repair completed.")
print()
print("Next:")
print(
    "  powershell -ExecutionPolicy Bypass "
    "-File .\\repair_vendor_names_symbols_admin.ps1"
)
print(
    "  powershell -ExecutionPolicy Bypass "
    "-File .\\deploy_current_admin_web.ps1"
)
