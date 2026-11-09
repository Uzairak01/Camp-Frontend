/// Trip Budget & Fuel Economics domain model.
class TripBudget {
  const TripBudget({
    required this.tripName,
    required this.capAmount,
    this.id = 'budget-active',
    this.startDate,
    this.endDate,
    this.allocatedSoFar = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  factory TripBudget.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final rawId = json['id'] as String?;
    final effectiveId = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : 'budget-active';

    final createdUtc = parseUtc(json['createdAt']) ?? DateTime.now().toUtc();
    final updatedUtc = parseUtc(json['updatedAt']) ?? createdUtc;

    return TripBudget(
      id: effectiveId,
      tripName: json['tripName'] as String? ?? 'Trip Budget',
      capAmount: parseDouble(json['capAmount']),
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      allocatedSoFar: parseDouble(json['allocatedSoFar']),
      createdAt: createdUtc,
      updatedAt: updatedUtc,
    );
  }

  final String id;
  final String tripName;
  final double capAmount;
  final String? startDate;
  final String? endDate;
  final double allocatedSoFar;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveId => id;
  DateTime get effectiveCreatedAt =>
      createdAt?.toUtc() ?? DateTime(2024, 1, 1).toUtc();
  DateTime get effectiveUpdatedAt =>
      updatedAt?.toUtc() ?? effectiveCreatedAt;

  /// Parsed DateTime representations of the optional date strings.
  DateTime? get parsedStartDate => parseTripDate(startDate);
  DateTime? get parsedEndDate => parseTripDate(endDate);

  /// Human-readable date range for cards and PDF exports.
  String get dateRangeDisplay {
    final start = startDate?.trim();
    final end = endDate?.trim();
    if (start != null && start.isNotEmpty && end != null && end.isNotEmpty) {
      return '$start – $end';
    } else if (start != null && start.isNotEmpty) {
      return 'From $start';
    } else if (end != null && end.isNotEmpty) {
      return 'Until $end';
    }
    return '';
  }

  /// Progress ratio clamped between 0.0 and 1.0 for progress indicators
  double get spentRatio =>
      capAmount > 0 ? (allocatedSoFar / capAmount).clamp(0.0, 1.0) : 0.0;

  /// Integer percentage e.g. 62
  int get spentPercentInt =>
      capAmount > 0 ? ((allocatedSoFar / capAmount) * 100).round() : 0;

  /// Remaining amount below cap
  double get remainingAmount => (capAmount - allocatedSoFar);

  /// Alias for remaining amount under budget
  double get underBudgetAmount => (capAmount - allocatedSoFar);

  /// Remaining percentage e.g. 38.5
  double get remainingPercent =>
      capAmount > 0 ? (100.0 - (allocatedSoFar / capAmount * 100.0)).clamp(0.0, 100.0) : 0.0;

  bool get isUnderBudget => allocatedSoFar <= capAmount;

  TripBudget copyWith({
    String? id,
    String? tripName,
    double? capAmount,
    String? startDate,
    String? endDate,
    double? allocatedSoFar,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripBudget(
      id: id ?? this.id,
      tripName: tripName ?? this.tripName,
      capAmount: capAmount ?? this.capAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      allocatedSoFar: allocatedSoFar ?? this.allocatedSoFar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TripBudget &&
          runtimeType == other.runtimeType &&
          tripName == other.tripName &&
          capAmount == other.capAmount &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          allocatedSoFar == other.allocatedSoFar;

  @override
  int get hashCode => Object.hash(
        tripName,
        capAmount,
        startDate,
        endDate,
        allocatedSoFar,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': effectiveCreatedAt.toIso8601String(),
        'updatedAt': effectiveUpdatedAt.toIso8601String(),
        'tripName': tripName,
        'capAmount': capAmount,
        'startDate': startDate,
        'endDate': endDate,
        'allocatedSoFar': allocatedSoFar,
      };
}

/// Month abbreviation names for trip date formatting.
const List<String> kTripMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a [DateTime] into "MMM d, y" (e.g. "Oct 12, 2026") in local time.
String formatTripDate(DateTime dt) {
  final local = dt.toLocal();
  return '${kTripMonths[local.month - 1]} ${local.day}, ${local.year}';
}

/// Tolerantly parses a date string in "MMM d, y", "yyyy-MM-dd", or ISO format.
DateTime? parseTripDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final str = raw.trim();

  // Try direct ISO / DateTime parser
  final parsedIso = DateTime.tryParse(str);
  if (parsedIso != null) return parsedIso;

  // Try "MMM d, y" e.g. "Oct 12, 2026"
  final match = RegExp(r'^([A-Za-z]{3,9})\s+(\d{1,2}),?\s+(\d{4})$').firstMatch(str);
  if (match != null) {
    final mStr = match.group(1)!.toLowerCase();
    const map = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    final month = map[mStr];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (month != null && day != null && year != null) {
      return DateTime(year, month, day);
    }
  }
  return null;
}

