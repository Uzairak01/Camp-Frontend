import 'dart:math';
import 'package:flutter/foundation.dart';

import 'maintenance_prediction_engine.dart';
import 'post_ride_report.dart';
import 'service_schedule_item.dart';
import 'service_schedule_status_formatter.dart';

/// Computed health and prediction for an individual service schedule item.
@immutable
class ServiceSchedulePrediction {
  const ServiceSchedulePrediction({
    required this.item,
    required this.scheduleStatus,
    this.effectiveIntervalKm,
    this.nextDueKm,
    this.remainingKm,
    this.nextDueDate,
    this.remainingDays,
    this.predictedDate,
    this.wearPercent = 0,
  });

  final ServiceScheduleItem item;
  final ScheduleItemStatus scheduleStatus;
  final int? effectiveIntervalKm;
  final double? nextDueKm;
  final int? remainingKm;
  final DateTime? nextDueDate;
  final int? remainingDays;
  final DateTime? predictedDate;
  final int wearPercent;

  String get id => item.id;
  String get bikeId => item.bikeId;
  ServiceItemType get type => item.type;
  String get name => item.type.displayName;

  /// Health score (0-100, where 100 is completely fresh).
  int get healthScore => (100 - wearPercent).clamp(0, 100);

  /// Bridge to [ComponentStatus] for compatibility with UI consumers.
  ComponentStatus get status {
    switch (scheduleStatus) {
      case ScheduleItemStatus.overdue:
        return ComponentStatus.overdue;
      case ScheduleItemStatus.dueSoon:
        return ComponentStatus.dueSoon;
      case ScheduleItemStatus.ok:
      case ScheduleItemStatus.addLastDone:
      case ScheduleItemStatus.notSetUp:
        return ComponentStatus.ok;
    }
  }

  ComponentStatus get componentStatus => status;

  /// Whether this item is overdue or due soon.
  bool get isDue =>
      scheduleStatus == ScheduleItemStatus.overdue ||
      scheduleStatus == ScheduleItemStatus.dueSoon;

  /// User-friendly status message formatted by the unified [ServiceScheduleStatusFormatter].
  ServiceStatusMessage get friendlyStatus => ServiceScheduleStatusFormatter.format(this);

  /// Subtitle for display in cards and alerts.
  String get displaySubtitle {
    switch (scheduleStatus) {
      case ScheduleItemStatus.notSetUp:
        return 'Not set up';
      case ScheduleItemStatus.addLastDone:
        return 'Interval configured';
      case ScheduleItemStatus.overdue:
        {
          final kmOverdue = remainingKm != null && remainingKm! <= 0;
          final daysOverdue = remainingDays != null && remainingDays! <= 0;
          if (kmOverdue && daysOverdue) {
            final overKm = remainingKm!.abs();
            final overDays = remainingDays!.abs();
            final parts = [
              if (overKm > 0) '$overKm km',
              if (overDays > 0) '$overDays ${overDays == 1 ? 'day' : 'days'}',
            ];
            return parts.isEmpty ? 'Overdue' : 'Overdue by ${parts.join(', ')}';
          }
          if (kmOverdue) {
            final over = remainingKm!.abs();
            return over == 0 ? 'Due now' : 'Overdue by $over km';
          }
          if (daysOverdue) {
            final daysOver = remainingDays!.abs();
            return daysOver == 0 ? 'Due today' : 'Overdue by $daysOver ${daysOver == 1 ? 'day' : 'days'}';
          }
          return 'Service overdue';
        }
      case ScheduleItemStatus.dueSoon:
        if (remainingKm != null && remainingDays != null) {
          return 'Due in $remainingKm km or $remainingDays days';
        }
        if (remainingKm != null) {
          return 'Due in $remainingKm km';
        }
        if (remainingDays != null) {
          return 'Due in $remainingDays days';
        }
        return 'Due soon';
      case ScheduleItemStatus.ok:
        if (remainingKm != null && remainingDays != null) {
          return 'In $remainingKm km or $remainingDays days';
        }
        if (remainingKm != null) {
          return 'In $remainingKm km';
        }
        if (remainingDays != null) {
          return 'In $remainingDays days';
        }
        return 'Up to date';
    }
  }
}

/// Pure Dart prediction engine implementing rider-set service schedules.
///
/// Contains NO hardcoded interval tables, NO modulo odometer wear logic,
/// and produces NO estimated costs.
class ServiceScheduleEngine {
  const ServiceScheduleEngine._();

  /// Evaluates an individual [ServiceScheduleItem] against the bike's current state.
  static ServiceSchedulePrediction evaluateItem({
    required ServiceScheduleItem item,
    required double currentOdometerKm,
    required bool isHarshConditions,
    required List<PostRideReport> recentReports,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();

    // 1. Not configured / disabled
    if (!item.enabled || !item.hasInterval) {
      return ServiceSchedulePrediction(
        item: item,
        scheduleStatus: ScheduleItemStatus.notSetUp,
        effectiveIntervalKm: item.effectiveIntervalKm(isHarshConditions),
      );
    }

    final effKm = item.effectiveIntervalKm(isHarshConditions);

    // 2. Interval configured, but missing last-done reference
    if (item.lastDoneKm == null && item.lastDoneDate == null) {
      return ServiceSchedulePrediction(
        item: item,
        scheduleStatus: ScheduleItemStatus.addLastDone,
        effectiveIntervalKm: effKm,
      );
    }

    // 3. Distance threshold calculation
    double? nextDueKm;
    int? remainingKm;
    double kmWearFraction = 0.0;

    if (effKm != null && effKm > 0 && item.lastDoneKm != null) {
      nextDueKm = item.lastDoneKm! + effKm;
      remainingKm = (nextDueKm - currentOdometerKm).round();
      final kmSince = currentOdometerKm - item.lastDoneKm!;
      kmWearFraction = kmSince > 0 ? (kmSince / effKm) : 0.0;
    }

    // 4. Date threshold calculation
    DateTime? nextDueDate;
    int? remainingDays;
    double daysWearFraction = 0.0;

    if (item.intervalMonths != null &&
        item.intervalMonths! > 0 &&
        item.lastDoneDate != null) {
      final baseDate = item.lastDoneDate!;
      // Month addition with year wrap
      final totalMonths = baseDate.month + item.intervalMonths!;
      final newYear = baseDate.year + ((totalMonths - 1) ~/ 12);
      final newMonth = ((totalMonths - 1) % 12) + 1;
      final maxDaysInMonth = DateTime(newYear, newMonth + 1, 0).day;
      final newDay = min(baseDate.day, maxDaysInMonth);

      nextDueDate = DateTime(newYear, newMonth, newDay, baseDate.hour, baseDate.minute);
      remainingDays = nextDueDate.difference(effectiveNow).inDays;

      final totalIntervalDays = max(1, nextDueDate.difference(baseDate).inDays);
      final daysSince = effectiveNow.difference(baseDate).inDays;
      daysWearFraction = daysSince > 0 ? (daysSince / totalIntervalDays) : 0.0;
    }

    // 5. Wear percentage calculation (0 - 100)
    final wearPercent =
        (max(kmWearFraction, daysWearFraction) * 100).round().clamp(0, 100);

    // 6. Status determination: Overdue > Due soon > OK
    // "Overdue when remaining km <= 0 or the due date has passed;
    // Due soon when remaining is <= 10% of the interval or <= 14 days; otherwise OK."
    final isKmOverdue = remainingKm != null && remainingKm <= 0;
    final isDateOverdue = remainingDays != null && remainingDays <= 0;

    final ScheduleItemStatus status;
    if (wearPercent >= 100 || isKmOverdue || isDateOverdue) {
      status = ScheduleItemStatus.overdue;
    } else {
      final isKmDueSoon = (remainingKm != null && remainingKm <= 200) ||
          (effKm != null && remainingKm != null && remainingKm <= (effKm * 0.20)) ||
          wearPercent >= 80;
      final isDateDueSoon = remainingDays != null && remainingDays <= 14;

      if (isKmDueSoon || isDateDueSoon) {
        status = ScheduleItemStatus.dueSoon;
      } else {
        status = ScheduleItemStatus.ok;
      }
    }

    // 7. Predicted date calculation strictly from rider's real trailing 30-day data
    // "Predicted date = remaining km ÷ the rider's real average km per day over the last 30 days
    // (from ride history and odometer updates). Show nothing if there are fewer than 7 days of data
    // or if no km were logged. Never estimate from defaults."
    DateTime? predictedDate;
    if (remainingKm != null && remainingKm > 0) {
      final avgKmPerDay = calculateRealAverageKmPerDay(
        bikeId: item.bikeId,
        recentReports: recentReports,
        now: effectiveNow,
      );

      if (avgKmPerDay != null && avgKmPerDay > 0) {
        final daysUntilDue = (remainingKm / avgKmPerDay).round();
        predictedDate = effectiveNow.add(Duration(days: daysUntilDue));
      }
    }

    return ServiceSchedulePrediction(
      item: item,
      scheduleStatus: status,
      effectiveIntervalKm: effKm,
      nextDueKm: nextDueKm,
      remainingKm: remainingKm,
      nextDueDate: nextDueDate,
      remainingDays: remainingDays,
      predictedDate: predictedDate,
      wearPercent: wearPercent,
    );
  }

  /// Calculates the real average km per day over the trailing 30 days.
  ///
  /// Returns `null` if there are fewer than 7 days of historical logging
  /// or if 0 km were logged.
  static double? calculateRealAverageKmPerDay({
    required String bikeId,
    required List<PostRideReport> recentReports,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final trailingCutoff = effectiveNow.subtract(const Duration(days: 30));

    // Filter reports in trailing 30-day window
    final relevant = recentReports
        .where((r) => r.bikeId == bikeId && r.date.isAfter(trailingCutoff))
        .toList();

    if (relevant.isEmpty) return null;

    // Determine earliest logged date in window
    DateTime earliest = relevant.first.date;
    double totalKm = 0.0;
    for (final r in relevant) {
      if (r.date.isBefore(earliest)) {
        earliest = r.date;
      }
      totalKm += r.distanceKm;
    }

    if (totalKm <= 0) return null;

    // Minimum 7 days of historical logging span
    final spanDays = effectiveNow.difference(earliest).inDays + 1;
    if (spanDays < 7) {
      return null;
    }

    final divisorDays = spanDays.clamp(7, 30);
    return totalKm / divisorDays;
  }
}
