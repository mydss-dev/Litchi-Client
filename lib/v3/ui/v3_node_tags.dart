import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

/// Compact, read-only server labels shared by the dashboard and both node views.
/// No synthetic Premium/streaming claims are introduced by the client.
class V3NodeTags extends StatelessWidget {
  const V3NodeTags({super.key, required this.tags, this.maxVisible = 3});

  final List<String> tags;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty || maxVisible <= 0) return const SizedBox.shrink();
    final p = V3Palette.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tag in tags.take(maxVisible))
          Tooltip(
            message: tag,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(99),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: Text(
                  tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        if (tags.length > maxVisible)
          Text(
            '+${tags.length - maxVisible}',
            style: TextStyle(color: p.inkMuted, fontSize: 10),
          ),
      ],
    );
  }
}
