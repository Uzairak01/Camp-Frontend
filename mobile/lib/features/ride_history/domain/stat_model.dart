import 'package:flutter/material.dart';

/// A single stat cell displayed in stat tile rows throughout Ride History.
class Stat {
  const Stat({
    required this.label,
    required this.value,
    this.unit,
    this.valueColor,
    this.unitColor,
  });

  /// Uppercase label shown below the value, e.g. "DISTANCE".
  final String label;

  /// Bold value string, e.g. "286.4".
  final String value;

  /// Optional unit shown after the value, e.g. "KM".
  final String? unit;

  /// Override color for the value text (defaults to AppColors.darkCharcoal on
  /// light tiles or white on dark tiles).
  final Color? valueColor;

  /// Override color for the unit text.
  final Color? unitColor;
}
