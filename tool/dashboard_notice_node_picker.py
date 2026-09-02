from pathlib import Path

p = Path('lib/features/dashboard/dashboard_page.dart')
text = p.read_text()

old = '''        _DesktopAlerts(
          ctrl: ctrl,
          onConnectionRetry: _toggleConnection,
          onDataRetry: _handlePullRefresh,
        ),
        if (noPlan)
'''
new = '''        _DesktopAlerts(
          ctrl: ctrl,
          onConnectionRetry: _toggleConnection,
          onDataRetry: _handlePullRefresh,
        ),
        NoticeCarousel(notices: ctrl.notices, isLoading: ctrl.noticesLoading),
        const SizedBox(height: 16),
        if (noPlan)
'''
if old not in text:
    raise SystemExit('desktop alert anchor not found')
text = text.replace(old, new, 1)

old = '                      onTap: () => ctrl.goToPage(AppPage.nodes),\n'
new = '                      onTap: () => showNodePicker(context),\n'
if old not in text:
    raise SystemExit('desktop node navigation anchor not found')
text = text.replace(old, new, 1)

old = '''        ],
        const SizedBox(height: 16),
        NoticeCarousel(notices: ctrl.notices, isLoading: ctrl.noticesLoading),
      ],
'''
new = '''        ],
      ],
'''
if old not in text:
    raise SystemExit('desktop notice footer anchor not found')
text = text.replace(old, new, 1)

p.write_text(text)
