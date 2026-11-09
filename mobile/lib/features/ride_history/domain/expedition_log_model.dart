import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import 'stat_model.dart';

/// A footer content shape: either a list of chip labels or a plain note string.
sealed class ExpeditionFooter {
  const ExpeditionFooter();
}

class ExpeditionFooterChips extends ExpeditionFooter {
  const ExpeditionFooterChips(this.chips);
  final List<String> chips;
}

class ExpeditionFooterNote extends ExpeditionFooter {
  const ExpeditionFooterNote(this.note);
  final String note;
}

/// Represents one logged expedition entry displayed in the Ride History screen.
class ExpeditionLog {
  const ExpeditionLog({
    required this.date,
    required this.tag,
    required this.tagVariant,
    required this.icon,
    required this.title,
    required this.route,
    required this.bike,
    required this.stats,
    required this.footer,
    required this.footerLink,
    this.tagIcon,
  });

  /// Display date for the pill, e.g. "OCT 11, 2024".
  final String date;

  /// Status chip label, e.g. "Verified Loop".
  final String tag;

  /// StatusChip variant (success / warning / neutral).
  final StatusChipVariant tagVariant;

  /// Leading icon for the card (right of date + tag row), muted or orange.
  final IconData icon;

  /// Optional icon for the StatusChip.
  final IconData? tagIcon;

  /// Card heading, e.g. "Karakoram High-Altitude Corridor".
  final String title;

  /// Sub-heading: "Hasan Abdal → Khunjerab Border • KTM 890 Adv R".
  final String route;

  /// Bike name substring (used separately if needed).
  final String bike;

  /// Four stat tiles shown in a row.
  final List<Stat> stats;

  /// Footer content — chips or a plain note.
  final ExpeditionFooter footer;

  /// Orange link label shown on the right, e.g. "Review GPS →".
  final String footerLink;
}
