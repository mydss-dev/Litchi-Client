import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../theme/v3_palette.dart';
import 'v3_mobile_components.dart';
import 'v3_notice_bar.dart';

/// Text-first announcement card backed by real server notices.
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
    // PageView needs a bounded height. Grow it with all four preview lines
    // instead of squeezing the text into the default-height card.
    final extraHeight = (scaler.scale(10) - 10 + scaler.scale(14) - 14 +
        2 * 1.55 * (scaler.scale(12) - 12)).clamp(0.0, double.infinity);
    final surface = V3MobileDesign.card(context);
    return Container(
      height: 128 + extraHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(V3MobileDesign.cardRadius),
        border: Border.all(color: V3MobileDesign.stroke(context)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(p.lychee.withValues(alpha: .07), surface),
            surface,
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(V3MobileDesign.cardRadius),
        child: Stack(children: [
          PageView.builder(
            controller: _pages,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) =>
              _NoticeItem(notice: notices[i], onTap: () async {
                await V3NoticeDialog.showReader(
                  context, notices: notices, initialIndex: i);
              }),
          ),
          Positioned(top: 14, right: 14, child: Row(children: [
            for (var i = 0; i < count; i++) ...[
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? p.lychee : p.inkMuted.withValues(alpha: .35),
                  shape: BoxShape.circle)),
              if (i < count - 1) const SizedBox(width: 4),
            ],
          ])),
        ]),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: p.surfaceRaised,
                  borderRadius: BorderRadius.circular(99)),
                child: Text('公告', style: TextStyle(
                  color: p.inkMuted, fontSize: 10,
                  fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(
                v3NoticeHeadline(notice, fallback: '公告'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.ink,
                  fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(v3NoticeText(notice.content).replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.inkMuted, fontSize: 12, height: 1.55)),
            ],
          ),
        ),
      ),
    );
  }
}
