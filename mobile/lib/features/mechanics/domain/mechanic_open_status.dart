import 'mechanic_model.dart';

enum MechanicStatusType {
  notSet,
  open,
  closed,
}

class MechanicStatus {
  const MechanicStatus._({
    required this.type,
    this.closesAt,
    this.opensAt,
    this.opensDay,
    this.isOpen24Hours = false,
  });

  const MechanicStatus.notSet() : this._(type: MechanicStatusType.notSet);

  const MechanicStatus.open({
    String? closesAt,
    bool isOpen24Hours = false,
  }) : this._(
          type: MechanicStatusType.open,
          closesAt: closesAt,
          isOpen24Hours: isOpen24Hours,
        );

  const MechanicStatus.closed({
    required String opensAt,
    String? opensDay,
  }) : this._(
          type: MechanicStatusType.closed,
          opensAt: opensAt,
          opensDay: opensDay,
        );

  final MechanicStatusType type;
  final String? closesAt;
  final String? opensAt;
  final String? opensDay;
  final bool isOpen24Hours;

  bool get isNotSet => type == MechanicStatusType.notSet;
  bool get isOpen => type == MechanicStatusType.open;
  bool get isClosed => type == MechanicStatusType.closed;

  /// Returns user-facing status label:
  /// - "Open 24 hours"
  /// - "Open now, closes 7:00 PM"
  /// - "Closed, opens Mon 9:00 AM" (or "Closed, opens 9:00 AM" if today)
  /// - "" if notSet
  String get displayText {
    switch (type) {
      case MechanicStatusType.notSet:
        return '';
      case MechanicStatusType.open:
        if (isOpen24Hours) {
          return 'Open 24 hours';
        }
        return 'Open now, closes ${closesAt ?? ''}';
      case MechanicStatusType.closed:
        if (opensDay != null && opensDay!.isNotEmpty) {
          return 'Closed, opens $opensDay ${opensAt ?? ''}';
        }
        return 'Closed, opens ${opensAt ?? ''}';
    }
  }
}

String formatMinutes(int minutes) {
  final h24 = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final period = h24 >= 12 ? 'PM' : 'AM';
  final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
  final mStr = m.toString().padLeft(2, '0');
  return '$h12:$mStr $period';
}

const Map<int, String> _shortDayNames = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

String dayName(int weekday) => _shortDayNames[weekday] ?? '';

String? formatMechanicSchedule(Mechanic m) {
  if (m.openDays.isEmpty) return null;
  if (!m.open24Hours && (m.openMinutes == null || m.closeMinutes == null)) {
    return null;
  }
  final daysText = formatDays(m.openDays);
  if (m.open24Hours) {
    if (m.openDays.length == 7) {
      return 'Open 24 hours, every day';
    }
    return '$daysText, Open 24 hours';
  }
  return '$daysText, ${formatMinutes(m.openMinutes!)} to ${formatMinutes(m.closeMinutes!)}';
}

String formatDays(List<int> days) {
  final sorted = List<int>.from(days)..sort();
  if (sorted.length == 7) return 'Every day';
  if (_listEquals(sorted, [1, 2, 3, 4, 5])) return 'Mon to Fri';
  if (_listEquals(sorted, [1, 2, 3, 4, 5, 6])) return 'Mon to Sat';
  if (_listEquals(sorted, [6, 7])) return 'Sat & Sun';
  return sorted
      .map((d) => _shortDayNames[d] ?? '')
      .where((s) => s.isNotEmpty)
      .join(', ');
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

MechanicStatus mechanicOpenStatus(Mechanic m, DateTime now) {
  if (m.openDays.isEmpty) {
    return const MechanicStatus.notSet();
  }
  if (!m.open24Hours && (m.openMinutes == null || m.closeMinutes == null)) {
    return const MechanicStatus.notSet();
  }

  final todayWeekday = now.weekday; // 1 = Monday .. 7 = Sunday
  final yesterdayWeekday = todayWeekday == 1 ? 7 : todayWeekday - 1;
  final nowMinutes = now.hour * 60 + now.minute;

  // 1. Check if 24 hours
  if (m.open24Hours) {
    if (m.openDays.contains(todayWeekday)) {
      return const MechanicStatus.open(isOpen24Hours: true);
    }
    // Closed today, search for next opening day
    for (var offset = 1; offset <= 7; offset++) {
      final nextDay = ((todayWeekday - 1 + offset) % 7) + 1;
      if (m.openDays.contains(nextDay)) {
        return MechanicStatus.closed(
          opensAt: '12:00 AM',
          opensDay: dayName(nextDay),
        );
      }
    }
    return const MechanicStatus.notSet();
  }

  final openMin = m.openMinutes!;
  final closeMin = m.closeMinutes!;
  final isOvernight = closeMin < openMin;

  // 2. Check if currently open:
  // Case A: Shift that started today
  if (m.openDays.contains(todayWeekday)) {
    if (!isOvernight) {
      if (nowMinutes >= openMin && nowMinutes < closeMin) {
        return MechanicStatus.open(closesAt: formatMinutes(closeMin));
      }
    } else {
      // Overnight shift starting today (e.g. 6 PM to 2 AM)
      if (nowMinutes >= openMin) {
        return MechanicStatus.open(closesAt: formatMinutes(closeMin));
      }
    }
  }

  // Case B: Overnight shift that started yesterday (e.g. Fri 6 PM to Sat 2 AM, and now is Sat 1 AM)
  if (isOvernight && m.openDays.contains(yesterdayWeekday)) {
    if (nowMinutes < closeMin) {
      return MechanicStatus.open(closesAt: formatMinutes(closeMin));
    }
  }

  // 3. Shop is currently CLOSED. Find the next opening time:
  // Can it open later today?
  if (m.openDays.contains(todayWeekday) && nowMinutes < openMin) {
    return MechanicStatus.closed(
      opensAt: formatMinutes(openMin),
      opensDay: null, // "opens 9:00 AM" if later today
    );
  }

  // Otherwise, search for the next day it opens
  for (var offset = 1; offset <= 7; offset++) {
    final nextDay = ((todayWeekday - 1 + offset) % 7) + 1;
    if (m.openDays.contains(nextDay)) {
      return MechanicStatus.closed(
        opensAt: formatMinutes(openMin),
        opensDay: dayName(nextDay),
      );
    }
  }

  return const MechanicStatus.notSet();
}
