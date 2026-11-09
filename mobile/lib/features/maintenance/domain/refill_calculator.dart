/// 3-field refill pricing coordinator and calculation engine.
///
/// Ensures the rider can edit any two fields (litres, price per litre, total paid),
/// and the third field is automatically calculated.
///
/// Prevents circular feedback loops, ignores programmatic updates, and avoids
/// double recalculations on real devices.
enum RefillField {
  litres,
  price,
  total,
}

class RefillCalculationResult {
  const RefillCalculationResult({
    required this.calculatedField,
    required this.calculatedValue,
  });

  final RefillField? calculatedField;
  final String calculatedValue;
}

class RefillCalculator {
  RefillCalculator({bool prefilledPrice = false}) {
    if (prefilledPrice) {
      _lastEdited.add(RefillField.price);
    }
  }

  final List<RefillField> _lastEdited = [];

  List<RefillField> get lastEdited => List.unmodifiable(_lastEdited);

  /// Returns which field is currently calculated (the one not in [_lastEdited]
  /// when 2 fields have been edited), or null if fewer than 2 fields have been established.
  RefillField? get calculatedField {
    if (_lastEdited.length < 2) return null;
    for (final field in RefillField.values) {
      if (!_lastEdited.contains(field)) return field;
    }
    return null;
  }

  /// Initialize state for editing an existing refill expense where all 3 fields exist.
  /// Defaults to price and litres as the edited fields, so total is calculated.
  void initForExisting({bool hasAllThree = true}) {
    _lastEdited.clear();
    if (hasAllThree) {
      _lastEdited.add(RefillField.price);
      _lastEdited.add(RefillField.litres);
    } else {
      _lastEdited.add(RefillField.total);
    }
  }

  /// Call whenever the user types into or edits [field].
  ///
  /// - Typing again in a field already in the list does not change the pair,
  ///   but updates recency so the other field remains the oldest.
  /// - When typing in the calculated field, it becomes an edited field and
  ///   the oldest edited field becomes the calculated one.
  void registerEdit(RefillField field) {
    if (_lastEdited.contains(field)) {
      _lastEdited.remove(field);
      _lastEdited.add(field);
    } else {
      if (_lastEdited.length >= 2) {
        _lastEdited.removeAt(0);
      }
      _lastEdited.add(field);
    }
  }

  /// Calculates the third field from raw parsed values of litres, price, and total.
  /// Returns the calculated field and the formatted string (or empty string if incomplete/partial).
  RefillCalculationResult calculate({
    required String litresText,
    required String priceText,
    required String totalText,
  }) {
    final target = calculatedField;
    if (target == null) {
      return const RefillCalculationResult(
        calculatedField: null,
        calculatedValue: '',
      );
    }

    final rawLitres = parsePositiveDouble(litresText);
    final rawPrice = parsePositiveDouble(priceText);
    final rawTotal = parsePositiveDouble(totalText);

    switch (target) {
      case RefillField.litres:
        if (rawPrice != null && rawTotal != null) {
          final computed = rawTotal / rawPrice;
          return RefillCalculationResult(
            calculatedField: target,
            calculatedValue: formatLitres(computed),
          );
        }
        return RefillCalculationResult(
          calculatedField: target,
          calculatedValue: '',
        );

      case RefillField.price:
        if (rawLitres != null && rawTotal != null) {
          final computed = rawTotal / rawLitres;
          return RefillCalculationResult(
            calculatedField: target,
            calculatedValue: formatPrice(computed),
          );
        }
        return RefillCalculationResult(
          calculatedField: target,
          calculatedValue: '',
        );

      case RefillField.total:
        if (rawLitres != null && rawPrice != null) {
          final computed = rawLitres * rawPrice;
          return RefillCalculationResult(
            calculatedField: target,
            calculatedValue: formatTotal(computed),
          );
        }
        return RefillCalculationResult(
          calculatedField: target,
          calculatedValue: '',
        );
    }
  }

  /// Parses a string into a positive double, ignoring currency symbols and commas.
  /// Returns null for empty, invalid, or partial input (<= 0).
  static double? parsePositiveDouble(String? text) {
    if (text == null) return null;
    final cleaned = text
        .replaceAll('Rs', '')
        .replaceAll('PKR', '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return null;
    final val = double.tryParse(cleaned);
    if (val == null || val <= 0) return null;
    return val;
  }

  /// Format litres for display rounded to 2 decimals, omitting unnecessary zeros for integers.
  static String formatLitres(double val) {
    if (val <= 0) return '';
    final rounded = double.parse(val.toStringAsFixed(2));
    if (rounded.truncateToDouble() == rounded) {
      return rounded.toInt().toString();
    }
    return rounded.toString();
  }

  /// Format price for display rounded to 2 decimals, omitting unnecessary zeros for integers.
  static String formatPrice(double val) {
    if (val <= 0) return '';
    final rounded = double.parse(val.toStringAsFixed(2));
    if (rounded.truncateToDouble() == rounded) {
      return rounded.toInt().toString();
    }
    return rounded.toString();
  }

  /// Format total for display rounded to whole rupees.
  static String formatTotal(double val) {
    if (val <= 0) return '';
    return val.round().toString();
  }
}
