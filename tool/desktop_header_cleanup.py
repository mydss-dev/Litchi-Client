from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def strip_desktop_prefix(path: str, method_marker: str, body_marker: str) -> None:
    text = read(path)
    method = text.index(method_marker)
    children_marker = "      children: [\n"
    children = text.index(children_marker, method) + len(children_marker)
    body = text.index(body_marker, children)
    text = text[:children] + text[body:]
    write(path, text)


def replace_in_method(path: str, method_marker: str, end_marker: str, old: str, new: str = "") -> None:
    text = read(path)
    start = text.index(method_marker)
    end = text.index(end_marker, start)
    segment = text[start:end]
    if segment.count(old) != 1:
        raise SystemExit(f"{path}: expected one method-local anchor: {old!r}, got {segment.count(old)}")
    segment = segment.replace(old, new, 1)
    write(path, text[:start] + segment + text[end:])


# Dashboard: content begins with alerts/connection cards. The page title and
# generic refresh affordance are redundant with the persistent desktop sidebar.
dashboard = "lib/features/dashboard/dashboard_page.dart"
strip_desktop_prefix(
    dashboard,
    "  Widget _buildDesktop(BuildContext context) {",
    "        _DesktopAlerts(",
)
text = read(dashboard)
start = text.index("class _DesktopDashboardHeader extends StatelessWidget")
end = text.index("class _DesktopAlerts extends StatelessWidget", start)
text = text[:start] + text[end:]
write(dashboard, text)

# Nodes: remove the banner header, then move the latency action into the actual
# search/filter toolbar so the first row has functional value.
nodes = "lib/features/nodes/nodes_page.dart"
strip_desktop_prefix(
    nodes,
    "  Widget _buildDesktop(BuildContext context) {",
    "        if (noPlan)",
)
text = read(nodes)
old = """              Text(
                context.l10n.nodeCountSummary(nodes.length),
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
"""
new = old + """              const SizedBox(width: 10),
              _LatencyTestButton(ctrl: ctrl, showLabel: true),
"""
if text.count(old) != 1:
    raise SystemExit(f"{nodes}: node toolbar anchor count {text.count(old)}")
write(nodes, text.replace(old, new, 1))

# Shop: category tabs are the page toolbar; no duplicate title/subtitle banner.
shop = "lib/features/shop/shop_page.dart"
strip_desktop_prefix(
    shop,
    "  Widget _buildDesktop(BuildContext context) {",
    "        _ShopTabs(",
)
replace_in_method(
    shop,
    "  Widget _buildDesktop(BuildContext context) {",
    "  // ── Compact",
    "    final c = AppColors.of(context);\n",
)

# Traffic: summary metrics already explain the page; start there directly.
traffic = "lib/features/traffic/traffic_page.dart"
strip_desktop_prefix(
    traffic,
    "  Widget _buildDesktop(BuildContext context) {",
    "        if (noPlan)",
)
replace_in_method(
    traffic,
    "  Widget _buildDesktop(BuildContext context) {",
    "  // ── Shared body",
    "    final c = AppColors.of(context);\n",
)

# Invite: invitation/link content is self-identifying; remove the generic header.
invite = "lib/features/invite/invite_page.dart"
strip_desktop_prefix(
    invite,
    "  Widget _buildDesktop(BuildContext context) {",
    "        LayoutBuilder(",
)
replace_in_method(
    invite,
    "  Widget _buildDesktop(BuildContext context) {",
    "  // ── Compact",
    "    final c = AppColors.of(context);\n",
)

# Account: the profile card itself is the identity header. Do not repeat an
# account title, description and refresh strip above it.
account = "lib/features/account/account_page.dart"
strip_desktop_prefix(
    account,
    "  Widget _buildDesktop(BuildContext context) {",
    "        _ProfileHeader(",
)
replace_in_method(
    account,
    "  Widget _buildDesktop(BuildContext context) {",
    "  // ── Compact",
    "    final c = AppColors.of(context);\n",
)

# Settings: section cards are already named. Remove the page-level heading.
settings = "lib/features/settings/settings_page.dart"
text = read(settings)
method = text.index("  Widget _buildDesktop(BuildContext context) {")
children_marker = "          children: [\n"
children = text.index(children_marker, method) + len(children_marker)
body_marker = "            ..._bodyChildren(context),"
body = text.index(body_marker, children)
text = text[:children] + text[body:]
write(settings, text)
replace_in_method(
    settings,
    "  Widget _buildDesktop(BuildContext context) {",
    "  // ── Shared body",
    "    final c = AppColors.of(context);\n",
)
replace_in_method(
    settings,
    "  Widget _buildDesktop(BuildContext context) {",
    "  // ── Shared body",
    "    final l10n = context.l10n;\n",
)

# Shared account/support scaffold: Desktop no longer renders a web-console-like
# title/subtitle banner. Keep only a compact action strip when the page actually
# has actions (refresh/new ticket), then render content immediately.
scaffold = "lib/shared/widgets/responsive_page_scaffold.dart"
text = read(scaffold)
text = text.replace("import '../theme/app_colors.dart';\n", "")
text = text.replace(
    "/// Shared page chrome for account/support sub-pages. Desktop uses the\n"
    "/// persistent sidebar and a wide title/subtitle header; compact platforms keep\n"
    "/// the bottom-nav/back-button presentation.\n",
    "/// Shared page chrome for account/support sub-pages. Desktop is content-first:\n"
    "/// the persistent sidebar already names the destination, so only real page\n"
    "/// actions are surfaced above content. Compact navigation remains unchanged.\n",
)
start = text.index("  Widget _buildDesktop(BuildContext context) {")
end = text.index("\n  }\n}\n\nclass _CompactBackHeader", start) + len("\n  }")
new_method = """  Widget _buildDesktop(BuildContext context) {
    final hasActions = trailing != null || onRefresh != null;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasActions) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onRefresh != null)
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .refreshIndicatorSemanticLabel,
                          onPressed: () async => onRefresh!(),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          iconSize: 17,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    if (trailing != null) ...[
                      if (onRefresh != null) const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            ...children,
          ],
        ),
      ),
    );
  }"""
text = text[:start] + new_method + text[end:]
write(scaffold, text)

# Guardrails: desktop primary/account pages must no longer start with the old
# page-title banner. Compact code intentionally retains its headers.
checks = {
    dashboard: "_DesktopDashboardHeader",
    shop: "context.l10n.buyPlansSubtitle",
    traffic: "context.l10n.trafficStatisticsSubtitle",
    invite: "context.l10n.inviteSubtitle",
    account: "desktopPageLabel(context, AppPage.account)",
}
for path, forbidden in checks.items():
    text = read(path)
    desktop = text.split("Widget _buildDesktop", 1)[1].split("// ── Compact", 1)[0]
    if forbidden in desktop:
        raise SystemExit(f"{path}: desktop banner residue {forbidden}")

text = read(settings)
desktop = text.split("Widget _buildDesktop", 1)[1].split("// ── Shared body", 1)[0]
if "AppTextStyles.pageTitle" in desktop or "settingsSubtitle" in desktop:
    raise SystemExit("settings: desktop banner residue")

text = read(nodes)
desktop = text.split("Widget _buildDesktop", 1)[1].split("// ── Compact", 1)[0]
if "nodesSubtitle" in desktop or "AppTextStyles.pageTitle" in desktop:
    raise SystemExit("nodes: desktop banner residue")
if desktop.count("_LatencyTestButton(ctrl: ctrl, showLabel: true)") != 1:
    raise SystemExit("nodes: latency action not integrated into toolbar")

text = read(scaffold)
desktop = text.split("Widget _buildDesktop", 1)[1].split("class _CompactBackHeader", 1)[0]
if "Text(\n                        title" in desktop or "subtitle," in desktop:
    raise SystemExit("responsive scaffold: desktop title/subtitle residue")
