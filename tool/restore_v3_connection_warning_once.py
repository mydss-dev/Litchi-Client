#!/usr/bin/env python3
"""One-shot, exact-match dashboard edits. Deleted after verification."""
from pathlib import Path

path = Path('lib/v3/pages/v3_dashboard_page.dart')
source = path.read_text(encoding='utf-8')


def replace_exact(before: str, after: str) -> None:
    global source
    count = source.count(before)
    if count != 1:
        raise SystemExit(f'Expected exactly one target, got {count}: {before[:100]!r}')
    source = source.replace(before, after, 1)


replace_exact(
    "import '../ui/v3_components.dart';\n",
    "import '../ui/v3_components.dart';\nimport '../ui/v3_dashboard_alerts.dart';\n",
)
replace_exact(
    "          V3NoticeBar(controller: controller),\n",
    "          V3NoticeBar(controller: controller),\n"
    "          V3DashboardAlerts(controller: controller),\n",
)
replace_exact(
    "    final error = status == ConnectionStatus.error\n"
    "        ? controller.coreError.isEmpty\n"
    "              ? v3Copy(\n"
    "                  context,\n"
    "                  zh: '请重试连接，或切换其他节点。',\n"
    "                  en: 'Retry or change nodes.',\n"
    "                  tw: '請重試或切換節點。',\n"
    "                )\n"
    "              : controller.coreError\n"
    "        : null;\n",
    '',
)
replace_exact(
    "                                  if (error != null) ...[\n"
    "                                    const SizedBox(height: 4),\n"
    "                                    Text(\n"
    "                                      error,\n"
    "                                      maxLines: 2,\n"
    "                                      overflow: TextOverflow.ellipsis,\n"
    "                                      textAlign: TextAlign.center,\n"
    "                                      style: TextStyle(\n"
    "                                        color: p.dangerInk,\n"
    "                                        fontSize: 10,\n"
    "                                      ),\n"
    "                                    ),\n"
    "                                  ],\n",
    '',
)
replace_exact(
    "                  : () async {\n"
    "                      final error = await controller.toggleConnection();\n"
    "                      if (error != null && context.mounted) {\n"
    "                        ScaffoldMessenger.of(context)\n"
    "                            .showSnackBar(SnackBar(content: Text(error)));\n"
    "                      }\n"
    "                    },\n",
    "                  : () async {\n"
    "                      // Persistent alert and retry are driven by core state.\n"
    "                      await controller.toggleConnection();\n"
    "                    },\n",
)
path.write_text(source, encoding='utf-8')
print('Applied guarded dashboard edits (alerts only).')
