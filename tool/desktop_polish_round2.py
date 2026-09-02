from pathlib import Path


def replace_between(text: str, start: str, end: str, replacement: str) -> str:
    a = text.index(start)
    b = text.index(end, a)
    return text[:a] + replacement + text[b:]


# ── Account: keep the three summary cards visually equal, move money actions
#    into their own full-width row below. ──────────────────────────────────
account_path = Path('lib/features/account/account_page.dart')
account = account_path.read_text(encoding='utf-8')

metrics = r'''class _DesktopAccountMetrics extends StatelessWidget {
  const _DesktopAccountMetrics({
    required this.ctrl,
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final AppController ctrl;
  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * 2) / 3;
        final balance = ctrl.user.balance / 100;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: width,
                  child: _DesktopAccountMetric(
                    icon: LucideIcons.package,
                    label: context.l10n.currentPlan,
                    value: ctrl.user.plan.isEmpty
                        ? context.l10n.noCurrentPlan
                        : ctrl.user.plan,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _DesktopBalanceMetric(
                    value:
                        '${ctrl.currencySymbol}${balance.toStringAsFixed(2)}',
                    commission:
                        '${ctrl.currencySymbol}${ctrl.withdrawable.toStringAsFixed(2)}',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _DesktopAccountMetric(
                    icon: LucideIcons.calendarClock,
                    label: context.l10n.expiryTime,
                    value: ctrl.user.expiry.isEmpty ? '--' : ctrl.user.expiry,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DesktopMoneyActions(
              onRecharge: onRecharge,
              onTransfer: onTransfer,
              onWithdraw: onWithdraw,
            ),
          ],
        );
      },
    );
  }
}

'''
account = replace_between(
    account,
    'class _DesktopAccountMetrics extends StatelessWidget {',
    'class _DesktopAccountMetric extends StatelessWidget {',
    metrics,
)

balance_and_actions = r'''class _DesktopBalanceMetric extends StatelessWidget {
  const _DesktopBalanceMetric({
    required this.value,
    required this.commission,
  });

  final String value;
  final String commission;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      height: 116,
      padding: const EdgeInsets.all(14),
      shadow: AppCardShadow.soft,
      child: Row(
        children: [
          _SmallIcon(icon: LucideIcons.wallet, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.accountBalance,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${context.l10n.withdrawableCommission} $commission',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopMoneyActions extends StatelessWidget {
  const _DesktopMoneyActions({
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shadow: AppCardShadow.soft,
      child: Row(
        children: [
          Expanded(
            child: _DesktopMoneyAction(
              label: context.l10n.rechargeBalance,
              onTap: onRecharge,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DesktopMoneyAction(
              label: context.l10n.transferShort,
              onTap: onTransfer,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DesktopMoneyAction(
              label: context.l10n.withdrawShort,
              onTap: onWithdraw,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopMoneyAction extends StatelessWidget {
  const _DesktopMoneyAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.primary.withValues(alpha: 0.16)),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: c.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

'''
account = replace_between(
    account,
    'class _DesktopBalanceMetric extends StatelessWidget {',
    'class _DesktopAccountServices extends StatelessWidget {',
    balance_and_actions,
)
account_path.write_text(account, encoding='utf-8')


# ── Dashboard: desktop node card is a display surface, not one giant button.
#    Keeping only the explicit switch button interactive also makes both hero
#    cards use the exact same AppCard rendering path/background. ───────────
dashboard_path = Path('lib/features/dashboard/dashboard_page.dart')
dashboard = dashboard_path.read_text(encoding='utf-8')
node_start = dashboard.index('class _DesktopNodeCard extends StatelessWidget {')
next_class = dashboard.index('\nclass ', node_start + 10)
node_block = dashboard[node_start:next_class]
needle = '      onTap: onTap,\n'
if needle not in node_block:
    raise SystemExit('desktop node card AppCard onTap not found')
node_block = node_block.replace(needle, '', 1)
dashboard = dashboard[:node_start] + node_block + dashboard[next_class:]
dashboard_path.write_text(dashboard, encoding='utf-8')


# ── Plans: the fresh plan list is authoritative for the current plan title.
#    This fixes stale names surviving refresh/logout-login after an admin rename.
plan_path = Path('lib/shared/services/plan_data_service.dart')
plan = plan_path.read_text(encoding='utf-8')
old_load = r'''    final plans = remotePlans.map(ModelMappers.toPlan).toList();
    final currentPlan = planById(plans, currentPlanId);
    final user = currentUser;
    return PlanDataResult(
      plans: plans,
      user: user != null && user.plan.trim().isEmpty && currentPlan != null
          ? user.copyWith(plan: currentPlan.title)
          : null,
    );
'''
new_load = r'''    final plans = remotePlans.map(ModelMappers.toPlan).toList();
    return PlanDataResult(
      plans: plans,
      user: syncCurrentPlanTitle(
        user: currentUser,
        plans: plans,
        currentPlanId: currentPlanId,
      ),
    );
'''
if old_load not in plan:
    raise SystemExit('PlanDataService loadPlans block changed unexpectedly')
plan = plan.replace(old_load, new_load, 1)
helper_marker = '  static PlanModel? planById(List<PlanModel> plans, int? id) {'
helper = r'''  static UserModel? syncCurrentPlanTitle({
    required UserModel? user,
    required List<PlanModel> plans,
    required int? currentPlanId,
  }) {
    if (user == null) return null;
    final currentPlan = planById(plans, currentPlanId);
    if (currentPlan == null) return null;
    final freshTitle = currentPlan.title.trim();
    if (freshTitle.isEmpty || user.plan.trim() == freshTitle) return null;
    return user.copyWith(plan: currentPlan.title);
  }

'''
if helper_marker not in plan:
    raise SystemExit('PlanDataService planById marker missing')
plan = plan.replace(helper_marker, helper + helper_marker, 1)
plan_path.write_text(plan, encoding='utf-8')


data_path = Path('lib/shared/services/data_loader.dart')
data = data_path.read_text(encoding='utf-8')
import_marker = "import 'panel_api.dart';\n"
if "import 'plan_data_service.dart';" not in data:
    if import_marker not in data:
        raise SystemExit('DataLoader panel_api import marker missing')
    data = data.replace(
        import_marker,
        import_marker + "import 'plan_data_service.dart';\n",
        1,
    )
old_sync = r'''        final currentPlan = _planById(mapped, snap.currentPlanId);
        final user = snap.user;
        if (user != null && user.plan.trim().isEmpty && currentPlan != null) {
          snap.user = user.copyWith(plan: currentPlan.title);
        }
'''
new_sync = r'''        final syncedUser = PlanDataService.syncCurrentPlanTitle(
          user: snap.user,
          plans: mapped,
          currentPlanId: snap.currentPlanId,
        );
        if (syncedUser != null) snap.user = syncedUser;
'''
if old_sync not in data:
    raise SystemExit('DataLoader stale plan-title block changed unexpectedly')
data = data.replace(old_sync, new_sync, 1)
old_helper = r'''  PlanModel? _planById(List<PlanModel> plans, int? id) {
    if (id == null || id <= 0) return null;
    for (final plan in plans) {
      if (int.tryParse(plan.id) == id) return plan;
    }
    return null;
  }

'''
if old_helper not in data:
    raise SystemExit('DataLoader private _planById helper missing')
data = data.replace(old_helper, '', 1)
data_path.write_text(data, encoding='utf-8')


# ── Regression test for backend plan renames. ─────────────────────────────
test_path = Path('test/data_services_test.dart')
test = test_path.read_text(encoding='utf-8')
marker = "  test('aggregates traffic logs by local day and keeps points sorted', () {\n"
new_test = r'''  test('fresh plan title replaces stale account plan name', () {
    const user = UserModel(
      name: 'Tester',
      plan: 'Old Pro Name',
      avatarLetter: 'T',
      expiry: '2026-12-31',
    );
    const plans = [
      PlanModel(
        id: '12',
        title: 'Litchi Pro',
        capacity: '500 GB',
        category: PlanCategory.recurring,
      ),
    ];

    final updated = PlanDataService.syncCurrentPlanTitle(
      user: user,
      plans: plans,
      currentPlanId: 12,
    );

    expect(updated?.plan, 'Litchi Pro');
    expect(
      PlanDataService.syncCurrentPlanTitle(
        user: updated,
        plans: plans,
        currentPlanId: 12,
      ),
      isNull,
    );
  });

'''
if marker not in test:
    raise SystemExit('data_services_test insertion marker missing')
test = test.replace(marker, new_test + marker, 1)
test_path.write_text(test, encoding='utf-8')


# Guardrails before formatting/building.
account_now = account_path.read_text(encoding='utf-8')
dashboard_now = dashboard_path.read_text(encoding='utf-8')
plan_now = plan_path.read_text(encoding='utf-8')
data_now = data_path.read_text(encoding='utf-8')
node_start = dashboard_now.index('class _DesktopNodeCard extends StatelessWidget {')
node_end = dashboard_now.index('\nclass ', node_start + 10)
node_now = dashboard_now[node_start:node_end]
assert 'class _DesktopMoneyActions extends StatelessWidget' in account_now
assert 'required this.onRecharge' not in account_now[
    account_now.index('class _DesktopBalanceMetric'):account_now.index('class _DesktopMoneyActions')
]
assert 'onTap: onTap,' not in node_now
assert 'syncCurrentPlanTitle' in plan_now
assert 'user.plan.trim().isEmpty && currentPlan != null' not in plan_now
assert 'user.plan.trim().isEmpty && currentPlan != null' not in data_now
print('desktop polish round 2 applied')
