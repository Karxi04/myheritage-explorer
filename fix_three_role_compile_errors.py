from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parent

EMAIL_FILE = ROOT / "lib/auth/gate/email_verification_page.dart"
ADMIN_USERS_FILE = ROOT / "lib/admin/users/admin_users_page.dart"

def backup(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Required file not found: {path}")
    backup_path = path.with_name(path.name + ".before_compile_fix.bak")
    if not backup_path.exists():
        shutil.copy2(path, backup_path)

# ---------------------------------------------------------------------
# 1. Fix email verification profile update.
# ---------------------------------------------------------------------
backup(EMAIL_FILE)
email_text = EMAIL_FILE.read_text(encoding="utf-8")

old_patterns = [
    "await AppServices.userRef(refreshedUser!.uid).set(",
    "await AppServices.travelerRef(refreshedUser!.uid).set(",
    "await AppServices.vendorRef(refreshedUser!.uid).set(",
]

replacement = (
    "final profileRef = await AppServices.accountRef(\n"
    "          refreshedUser!.uid,\n"
    "        );\n"
    "        await profileRef.set("
)

replaced = False
for old in old_patterns:
    if old in email_text:
        email_text = email_text.replace(old, replacement, 1)
        replaced = True
        break

if not replaced and "await profileRef.set(" not in email_text:
    raise RuntimeError(
        "Could not find the email verification profile update block."
    )

EMAIL_FILE.write_text(email_text, encoding="utf-8")
print("Fixed: lib/auth/gate/email_verification_page.dart")

# ---------------------------------------------------------------------
# 2. Add roleFilter support to AdminUsersPage.
# ---------------------------------------------------------------------
backup(ADMIN_USERS_FILE)
admin_text = ADMIN_USERS_FILE.read_text(encoding="utf-8")

# Constructor and field.
constructor_pattern = re.compile(
    r"class AdminUsersPage extends StatefulWidget \{\s*"
    r"const AdminUsersPage\(\{super\.key\}\);\s*",
    re.MULTILINE,
)

constructor_replacement = """class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    this.roleFilter,
  });

  final String? roleFilter;

"""

if constructor_pattern.search(admin_text):
    admin_text = constructor_pattern.sub(
        constructor_replacement,
        admin_text,
        count=1,
    )
elif "final String? roleFilter;" not in admin_text:
    raise RuntimeError(
        "Could not find the AdminUsersPage constructor."
    )

# Change role variable to late and initialise from roleFilter.
admin_text = admin_text.replace(
    "  String role = 'all';",
    "  late String role;",
    1,
)

if "void initState()" not in admin_text:
    dispose_marker = """  @override
  void dispose() {
"""
    init_state = """  @override
  void initState() {
    super.initState();

    final requestedRole = widget.roleFilter;
    role = const {'admin', 'traveler', 'vendor'}.contains(requestedRole)
        ? requestedRole!
        : 'all';
  }

"""
    if dispose_marker not in admin_text:
        raise RuntimeError(
            "Could not find the AdminUsersPage dispose method."
        )
    admin_text = admin_text.replace(
        dispose_marker,
        init_state + dispose_marker,
        1,
    )

ADMIN_USERS_FILE.write_text(admin_text, encoding="utf-8")
print("Fixed: lib/admin/users/admin_users_page.dart")

# Basic delimiter checks.
for path in [EMAIL_FILE, ADMIN_USERS_FILE]:
    text = path.read_text(encoding="utf-8")
    for opening, closing in [("(", ")"), ("[", "]"), ("{", "}")]:
        if text.count(opening) != text.count(closing):
            raise RuntimeError(
                f"Delimiter mismatch in {path.name}: "
                f"{opening}={text.count(opening)}, "
                f"{closing}={text.count(closing)}"
            )

print()
print("Current blocking errors are fixed.")
print("Now run:")
print("  flutter clean")
print("  flutter pub get")
print("  flutter analyze")
print("  flutter run")
