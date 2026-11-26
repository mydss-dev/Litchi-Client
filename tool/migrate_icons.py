"""One-off migration: Material icons and raw Lucide references -> AppIcons.

Run from the project root:  python tool/migrate_icons.py
"""

from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MAPPING = {
    "error_outline_rounded": "error",
    "chevron_right_rounded": "chevronRight",
    "close_rounded": "close",
    "refresh_rounded": "refresh",
    "link_rounded": "link",
    "auto_awesome_rounded": "sparkles",
    "visibility_off_rounded": "hidden",
    "receipt_long_rounded": "receipt",
    "check_rounded": "check",
    "add_rounded": "add",
    "warning_amber_rounded": "warning",
    "visibility_rounded": "visible",
    "shield_rounded": "shield",
    "send_rounded": "send",
    "person_outline_rounded": "user",
    "info_outline_rounded": "info",
    "chevron_left_rounded": "chevronLeft",
    "swap_horiz_rounded": "swap",
    "search_rounded": "search",
    "search_off_rounded": "searchOff",
    "power_settings_new_rounded": "power",
    "forum_rounded": "support",
    "check_circle_rounded": "checkCircle",
    "blur_on_rounded": "brand",
    "tune_rounded": "sliders",
    "support_agent_rounded": "headset",
    "storefront_rounded": "store",
    "storage_rounded": "database",
    "stop_rounded": "stop",
    "shield_outlined": "shield",
    "redeem_rounded": "gift",
    "receipt_long_outlined": "receipt",
    "public_off_rounded": "globeOff",
    "logout_rounded": "logout",
    "inventory_2_rounded": "package",
    "insights_rounded": "chartLine",
    "data_usage_rounded": "gauge",
    "dark_mode_rounded": "sleep",
    "copy_rounded": "copy",
    "check_circle_outline_rounded": "checkCircle",
    "campaign_rounded": "broadcast",
    "arrow_downward_rounded": "arrowDown",
    "arrow_back_ios_new_rounded": "chevronLeft",
    "add_card_rounded": "card",
    "widgets_rounded": "grid",
    "verified_rounded": "verified",
    "system_update_rounded": "download",
    "system_update_alt_rounded": "download",
    "storage_outlined": "database",
    "stacked_line_chart_rounded": "chartStacked",
    "shopping_bag_rounded": "shoppingBag",
    "shopping_bag_outlined": "shoppingBag",
    "send_outlined": "send",
    "schedule_rounded": "clock",
    "remove_rounded": "remove",
    "public_rounded": "globe",
    "person_rounded": "user",
    "person_add_alt_1_rounded": "userPlus",
    "password_rounded": "key",
    "open_in_new_rounded": "externalLink",
    "lock_outline_rounded": "lock",
    "link_off_rounded": "linkOff",
    "light_mode_rounded": "daylight",
    "language_rounded": "language",
    "keyboard_arrow_down_rounded": "chevronDown",
    "insights_outlined": "chartLine",
    "hub_rounded": "nodes",
    "hub_outlined": "nodes",
    "grid_view_rounded": "grid",
    "forum_outlined": "support",
    "filter_none_rounded": "filtered",
    "expand_more": "chevronDown",
    "expand_less": "chevronUp",
    "dns_rounded": "server",
    "diamond_rounded": "gem",
    "devices_outlined": "devices",
    "crop_square_rounded": "scan",
    "content_copy_rounded": "copy",
    "cloud_off_rounded": "cloudOff",
    "checklist_rounded": "listChecks",
    "chat_bubble_outline_rounded": "message",
    "card_giftcard_rounded": "gift",
    "campaign_outlined": "broadcast",
    "build_circle_rounded": "wrench",
    "bar_chart_rounded": "chartBar",
    "autorenew_rounded": "refresh",
    "auto_awesome_outlined": "sparkles",
    "arrow_upward_rounded": "arrowUp",
    "arrow_circle_up_rounded": "arrowUpCircle",
    "account_balance_rounded": "bank",
    "account_balance_outlined": "bank",
    "radar_rounded": "radar",
    "radar_outlined": "radar",
    "tune_outlined": "sliders",
    # Raw Lucide references already in the tree.
    "house": "connection",
    "crown": "plans",
    "userRound": "account",
    "zap": "zap",
    "server": "nodes",
    "wallet": "wallet",
    "settings": "settings",
    "receipt": "receipt",
    "chevronRight": "chevronRight",
    "messageCircle": "message",
}

ICONS_IMPORT = "package:lucide_icons_flutter/lucide_icons.dart"


def rel_import(target: Path, source: Path) -> str:
    rel = os.path.relpath(target, source.parent).replace("\\", "/")
    return rel if rel.startswith(".") else f"./{rel}"


def migrate(path: Path, package_prefix: str) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text

    for material, member in MAPPING.items():
        text = re.sub(rf"\bIcons\.{material}\b", f"AppIcons.{member}", text)
        text = re.sub(rf"\bLucideIcons\.{material}\b", f"AppIcons.{member}", text)

    if "AppIcons." not in text:
        return False

    icons_file = ROOT / "lib" / "shared" / "theme" / "app_icons.dart"
    if "app_icons.dart" not in text:
        imp = f"import '{package_prefix}{rel_import(icons_file, path)}';"
        # Insert after the last import line, keeping the block tidy.
        lines = text.splitlines()
        last = max(i for i, line in enumerate(lines) if line.startswith("import "))
        lines.insert(last + 1, imp)
        text = "\n".join(lines) + ("\n" if original.endswith("\n") else "")

    # Drop the Lucide import once nothing references it directly.
    if "LucideIcons." not in text and ICONS_IMPORT in text:
        text = text.replace(f"import '{ICONS_IMPORT}';\n", "")
        text = text.replace(f"import '{ICONS_IMPORT}';\r\n", "")

    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> int:
    changed = []
    for base, prefix in ((ROOT / "lib", "package:litchi_client/"), (ROOT / "test", "package:litchi_client/")):
        for path in sorted(base.rglob("*.dart")):
            if "l10n/generated" in path.as_posix():
                continue
            if migrate(path, prefix):
                changed.append(path.relative_to(ROOT).as_posix())
    print(f"updated {len(changed)} files")
    for c in changed:
        print(" ", c)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
