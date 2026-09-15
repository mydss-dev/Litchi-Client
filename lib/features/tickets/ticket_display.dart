import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';

String ticketPriorityLabel(BuildContext context, int level) => switch (level) {
  2 => context.l10n.priorityUrgent,
  1 => context.l10n.priorityMedium,
  _ => context.l10n.priorityLow,
};

String ticketStatusLabel(BuildContext context, bool isOpen) =>
    isOpen ? context.l10n.processing : context.l10n.ticketClosedStatus;
