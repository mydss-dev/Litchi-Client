import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart' show UserModel;
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_text_styles.dart';

class ExpiryBanner extends StatelessWidget {
  const ExpiryBanner({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    if (user.expiry.isEmpty) return const SizedBox.shrink();
    final expiry = DateTime.tryParse(user.expiry);
    if (expiry == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final daysLeft = expiryDay.difference(today).inDays;

    if (daysLeft > 7) return const SizedBox.shrink();

    final c = AppColors.of(context);
    // Banner content derives from the [user] prop — no need to subscribe to the
    // controller; read it only to navigate on tap.
    final ctrl = AppScope.read(context);
    final color = daysLeft <= 0 ? c.danger : c.warning;
    final message = daysLeft < 0
        ? context.l10n.subscriptionExpired
        : daysLeft == 0
        ? context.l10n.subscriptionExpiresToday
        : context.l10n.subscriptionExpiresInDays(daysLeft);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => ctrl.goToPage(AppPage.shop),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.alertTriangle, size: 16, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.body.copyWith(
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.renewNow,
                  style: AppTextStyles.button.copyWith(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
