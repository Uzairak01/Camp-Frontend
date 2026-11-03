import 'package:flutter/foundation.dart';

/// Parsed representation of a phone number entered or edited by the rider.
@immutable
class ParsedPhoneNumber {
  const ParsedPhoneNumber({
    required this.countryCode,
    required this.nationalNumber,
    required this.e164,
    required this.hasUnlistedCountryCode,
    required this.isValidLength,
    required this.isDigitsOnly,
  });

  /// The country calling code digits without '+' (e.g. '92', '966', '1').
  final String countryCode;

  /// The national phone digits without leading zeros, spaces, or hyphens.
  final String nationalNumber;

  /// Normalized E.164 string (+ followed by country code and national digits).
  final String e164;

  /// Whether the phone number started with a code not found in standard ITU allocations.
  final bool hasUnlistedCountryCode;

  /// Whether the national number contains between 6 and 12 digits.
  final bool isValidLength;

  /// Whether the national part contains digits only.
  final bool isDigitsOnly;

  /// True if the phone number meets all validation requirements:
  /// digits only and 6 to 12 national digits.
  bool get isValid => isDigitsOnly && isValidLength;
}

/// Result of splitting a raw phone number into country calling code and national number.
@immutable
class PhoneSplitResult {
  const PhoneSplitResult({
    required this.countryCode,
    required this.nationalNumber,
  });

  /// Digits of the country calling code without '+' (e.g. '92', '966', '1').
  final String countryCode;

  /// Digits of the national number with leading 0 removed.
  final String nationalNumber;
}

/// Utility helper for emergency contact phone parsing, formatting, validation, and migration.
class EmergencyPhoneHelper {
  EmergencyPhoneHelper._();

  /// Standard ITU-T E.164 assigned country calling codes (1, 2, and 3 digits).
  static const Set<String> kItuCountryCodes = {
    // 1-digit
    '1', '7',
    // 2-digit
    '20', '27',
    '30', '31', '32', '33', '34', '36', '39',
    '40', '41', '43', '44', '45', '46', '47', '48', '49',
    '51', '52', '53', '54', '55', '56', '57', '58',
    '60', '61', '62', '63', '64', '65', '66',
    '81', '82', '84', '86',
    '90', '91', '92', '93', '94', '95', '98',
    // 3-digit
    '211', '212', '213', '216', '218', '220', '221', '222', '223', '224',
    '225', '226', '227', '228', '229', '230', '231', '232', '233', '234',
    '235', '236', '237', '238', '239', '240', '241', '242', '243', '244',
    '245', '246', '247', '248', '249', '250', '251', '252', '253', '254',
    '255', '256', '257', '258', '260', '261', '262', '263', '264', '265',
    '266', '267', '268', '269', '290', '291', '297', '298', '299',
    '350', '351', '352', '353', '354', '355', '356', '357', '358', '359',
    '370', '371', '372', '373', '374', '375', '376', '377', '378', '379',
    '380', '381', '382', '383', '385', '386', '387', '389',
    '420', '421', '423',
    '500', '501', '502', '503', '504', '505', '506', '507', '508', '509',
    '590', '591', '592', '593', '594', '595', '596', '597', '598', '599',
    '670', '672', '673', '674', '675', '676', '677', '678', '679',
    '680', '681', '682', '683', '685', '686', '687', '688', '689',
    '690', '691', '692',
    '850', '852', '853', '855', '856', '880', '886',
    '960', '961', '962', '963', '964', '965', '966', '967', '968',
    '970', '971', '972', '973', '974', '975', '976', '977',
    '992', '993', '994', '995', '996', '998',
  };

  /// Removes spaces, dashes, parentheses, and brackets.
  static String stripFormatting(String input) {
    return input.replaceAll(RegExp(r'[\s\-\(\)\[\]]'), '');
  }

  /// Attempts to split a number starting with '+' or '00' into a country code
  /// (longest matching ITU code of 1 to 3 digits) and national number (6 to 12 digits).
  ///
  /// Returns `null` if the input does not match a valid ITU code or if the
  /// remaining national digits are outside the 6-12 digit range.
  static PhoneSplitResult? trySplitPastedNumber(String raw) {
    var clean = stripFormatting(raw.trim());
    if (clean.isEmpty) return null;

    if (clean.startsWith('00')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('+')) {
      clean = clean.substring(1);
    } else {
      // Must start with + or 00
      return null;
    }

    // Retain digits only
    clean = clean.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length < 7) return null; // At least 1-digit code + 6 national digits

    // Check longest valid ITU code prefix (3 digits, then 2, then 1)
    for (int len = 3; len >= 1; len--) {
      if (clean.length > len) {
        final prefix = clean.substring(0, len);
        if (kItuCountryCodes.contains(prefix)) {
          final national = clean.substring(len).replaceFirst(RegExp(r'^0+'), '');
          if (national.length >= 6 && national.length <= 12) {
            return PhoneSplitResult(
              countryCode: prefix,
              nationalNumber: national,
            );
          }
        }
      }
    }

    return null;
  }

  /// Splits an existing stored E.164 number into its country code and national digits.
  ///
  /// Checks standard ITU prefixes (3, 2, 1) and falls back to a 1-3 digit split.
  static PhoneSplitResult splitE164(String phone) {
    var clean = stripFormatting(phone.trim());
    if (clean.startsWith('00')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('+')) {
      clean = clean.substring(1);
    }

    clean = clean.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      return const PhoneSplitResult(countryCode: '', nationalNumber: '');
    }

    // Try standard ITU prefixes
    for (int len = 3; len >= 1; len--) {
      if (clean.length > len) {
        final prefix = clean.substring(0, len);
        if (kItuCountryCodes.contains(prefix)) {
          final nat = clean.substring(len).replaceFirst(RegExp(r'^0+'), '');
          return PhoneSplitResult(countryCode: prefix, nationalNumber: nat);
        }
      }
    }

    // Fallback split: if length > 9, assume 2 or 3 digit prefix
    if (clean.length >= 10) {
      return PhoneSplitResult(
        countryCode: clean.substring(0, 2),
        nationalNumber: clean.substring(2).replaceFirst(RegExp(r'^0+'), ''),
      );
    }

    return PhoneSplitResult(countryCode: '', nationalNumber: clean);
  }

  /// Parses a raw phone input (typed or pasted) from the contact form.
  ///
  /// - Strips spaces, dashes, parentheses, and brackets.
  /// - Strips leading 0 from the national number.
  /// - If raw input starts with '+' or '00', parses country code from prefix.
  /// - Otherwise combines with [selectedCountryCode].
  static ParsedPhoneNumber parseInput({
    required String rawInput,
    String selectedCountryCode = '',
  }) {
    final clean = stripFormatting(rawInput.trim());
    final cleanSelectedCode = stripFormatting(selectedCountryCode.trim())
        .replaceAll(RegExp(r'[^0-9]'), '');

    if (clean.isEmpty) {
      return ParsedPhoneNumber(
        countryCode: cleanSelectedCode,
        nationalNumber: '',
        e164: '',
        hasUnlistedCountryCode: false,
        isValidLength: false,
        isDigitsOnly: true,
      );
    }

    bool hasUnlisted = false;

    // If pasted with '+' or '00', try splitting prefix
    if (clean.startsWith('+') || clean.startsWith('00')) {
      final split = trySplitPastedNumber(clean);
      if (split != null) {
        final isDigits = RegExp(r'^[0-9]+$').hasMatch(split.nationalNumber);
        final isValidLen = split.nationalNumber.length >= 6 && split.nationalNumber.length <= 12;
        return ParsedPhoneNumber(
          countryCode: split.countryCode,
          nationalNumber: split.nationalNumber,
          e164: '+${split.countryCode}${split.nationalNumber}',
          hasUnlistedCountryCode: false,
          isValidLength: isValidLen,
          isDigitsOnly: isDigits,
        );
      } else {
        hasUnlisted = true;
      }
    }

    // Extract digits and remove leading zeros
    final national = clean.replaceFirst(RegExp(r'^0+'), '');
    final isDigitsOnly = national.isEmpty || RegExp(r'^[0-9]+$').hasMatch(national);
    final isValidLength = national.length >= 6 && national.length <= 12;

    final String e164;
    if (hasUnlisted) {
      final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      e164 = '+$digits';
    } else if (cleanSelectedCode.isNotEmpty && national.isNotEmpty && isDigitsOnly) {
      e164 = '+$cleanSelectedCode$national';
    } else {
      e164 = clean.startsWith('+') ? clean : '';
    }

    return ParsedPhoneNumber(
      countryCode: cleanSelectedCode,
      nationalNumber: national,
      e164: e164,
      hasUnlistedCountryCode: hasUnlisted,
      isValidLength: isValidLength,
      isDigitsOnly: isDigitsOnly,
    );
  }

  /// Migrates legacy stored phone numbers into normalized E.164.
  ///
  /// - 11 digits starting with 03 (Pakistani mobile) becomes +923XXXXXXXXX.
  /// - Numbers with '00' prefix become '+'.
  /// - Numbers with '+9203...' (13 digits with extra 0 after country code) become '+923...'.
  /// - Numbers already starting with + are cleaned and kept.
  /// - Any other non-standard format is left intact for rider review.
  static String migrateLegacyPhoneNumber(String raw) {
    final clean = stripFormatting(raw.trim());
    if (clean.isEmpty) return '';

    // Convert leading '00' to '+'
    if (clean.startsWith('00')) {
      final digits = clean.substring(2).replaceAll(RegExp(r'[^0-9]'), '');
      return '+$digits';
    }

    // Already starting with +: keep + and digits, fix any +9203 extra 0
    if (clean.startsWith('+')) {
      final digits = clean.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.startsWith('920') && digits.length == 13) {
        return '+92${digits.substring(3)}';
      }
      return '+$digits';
    }

    // 11 digits starting with 03 (Pakistani mobile: e.g. 03212699353 -> +923212699353)
    if (RegExp(r'^03[0-9]{9}$').hasMatch(clean)) {
      return '+92${clean.substring(1)}';
    }

    // Otherwise leave as is
    return clean;
  }

  /// Extracts digits for WhatsApp URL or tel schemes, ensuring:
  /// - strictly digits only (no '+', no spaces, no punctuation)
  /// - no leading zeros or '00'
  /// - fixes legacy Pakistani numbers (03... -> 923..., 9203... -> 923...)
  static String extractE164Digits(String phone) {
    var clean = stripFormatting(phone.trim());
    if (clean.startsWith('00')) {
      clean = clean.substring(2);
    }
    if (clean.startsWith('+')) {
      clean = clean.substring(1);
    }
    var digits = clean.replaceAll(RegExp(r'[^0-9]'), '');

    // Handle legacy Pakistani numbers
    if (digits.startsWith('920') && digits.length == 13) {
      digits = '92${digits.substring(3)}';
    } else if (digits.startsWith('03') && digits.length == 11) {
      digits = '92${digits.substring(1)}';
    } else {
      // Strip any other unwanted leading zeros
      digits = digits.replaceFirst(RegExp(r'^0+'), '');
    }

    return digits;
  }

  /// Formats an E.164 phone number into a human-readable string for display on cards.
  ///
  /// Examples:
  /// - '+923212699353' -> '+92 321 2699353'
  /// - '+966501234567' -> '+966 50 123 4567'
  /// - '+15551234567'  -> '+1 555 1234567'
  static String formatPhoneReadable(String phone) {
    final clean = stripFormatting(phone.trim());
    if (!clean.startsWith('+')) return phone;

    final split = splitE164(clean);
    if (split.countryCode.isNotEmpty && split.nationalNumber.isNotEmpty) {
      final code = split.countryCode;
      final nat = split.nationalNumber;

      if (code == '92' && nat.length == 10) {
        return '+$code ${nat.substring(0, 3)} ${nat.substring(3)}';
      } else if (code == '966' && nat.length == 9) {
        return '+$code ${nat.substring(0, 2)} ${nat.substring(2, 5)} ${nat.substring(5)}';
      } else if (code == '971' && nat.length == 9) {
        return '+$code ${nat.substring(0, 2)} ${nat.substring(2, 5)} ${nat.substring(5)}';
      } else if (code == '1' && nat.length == 10) {
        return '+$code ${nat.substring(0, 3)} ${nat.substring(3, 6)} ${nat.substring(6)}';
      } else if (code == '44' && nat.length == 10) {
        return '+$code ${nat.substring(0, 4)} ${nat.substring(4)}';
      } else if (nat.length >= 7) {
        return '+$code ${nat.substring(0, 3)} ${nat.substring(3)}';
      }
      return '+$code $nat';
    }

    return phone;
  }

  /// Checks if the phone number adheres to normalized E.164 format.
  /// Returns false for unmigrated or non-standard formats (e.g. '12345' or '03212699353').
  static bool hasValidFormat(String phone) {
    final clean = stripFormatting(phone.trim());
    if (!clean.startsWith('+')) return false;
    final digits = clean.substring(1);
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return false;
    return digits.length >= 7 && digits.length <= 15;
  }
}
