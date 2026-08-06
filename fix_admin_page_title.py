from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parent
TARGET = ROOT / "lib/admin/users/admin_users_page.dart"

if not TARGET.exists():
    raise FileNotFoundError(f"Required file not found: {TARGET}")

backup = TARGET.with_name(
    TARGET.name + ".before_page_title_fix.bak"
)
if not backup.exists():
    shutil.copy2(TARGET, backup)

text = TARGET.read_text(encoding="utf-8")

# Support the current AdminShell calls:
# AdminUsersPage(roleFilter: 'traveler', pageTitle: 'Traveler Management')
# AdminUsersPage(roleFilter: 'vendor', pageTitle: 'Vendor Management')
constructor_patterns = [
    (
        r"""class AdminUsersPage extends StatefulWidget \{
  const AdminUsersPage\(\{
    super\.key,
    this\.roleFilter,
  \}\);

  final String\? roleFilter;
""",
        """class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    this.roleFilter,
    this.pageTitle,
  });

  final String? roleFilter;
  final String? pageTitle;
""",
    ),
    (
        r"""class AdminUsersPage extends StatefulWidget \{
  const AdminUsersPage\(\{super\.key\}\);
""",
        """class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    this.roleFilter,
    this.pageTitle,
  });

  final String? roleFilter;
  final String? pageTitle;
""",
    ),
]

changed_constructor = False
for pattern, replacement in constructor_patterns:
    new_text, count = re.subn(
        pattern,
        replacement,
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count:
        text = new_text
        changed_constructor = True
        break

if not changed_constructor and "final String? pageTitle;" not in text:
    raise RuntimeError(
        "Could not find the AdminUsersPage constructor."
    )

# Ensure role is initialised from roleFilter.
if "late String role;" not in text:
    text = text.replace(
        "  String role = 'all';",
        "  late String role;",
        1,
    )

if "void initState()" not in text:
    marker = """  @override
  void dispose() {
"""
    init_state = """  @override
  void initState() {
    super.initState();

    final requestedRole = widget.roleFilter;
    role = const {'admin', 'traveler', 'vendor'}.contains(
      requestedRole,
    )
        ? requestedRole!
        : 'all';
  }

"""
    if marker not in text:
        raise RuntimeError(
            "Could not find the AdminUsersPage dispose method."
        )
    text = text.replace(marker, init_state + marker, 1)

# Display the page title above the search controls.
build_marker = """    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
"""

title_block = """    return Column(
      children: [
        if (widget.pageTitle != null &&
            widget.pageTitle!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.pageTitle!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
"""

if build_marker in text:
    text = text.replace(build_marker, title_block, 1)
elif "widget.pageTitle" not in text:
    raise RuntimeError(
        "Could not find the AdminUsersPage build layout."
    )

TARGET.write_text(text, encoding="utf-8")

for opening, closing in [("(", ")"), ("[", "]"), ("{", "}")]:
    if text.count(opening) != text.count(closing):
        raise RuntimeError(
            f"Delimiter mismatch: {opening}={text.count(opening)}, "
            f"{closing}={text.count(closing)}"
        )

print("Fixed: lib/admin/users/admin_users_page.dart")
print()
print("Now run:")
print("  flutter clean")
print("  flutter pub get")
print("  flutter analyze")
print("  flutter run")
