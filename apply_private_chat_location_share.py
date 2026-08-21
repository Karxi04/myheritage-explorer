from pathlib import Path
import shutil
import re
import sys

ROOT = Path.cwd()

required = [
    ROOT / "lib" / "traveler" / "traveler_pages.dart",
    ROOT / "lib" / "traveler" / "companion" / "companion_page.dart",
]

missing = [str(p) for p in required if not p.exists()]
if missing:
    print("Run this script from the myheritage-explorer repository root.")
    print("Missing:")
    for item in missing:
        print(" -", item)
    sys.exit(1)

SOURCE_DIR = Path(__file__).resolve().parent / "lib" / "traveler" / "companion"
TARGET_DIR = ROOT / "lib" / "traveler" / "companion"

backup_dir = ROOT.parent / f"{ROOT.name}_private_chat_backup"
backup_dir.mkdir(parents=True, exist_ok=True)

for name in [
    "companion_page.dart",
    "private_chat_page.dart",
    "private_chats_page.dart",
]:
    src = SOURCE_DIR / name
    dst = TARGET_DIR / name

    if dst.exists():
        shutil.copy2(dst, backup_dir / name)

    shutil.copy2(src, dst)
    print("Updated:", dst)

traveler_pages = ROOT / "lib" / "traveler" / "traveler_pages.dart"
text = traveler_pages.read_text(encoding="utf-8")

parts = [
    "part 'companion/private_chats_page.dart';",
    "part 'companion/private_chat_page.dart';",
]

anchor = "part 'companion/group_chat_page.dart';"

for part in parts:
    if part not in text:
        if anchor in text:
            text = text.replace(anchor, anchor + "\n" + part)
            anchor = part
        else:
            raise RuntimeError(
                "Could not find group_chat_page.dart part line in traveler_pages.dart"
            )

traveler_pages.write_text(text, encoding="utf-8")
print("Updated:", traveler_pages)

print()
print("DONE.")
print("Next:")
print("  1. Add 'private_chats' and 'location_requests' to your Firestore temporary-development allow-list.")
print("  2. flutter analyze")
print("  3. flutter run")
