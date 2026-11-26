import 'package:material_ui/material_ui.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';
import 'v3_mobile_components.dart';
import 'v3_notice_bar.dart';
import '../../shared/theme/app_icons.dart';

/// Slim announcement strip backed by real server notices.
///
/// One line (icon, headline, page dots, chevron) instead of a full card, so
/// the connection surface keeps the top of the screen. Tapping opens the
/// reader on the visible notice; swiping pages through up to six notices.
class V3HtmlPhoneNotice extends StatefulWidget {
  const V3HtmlPhoneNotice({super.key, required this.controller});
  final AppController controller;

  @override
  State<V3HtmlPhoneNotice> createState() => _V3HtmlPhoneNoticeState();
}

class _V3HtmlPhoneNoticeState extends State<V3HtmlPhoneNotice> {
  int _index = 0;
  final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final notices = widget.controller.notices.take(6).toList();
    if (notices.isEmpty) return const SizedBox.shrink();
    final count = notices.length;
    final scaler = MediaQuery.textScalerOf(context);
    final height = 52 + (scaler.scale(13) - 13).clamp(0.0, double.infinity);
    return Padding(
      padding: const EdgeInsets.only(bottom: V3MobileDesign.cardGap),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          // Floats over the dot map: a warm, barely-tinted surface with a
          // hairline of the same coral, so it reads as a notice laid on the
          // canvas rather than another white card in the stack.
          color: Color.alphaBlend(
            p.lychee.withValues(alpha: .07),
            V3MobileDesign.card(context),
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.lychee.withValues(alpha: .16)),
          boxShadow: [
            BoxShadow(
              color: p.ink.withValues(alpha: .05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(children: [
            const SizedBox(width: 12),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.lychee.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(AppIcons.broadcast, size: 16, color: p.lycheeInk),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _NoticeItem(
                  notice: notices[i],
                  onTap: () => V3NoticeDialog.showReader(
                    context, notices: notices, initialIndex: i),
                ),
              ),
            ),
            if (count > 1) ...[
              const SizedBox(width: 8),
              for (var i = 0; i < count; i++) ...[
                Container(
                  width: i == _index ? 12 : 5, height: 5,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? p.ink : p.inkMuted.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(99))),
                if (i < count - 1) const SizedBox(width: 3),
              ],
            ],
            const SizedBox(width: 6),
            Icon(AppIcons.chevronRight, size: 18, color: p.inkMuted),
            const SizedBox(width: 10),
          ]),
        ),
      ),
    );
  }
}

class _NoticeItem extends StatelessWidget {
  const _NoticeItem({required this.notice, required this.onTap});
  final NoticeModel notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final fallback = v3Copy(context, zh: '公告', en: 'Notice', tw: '公告');
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            v3NoticeHeadline(notice, fallback: fallback),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink,
              fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
