import 'package:material_ui/material_ui.dart';

import '../../app/core_controller.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_locale_copy.dart';

/// Elegant reference's standalone safety banner: a tinted, hairline-edged
/// card with a leading shield, a bold caption and a one-line status note.
///
/// Presentation only — it reads live [ConnectionStatus] and never drives the
/// tunnel. The connect orb and its keys remain the single control surface.
class V3MobileSafetyCard extends StatelessWidget {
  const V3MobileSafetyCard({
    super.key,
    required this.status,
    this.note,
  });

  final ConnectionStatus status;
  final String? note;

  ({Color tint, Color ink, IconData icon}) _resolve(
    BuildContext context,
    V3Palette p,
  ) =>
      switch (status) {
        ConnectionStatus.connected => (
            tint: p.success.withValues(alpha: .12),
            ink: p.successInk,
            icon: Icons.verified_user_rounded,
          ),
        ConnectionStatus.connecting ||
        ConnectionStatus.disconnecting => (
            tint: p.warning.withValues(alpha: .14),
            ink: p.warningInk,
            icon: Icons.hourglass_top_rounded,
          ),
        ConnectionStatus.error => (
            tint: p.danger.withValues(alpha: .12),
            ink: p.dangerInk,
            icon: Icons.gpp_bad_rounded,
          ),
        ConnectionStatus.disconnected => (
            tint: p.danger.withValues(alpha: .09),
            ink: p.dangerInk,
            icon: Icons.shield_outlined,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final s = _resolve(context, p);
    final caption = switch (status) {
      ConnectionStatus.connected => v3Copy(context,
          zh: '安全状态', en: 'Safety status', tw: '安全狀態'),
      ConnectionStatus.connecting ||
      ConnectionStatus.disconnecting => v3Copy(context,
          zh: '安全状态', en: 'Safety status', tw: '安全狀態'),
      ConnectionStatus.error ||
      ConnectionStatus.disconnected => v3Copy(context,
          zh: '安全状态', en: 'Safety status', tw: '安全狀態'),
    };
    final detail = note ??
        switch (status) {
          ConnectionStatus.connected => v3Copy(context,
              zh: '已连接 · 网络受保护',
              en: 'Connected · traffic protected',
              tw: '已連線 · 網路受保護'),
          ConnectionStatus.connecting ||
          ConnectionStatus.disconnecting => v3Copy(context,
              zh: '处理中 · 正在建立保护',
              en: 'Processing · establishing protection',
              tw: '處理中 · 正在建立保護'),
          ConnectionStatus.error => v3Copy(context,
              zh: '连接失败 · 当前网络不安全',
              en: 'Failed · current network unprotected',
              tw: '連線失敗 · 當前網路不安全'),
          ConnectionStatus.disconnected => v3Copy(context,
              zh: '未连接 · 当前网络不安全',
              en: 'Not connected · current network unprotected',
              tw: '未連線 · 當前網路不安全'),
        };
    return Container(
      key: const ValueKey('v3-mobile-safety-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: s.tint,
        borderRadius: BorderRadius.circular(V3Radius.card),
        border: Border.all(color: s.ink.withValues(alpha: .16)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(s.icon, size: 19, color: s.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption,
                  style: TextStyle(
                      color: p.ink, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: s.ink, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}
