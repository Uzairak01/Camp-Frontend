import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import 'service_schedule_engine.dart';
import 'service_schedule_item.dart';

/// Semantic status type for a service schedule item.
enum ServiceStatusType {
  notSetUp,
  upcoming,
  approaching,
  dueNow,
  overdue,
  veryOverdue,
}

/// Structured friendly status message for a service schedule item.
///
/// Guaranteed identical across Service Schedule, Finances, Maintenance tab, and Home.
@immutable
class ServiceStatusMessage {
  const ServiceStatusMessage({
    required this.headline,
    required this.color,
    required this.statusType,
    this.detail,
    this.actionLabel,
    this.isVeryOverdue = false,
    this.reason,
  });

  /// Primary friendly status message (e.g. "1,250 km until your next oil filter change.").
  final String headline;

  /// Secondary detail line (e.g. "Next at 47,250 km" or "Due on 12 Dec 2026").
  final String? detail;

  /// Action label if actionable (e.g. "Edit last service" when very overdue).
  final String? actionLabel;

  /// Semantic theme color: green (upcoming), amber/orange (approaching), red (due/overdue).
  final Color color;

  /// The classified status type.
  final ServiceStatusType statusType;

  /// Whether the item is more than 2x the interval overdue.
  final bool isVeryOverdue;

  /// Whichever-comes-first reason ("by km" or "by date") when both intervals are configured.
  final String? reason;

  /// Convenience full text combining headline and detail if present.
  String get displayText => (detail != null && detail!.isNotEmpty)
      ? '$headline $detail'
      : headline;

  @override
  String toString() => displayText;
}

/// Shared pure Dart formatter for user-friendly service schedule status messages.
///
/// Implements the exact friendly status rules across all surfaces:
///  - Upcoming: "1,250 km until your next oil filter change." (second line "Next at 47,250 km")
///  - Approaching: "Only 100 km left until your next service."
///  - Due now: "Your oil filter service is due now."
///  - Overdue: "Your oil filter service is 10 km overdue."
///  - Very overdue (>2x interval): "... 44,250 km overdue. The last service reading may be wrong."
///  - Time-based: "2 months until your next service. Due on 12 Dec 2026" / "Your service is 5 days overdue"
///  - Not set up: "Add when you last did this to get reminders."
class ServiceScheduleStatusFormatter {
  const ServiceScheduleStatusFormatter._();

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Formats an integer with standard thousands separators (e.g. 47,250).
  static String formatNumber(num n) {
    final int intVal = n.round();
    final bool isNegative = intVal < 0;
    final String str = intVal.abs().toString();
    final StringBuffer buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write(',');
      }
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return isNegative ? '-$formatted' : formatted;
  }

  /// Formats a DateTime as "12 Dec 2026".
  static String formatDate(DateTime date) {
    final day = date.day;
    final month = _monthNames[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  /// Returns the component action phrase used in upcoming messages
  /// (e.g. "oil filter change", "engine oil change").
  static String getComponentAction(ServiceItemType type, [String? customTitle]) {
    switch (type) {
      case ServiceItemType.oilFilter:
        return 'oil filter change';
      case ServiceItemType.oilAndSmallService:
        return 'engine oil change';
      case ServiceItemType.airFilter:
        return 'air filter change';
      case ServiceItemType.chain:
        return 'chain & sprocket service';
      case ServiceItemType.sparkPlug:
        return 'spark plug change';
      case ServiceItemType.tuning:
        return 'tuning';
      case ServiceItemType.brakes:
        return 'front brake pad service';
      case ServiceItemType.rearBrakes:
        return 'rear brake service';
      case ServiceItemType.tyres:
        return 'tyre check';
      case ServiceItemType.battery:
        return 'battery check';
      case ServiceItemType.carburetor:
        return 'carburetor service';
      case ServiceItemType.custom:
        final name = (customTitle != null && customTitle.isNotEmpty)
            ? customTitle.toLowerCase()
            : 'custom';
        return '$name service';
    }
  }

  /// Returns the component noun used in due and overdue messages
  /// (e.g. "oil filter", "engine oil").
  static String getComponentNoun(ServiceItemType type, [String? customTitle]) {
    switch (type) {
      case ServiceItemType.oilFilter:
        return 'oil filter';
      case ServiceItemType.oilAndSmallService:
        return 'engine oil';
      case ServiceItemType.airFilter:
        return 'air filter';
      case ServiceItemType.chain:
        return 'chain';
      case ServiceItemType.sparkPlug:
        return 'spark plug';
      case ServiceItemType.tuning:
        return 'tuning';
      case ServiceItemType.brakes:
        return 'front brake pad';
      case ServiceItemType.rearBrakes:
        return 'rear brake';
      case ServiceItemType.tyres:
        return 'tyre';
      case ServiceItemType.battery:
        return 'battery';
      case ServiceItemType.carburetor:
        return 'carburetor';
      case ServiceItemType.custom:
        return (customTitle != null && customTitle.isNotEmpty)
            ? customTitle.toLowerCase()
            : 'custom item';
    }
  }

  /// Formats the friendly status for a [ServiceSchedulePrediction].
  static ServiceStatusMessage format(ServiceSchedulePrediction prediction) {
    final item = prediction.item;

    // 1. Not configured or missing baseline
    if (!item.enabled || !item.hasInterval || !item.hasLastDone) {
      return const ServiceStatusMessage(
        headline: 'Add when you last did this to get reminders.',
        color: AppColors.mutedText,
        statusType: ServiceStatusType.notSetUp,
      );
    }

    final hasKm = prediction.remainingKm != null && prediction.effectiveIntervalKm != null;
    final hasDays = prediction.remainingDays != null && item.intervalMonths != null;

    // Whichever comes first logic when both are configured
    bool preferKm = true;
    String? reason;

    if (hasKm && hasDays) {
      final remKm = prediction.remainingKm!;
      final remDays = prediction.remainingDays!;
      final effKm = prediction.effectiveIntervalKm!;
      final totalDays = item.intervalMonths! * 30;

      if (remKm <= 0 && remDays > 0) {
        preferKm = true;
      } else if (remDays <= 0 && remKm > 0) {
        preferKm = false;
      } else if (remKm <= 0 && remDays <= 0) {
        final kmRatio = remKm.abs() / effKm;
        final daysRatio = remDays.abs() / totalDays;
        preferKm = kmRatio >= daysRatio;
      } else {
        final kmRatio = remKm / effKm;
        final daysRatio = remDays / totalDays;
        preferKm = kmRatio <= daysRatio;
      }
      reason = preferKm ? 'by km' : 'by date';
    } else if (hasKm) {
      preferKm = true;
      reason = null;
    } else {
      preferKm = false;
      reason = null;
    }

    final noun = getComponentNoun(item.type, item.customTitle);
    final action = getComponentAction(item.type, item.customTitle);
    final reasonSuffix = reason != null ? ' ($reason)' : '';

    if (preferKm && hasKm) {
      final remKm = prediction.remainingKm!;
      final effInterval = prediction.effectiveIntervalKm!;
      final nextDueKm = prediction.nextDueKm?.round();

      // Overdue
      if (remKm < 0) {
        final overdueKm = remKm.abs();
        final isVeryOverdue = overdueKm > (2 * effInterval);

        if (isVeryOverdue) {
          return ServiceStatusMessage(
            headline: 'Your $noun service is ${formatNumber(overdueKm)} km overdue$reasonSuffix. The last service reading may be wrong.',
            actionLabel: 'Edit last service',
            color: AppColors.alertRed,
            statusType: ServiceStatusType.veryOverdue,
            isVeryOverdue: true,
            reason: reason,
          );
        }

        return ServiceStatusMessage(
          headline: 'Your $noun service is ${formatNumber(overdueKm)} km overdue$reasonSuffix.',
          color: AppColors.alertRed,
          statusType: ServiceStatusType.overdue,
          isVeryOverdue: false,
          reason: reason,
        );
      }

      // Due now (exactly 0)
      if (remKm == 0) {
        return ServiceStatusMessage(
          headline: 'Your $noun service is due now$reasonSuffix.',
          color: AppColors.alertRed,
          statusType: ServiceStatusType.dueNow,
          reason: reason,
        );
      }

      // Approaching (dueSoon)
      if (prediction.scheduleStatus == ScheduleItemStatus.dueSoon) {
        return ServiceStatusMessage(
          headline: 'Only ${formatNumber(remKm)} km left until your next service$reasonSuffix.',
          detail: nextDueKm != null ? 'Next at ${formatNumber(nextDueKm)} km' : null,
          color: AppColors.tacticalOrange,
          statusType: ServiceStatusType.approaching,
          reason: reason,
        );
      }

      // Upcoming (OK)
      return ServiceStatusMessage(
        headline: '${formatNumber(remKm)} km until your next $action$reasonSuffix.',
        detail: nextDueKm != null ? 'Next at ${formatNumber(nextDueKm)} km' : null,
        color: AppColors.statusGreen,
        statusType: ServiceStatusType.upcoming,
        reason: reason,
      );
    }

    // Time-based
    if (hasDays) {
      final remDays = prediction.remainingDays!;
      final nextDueDate = prediction.nextDueDate;
      final dueOnText = nextDueDate != null ? 'Due on ${formatDate(nextDueDate)}' : null;
      final totalIntervalDays = item.intervalMonths! * 30;

      // Overdue
      if (remDays < 0) {
        final overdueDays = remDays.abs();
        final isVeryOverdue = overdueDays > (2 * totalIntervalDays);

        if (isVeryOverdue) {
          return ServiceStatusMessage(
            headline: 'Your service is $overdueDays days overdue$reasonSuffix. The last service reading may be wrong.',
            actionLabel: 'Edit last service',
            color: AppColors.alertRed,
            statusType: ServiceStatusType.veryOverdue,
            isVeryOverdue: true,
            reason: reason,
          );
        }

        return ServiceStatusMessage(
          headline: 'Your service is $overdueDays ${overdueDays == 1 ? 'day' : 'days'} overdue$reasonSuffix.',
          color: AppColors.alertRed,
          statusType: ServiceStatusType.overdue,
          reason: reason,
        );
      }

      // Due today (0)
      if (remDays == 0) {
        return ServiceStatusMessage(
          headline: 'Your service is due today$reasonSuffix.',
          color: AppColors.alertRed,
          statusType: ServiceStatusType.dueNow,
          reason: reason,
        );
      }

      // Approaching
      if (prediction.scheduleStatus == ScheduleItemStatus.dueSoon) {
        return ServiceStatusMessage(
          headline: 'Only $remDays ${remDays == 1 ? 'day' : 'days'} left until your next service$reasonSuffix.',
          detail: dueOnText,
          color: AppColors.tacticalOrange,
          statusType: ServiceStatusType.approaching,
          reason: reason,
        );
      }

      // Upcoming
      final monthsRemaining = (remDays / 30).round();
      final String timeHeadline;
      if (monthsRemaining >= 2) {
        timeHeadline = '$monthsRemaining months until your next service$reasonSuffix.';
      } else if (monthsRemaining == 1) {
        timeHeadline = '1 month until your next service$reasonSuffix.';
      } else {
        timeHeadline = '$remDays ${remDays == 1 ? 'day' : 'days'} until your next service$reasonSuffix.';
      }

      return ServiceStatusMessage(
        headline: dueOnText != null ? '$timeHeadline $dueOnText' : timeHeadline,
        detail: dueOnText,
        color: AppColors.statusGreen,
        statusType: ServiceStatusType.upcoming,
        reason: reason,
      );
    }

    return const ServiceStatusMessage(
      headline: 'Add when you last did this to get reminders.',
      color: AppColors.mutedText,
      statusType: ServiceStatusType.notSetUp,
    );
  }
}
