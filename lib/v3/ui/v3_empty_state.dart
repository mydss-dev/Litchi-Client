import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

/// Shared empty/failure state: a raised icon tile, a title, one muted line
/// and an optional action. Every list that can be empty — tickets, orders,
/// the node picker — speaks in this one voice instead of growing private
/// variants, so an empty screen reads as a deliberate pause, not a dead end
/// (M3/Apple HIG: state the emptiness, explain the way out, offer one step).
class V3EmptyState extends StatelessWidget {
  const V3EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(V3Radius.card),
            ),
            child: Icon(icon, color: p.inkMuted, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: p.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkMuted, fontSize: 11, height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            // Tonal emphasis: one accent-tinted step out of the emptiness,
            // quieter than the page's primary CTA but clearly the way forward.
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.lycheeSoft,
                foregroundColor: p.lycheeInk,
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ]),
      ),
    );
  }
}
