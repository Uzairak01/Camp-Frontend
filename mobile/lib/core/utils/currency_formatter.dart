/// Single source of truth currency helper for Pakistani Rupees (PKR).
/// Formats amounts as "Rs 12,500" with thousands separators and no decimals
/// unless the amount has paisa. Rejects negatives and non-numbers.
library;

const double kMaxPkrAmount = 999999999.0;

/// Format a numerical amount in PKR.
///
/// Returns formatted string like "Rs 12,500", "Rs 999", "Rs 1,234,567".
/// Returns "Rs 0" for zero, null, or negative inputs (negatives are never displayed).
/// If the amount contains fractional paisa, formats with two decimal places (e.g. "Rs 12.50").
String formatPkr(num? amount) {
  if (amount == null || amount <= 0) {
    return 'Rs 0';
  }

  final double val = amount.toDouble();
  final int wholePart = val.floor();
  final double fractional = val - wholePart;

  final String formattedWhole = _addThousandsSeparators(wholePart);

  // If there is fractional paisa (>= 0.5 paisa)
  final int paisa = (fractional * 100).round();
  if (paisa > 0 && paisa < 100) {
    final String paisaStr = paisa.toString().padLeft(2, '0');
    return 'Rs $formattedWhole.$paisaStr';
  }

  return 'Rs $formattedWhole';
}

/// Helper to add thousands separators (commas) to an integer.
String _addThousandsSeparators(int number) {
  final String digits = number.toString();
  final StringBuffer buffer = StringBuffer();
  final int len = digits.length;

  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

/// Parse user-entered currency input strings into a valid PKR double amount.
///
/// Accepts commas or plain digits (e.g. "12,500" or "12500"), optional "Rs" prefix.
/// Returns `null` for empty, negative, non-numeric strings, or values exceeding [kMaxPkrAmount].
double? parsePkr(String? input) {
  if (input == null) return null;
  final String trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // Reject negative numbers
  if (trimmed.contains('-')) return null;

  // Sanitize "Rs", "PKR", commas, and spaces
  final String sanitized = trimmed
      .replaceAll('Rs', '')
      .replaceAll('rs', '')
      .replaceAll('PKR', '')
      .replaceAll('pkr', '')
      .replaceAll(',', '')
      .trim();

  if (sanitized.isEmpty) return null;

  final double? parsed = double.tryParse(sanitized);
  if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
    return null;
  }

  if (parsed > kMaxPkrAmount) {
    return null;
  }

  return parsed;
}
