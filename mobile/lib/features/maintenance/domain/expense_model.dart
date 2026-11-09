import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';

/// Categories for expedition expenses
enum ExpenseCategory {
  fuel,
  permits,
  lodging,
  parts,
  service,
  food,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.fuel:
        return 'Fuel';
      case ExpenseCategory.permits:
        return 'Permits';
      case ExpenseCategory.lodging:
        return 'Lodging';
      case ExpenseCategory.parts:
        return 'Parts';
      case ExpenseCategory.service:
        return 'Service';
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  String get chipLabel {
    switch (this) {
      case ExpenseCategory.fuel:
        return '🛢 Fuel';
      case ExpenseCategory.permits:
        return '🎫 Permits';
      case ExpenseCategory.lodging:
        return '⛺ Lodging';
      case ExpenseCategory.parts:
        return '🔧 Parts';
      case ExpenseCategory.service:
        return '🛠 Service';
      case ExpenseCategory.food:
        return '🍴 Food';
      case ExpenseCategory.other:
        return '⋯ Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ExpenseCategory.fuel:
        return Icons.local_gas_station_rounded;
      case ExpenseCategory.permits:
        return Icons.confirmation_number_rounded;
      case ExpenseCategory.lodging:
        return Icons.holiday_village_rounded;
      case ExpenseCategory.parts:
        return Icons.build_circle_rounded;
      case ExpenseCategory.service:
        return Icons.handyman_rounded;
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }
}

/// Telemetry vs Manual Entry mode
enum ExpenseTrackingMode {
  autoTrack,
  manualEntry;

  String get label {
    switch (this) {
      case ExpenseTrackingMode.autoTrack:
        return 'Auto';
      case ExpenseTrackingMode.manualEntry:
        return 'Manual';
    }
  }
}

/// An expense record in a trip's budget ledger
class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.title,
    required this.amount,
    required this.trackingMode,
    this.bikeId,
    this.maintenanceItemId,
    this.litres,
    this.pricePerLitre,
    this.isFullTank = false,
    this.subtitle,
    this.note,
    this.dateRecorded,
    this.formattedDate,
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val)?.toUtc();
      return null;
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val.trim());
      return null;
    }

    final rawId = json['id'] as String?;
    final effectiveId = (rawId != null && rawId.trim().isNotEmpty)
        ? rawId.trim()
        : 'exp-${DateTime.now().millisecondsSinceEpoch}';

    final dateRec = json['dateRecorded'] != null
        ? DateTime.tryParse(json['dateRecorded'] as String)
        : null;
    final createdUtc =
        parseUtc(json['createdAt']) ?? dateRec?.toUtc() ?? DateTime.now().toUtc();
    final updatedUtc = parseUtc(json['updatedAt']) ?? createdUtc;

    final parsedLitres = parseDouble(json['litres'] ?? json['liters']);
    final parsedPricePerLitre = parseDouble(
      json['pricePerLitre'] ?? json['price_per_litre'] ?? json['pricePerLiter'],
    );

    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is String) {
        final s = val.toLowerCase().trim();
        return s == 'true' || s == '1';
      }
      if (val is num) return val == 1;
      return false;
    }

    final parsedIsFullTank = parseBool(
      json['isFullTank'] ?? json['is_full_tank'] ?? json['fullTank'],
    );

    final rawBikeId = json['bikeId'] as String?;
    final rawMaintId = (json['maintenanceItemId'] ??
        json['maintenance_item_id'] ??
        json['serviceVisitId']) as String?;

    return Expense(
      id: effectiveId,
      createdAt: createdUtc,
      updatedAt: updatedUtc,
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => ExpenseCategory.other,
      ),
      title: json['title'] as String? ?? 'Expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      trackingMode: json['trackingMode'] == 'autoTrack'
          ? ExpenseTrackingMode.autoTrack
          : ExpenseTrackingMode.manualEntry,
      bikeId: (rawBikeId != null && rawBikeId.trim().isNotEmpty)
          ? rawBikeId.trim()
          : null,
      maintenanceItemId: (rawMaintId != null && rawMaintId.trim().isNotEmpty)
          ? rawMaintId.trim()
          : null,
      litres: parsedLitres,
      pricePerLitre: parsedPricePerLitre,
      isFullTank: parsedIsFullTank,
      subtitle: json['subtitle'] as String?,
      note: json['note'] as String?,
      dateRecorded: dateRec,
      formattedDate: json['formattedDate'] as String?,
    );
  }

  final String id;
  final String? bikeId;
  final String? maintenanceItemId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get effectiveId => id;
  DateTime get effectiveCreatedAt =>
      createdAt?.toUtc() ?? dateRecorded?.toUtc() ?? DateTime.now().toUtc();
  DateTime get effectiveUpdatedAt =>
      updatedAt?.toUtc() ?? effectiveCreatedAt;

  final ExpenseCategory category;
  final String title;
  final double amount;
  final ExpenseTrackingMode trackingMode;
  final double? litres;
  final double? pricePerLitre;
  final bool isFullTank;
  final String? subtitle;
  final String? note;
  final DateTime? dateRecorded;
  final String? formattedDate;

  /// Returns the formatted subtitle for display.
  /// For fuel expenses:
  /// - If both [litres] and [pricePerLitre] are present, returns e.g. "10 L at Rs 275/L".
  /// - For older refills without [litres] or [pricePerLitre], returns null so only the amount is shown.
  /// For other categories, returns [subtitle].
  String? get displaySubtitle {
    if (category == ExpenseCategory.fuel) {
      if (litres != null && litres! > 0 && pricePerLitre != null && pricePerLitre! > 0) {
        final lStr = litres!.toStringAsFixed(2);
        return '$lStr L at ${formatPkr(pricePerLitre)}/L';
      }
      return null;
    }
    return subtitle;
  }

  static const _sentinel = Object();

  Expense copyWith({
    String? id,
    ExpenseCategory? category,
    String? title,
    double? amount,
    ExpenseTrackingMode? trackingMode,
    Object? bikeId = _sentinel,
    Object? maintenanceItemId = _sentinel,
    double? litres,
    double? pricePerLitre,
    bool? isFullTank,
    String? subtitle,
    String? note,
    DateTime? dateRecorded,
    String? formattedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      trackingMode: trackingMode ?? this.trackingMode,
      bikeId: identical(bikeId, _sentinel) ? this.bikeId : (bikeId as String?),
      maintenanceItemId: identical(maintenanceItemId, _sentinel)
          ? this.maintenanceItemId
          : (maintenanceItemId as String?),
      litres: litres ?? this.litres,
      pricePerLitre: pricePerLitre ?? this.pricePerLitre,
      isFullTank: isFullTank ?? this.isFullTank,
      subtitle: subtitle ?? this.subtitle,
      note: note ?? this.note,
      dateRecorded: dateRecorded ?? this.dateRecorded,
      formattedDate: formattedDate ?? this.formattedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          title == other.title &&
          amount == other.amount &&
          trackingMode == other.trackingMode &&
          bikeId == other.bikeId &&
          maintenanceItemId == other.maintenanceItemId &&
          litres == other.litres &&
          pricePerLitre == other.pricePerLitre &&
          isFullTank == other.isFullTank &&
          subtitle == other.subtitle &&
          note == other.note &&
          dateRecorded == other.dateRecorded &&
          formattedDate == other.formattedDate;

  @override
  int get hashCode => Object.hash(
        id,
        category,
        title,
        amount,
        trackingMode,
        bikeId,
        maintenanceItemId,
        litres,
        pricePerLitre,
        isFullTank,
        subtitle,
        note,
        dateRecorded,
        formattedDate,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'createdAt': effectiveCreatedAt.toIso8601String(),
      'updatedAt': effectiveUpdatedAt.toIso8601String(),
      'category': category.name,
      'title': title,
      'amount': amount,
      'trackingMode': trackingMode.name,
      'isFullTank': isFullTank,
      'subtitle': subtitle,
      'note': note,
      'dateRecorded': dateRecorded?.toIso8601String(),
      'formattedDate': formattedDate,
    };
    if (bikeId != null) map['bikeId'] = bikeId;
    if (maintenanceItemId != null) map['maintenanceItemId'] = maintenanceItemId;
    if (litres != null) map['litres'] = litres;
    if (pricePerLitre != null) map['pricePerLitre'] = pricePerLitre;
    return map;
  }
}
