from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent
HELPERS = ROOT / "lib/core/helpers.dart"
LOGIN = ROOT / "lib/auth/screens/login_page.dart"
AUTH_GATE = ROOT / "lib/auth/gate/auth_gate_view.dart"
DAILY_PLANNER_DIR = ROOT / "lib/traveler/daily_planner"


def backup(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Required file not found: {path}")
    backup_path = path.with_name(path.name + ".before_symbol_admin_fix.bak")
    if not backup_path.exists():
        shutil.copy2(path, backup_path)


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    print(f"Updated: {path.relative_to(ROOT)}")


backup(HELPERS)
helpers = HELPERS.read_text(encoding="utf-8")
if "String cleanDisplayText(" not in helpers:
    marker = "void showMessage("
    helper_function = '''
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
      .replaceAll(RegExp(r'\\s+-\\s+'), ' - ')
      .replaceAll(RegExp(r'\\s+'), ' ')
      .trim();
}

'''
    if marker not in helpers:
        raise RuntimeError("Could not find showMessage() in helpers.dart.")
    helpers = helpers.replace(marker, helper_function + marker, 1)
write(HELPERS, helpers)

for dart_file in DAILY_PLANNER_DIR.rglob("*.dart"):
    backup(dart_file)
    text = dart_file.read_text(encoding="utf-8")
    for old, new in {
        " • ": " - ",
        "â€¢": " - ",
        "â€˘": " - ",
        "â€“": "-",
        "â€”": "-",
        "Â": "",
        "�": "",
    }.items():
        text = text.replace(old, new)

    text = text.replace(
        "return reasons.take(3).join(' • ');",
        "return reasons.take(3).join(' - ');",
    )

    if dart_file.name == "place_detail_page.dart":
        text = re.sub(
            r"final suggestionReason\s*=\s*"
            r"'\$\{place\['suggestionReason'\]\s*\?\?\s*''\}';",
            "final suggestionReason = cleanDisplayText(place['suggestionReason']);",
            text,
            count=1,
        )

    if dart_file.name == "daily_planner_page.dart":
        text = text.replace(
            "'${data['suggestionReason']}'",
            "cleanDisplayText(data['suggestionReason'])",
        )

    write(dart_file, text)

backup(LOGIN)
login = LOGIN.read_text(encoding="utf-8")
patterns = [
    r"final\s+profile\s*=\s*\(await\s+AppServices\.userRef\(credential\.user!\.uid\)\.get\(\)\)\.data\(\);",
    r"final\s+profile\s*=\s*\(await\s+AppServices\.travelerRef\(credential\.user!\.uid\)\.get\(\)\)\.data\(\);",
    r"final\s+profile\s*=\s*\(await\s+AppServices\.vendorRef\(credential\.user!\.uid\)\.get\(\)\)\.data\(\);",
]
replacement = (
    "final profile = await AppServices.profileForRole(\n"
    "        credential.user!.uid,\n"
    "        widget.role,\n"
    "      );"
)
for pattern in patterns:
    login = re.sub(pattern, replacement, login)
write(LOGIN, login)

backup(AUTH_GATE)
auth_gate = '''part of '../auth_gate.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AppServices.auth.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;
        if (user == null) return const RoleSelectPage();

        return StreamBuilder<AccountProfile?>(
          stream: AppServices.accountProfileStream(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting &&
                !profileSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${profileSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            final account = profileSnapshot.data;
            if (account == null) {
              return MissingProfilePage(uid: user.uid);
            }

            final role = account.role;
            final profile = account.data;

            if (profile['status'] != 'active') {
              return const AccountDisabledPage();
            }

            if (!user.emailVerified && role != 'admin') {
              return EmailVerificationPage(user: user);
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

            return TravelerShell(profile: profile);
          },
        );
      },
    );
  }
}
'''
write(AUTH_GATE, auth_gate)

for dart_file in [HELPERS, LOGIN, AUTH_GATE, *DAILY_PLANNER_DIR.rglob("*.dart")]:
    text = dart_file.read_text(encoding="utf-8")
    for opening, closing in [("(", ")"), ("[", "]"), ("{", "}")]:
        if text.count(opening) != text.count(closing):
            raise RuntimeError(
                f"Delimiter mismatch in {dart_file.name}: "
                f"{opening}={text.count(opening)}, {closing}={text.count(closing)}"
            )

print()
print("Symbol and Admin web source repair completed.")
print("Next run:")
print("  powershell -ExecutionPolicy Bypass -File .\\repair_admin_and_saved_symbols.ps1")
print("  powershell -ExecutionPolicy Bypass -File .\\deploy_admin_web.ps1")
