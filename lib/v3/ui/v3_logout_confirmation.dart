import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';

/// A destructive account action must not execute from an accidental tap.
Future<bool> showV3LogoutConfirmation(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.48),
    builder: (dialogContext) {
      final p = V3Palette.of(dialogContext);
      return AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(V3Radius.panel)),
        title: Text(
          v3Copy(dialogContext, zh: '确认退出登录', en: 'Log out?', tw: '確認登出'),
        ),
        content: Text(
          v3Copy(
            dialogContext,
            zh: '退出后需要重新登录，确定继续吗？',
            en: 'You will need to sign in again. Continue?',
            tw: '登出後需要重新登入，確定繼續嗎？',
          ),
        ),
        actions: [
          TextButton(
            key: const Key('v3-logout-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              v3Copy(dialogContext, zh: '取消', en: 'Cancel', tw: '取消'),
            ),
          ),
          FilledButton(
            key: const Key('v3-logout-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: p.danger,
              foregroundColor: p.onDanger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              v3Copy(dialogContext, zh: '退出登录', en: 'Log out', tw: '登出'),
            ),
          ),
        ],
      );
    },
  );
  return accepted == true;
}
