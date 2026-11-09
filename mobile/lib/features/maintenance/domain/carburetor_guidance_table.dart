import 'dart:math' as math;

/// Altitude-density guidance for carburetor-equipped motorcycles.
///
/// ⚠️  GUIDANCE ONLY — every value in this file is unverified.
///
/// TODO: verify all band thresholds and recommendation text with a qualified
/// motorcycle mechanic before release. Air screws and fuel screws work in
/// OPPOSITE directions; the table deliberately uses neutral wording
/// ("adjust the mixture screw per your carb's manual") until each carb type
/// has been checked.
///
/// Formula source: US Standard Atmosphere 1976 (NOAA / NASA / USAF).
/// density(h) = (1 − 2.25577e−5 · h)^4.25588,  h in metres above sea level.

// ── Standard Atmosphere density function ────────────────────────────────────

/// Relative air density at altitude [altitudeM] metres (sea-level = 1.0).
/// Uses the US Standard Atmosphere 1976 polynomial.
/// Returns a value in [0.0, 1.0].
double atmosphericDensityRatio(double altitudeM) {
  // Clamp to troposphere range; formula is only valid below ~11,000 m.
  final h = altitudeM.clamp(0.0, 11000.0);
  return math.pow(1.0 - 2.25577e-5 * h, 4.25588).toDouble();
}

/// Density ratio of [currentAltitudeM] relative to [baselineAltitudeM].
/// 1.0 = same density as baseline. < 1.0 = thinner air at current location.
double altitudeDensityRatio(double currentAltitudeM, double baselineAltitudeM) {
  final baseDensity = atmosphericDensityRatio(baselineAltitudeM);
  if (baseDensity == 0) return 0;
  return atmosphericDensityRatio(currentAltitudeM) / baseDensity;
}

// ── Density-change guidance bands ───────────────────────────────────────────

/// Categorises the density ratio change into named severity bands.
enum DensityBand {
  /// Change < 5 %: minimal re-jetting needed.
  minimal,

  /// Change 5–10 %: slight rich condition at altitude.
  slight,

  /// Change 10–20 %: noticeable rich condition; jetting adjustment recommended.
  noticeable,

  /// Change > 20 %: significant rich condition; professional re-jetting advised.
  significant,
}

/// Returns the [DensityBand] for a given [densityRatio] (current/baseline).
DensityBand densityBand(double densityRatio) {
  // Round to 4 decimal places to prevent IEEE-754 precision issues
  // (e.g. 1.0 - 0.90 evaluates to 0.09999999999999998).
  final change = double.parse((1.0 - densityRatio).abs().toStringAsFixed(4));
  if (change < 0.05) return DensityBand.minimal;
  if (change < 0.10) return DensityBand.slight;
  if (change < 0.20) return DensityBand.noticeable;
  return DensityBand.significant;
}

// ── Guidance text by band × carb type ───────────────────────────────────────

/// Carb type classifications for guidance text lookup.
enum CarbType {
  /// Slide-type (e.g. Mikuni VM, Keihin PE / CR round-slide).
  // TODO: verify guidance wording with a mechanic for slide-type carbs.
  slide,

  /// CV / constant-velocity (e.g. Mikuni BST/BS, Keihin CVK, CV-type).
  // TODO: verify guidance wording with a mechanic for CV-type carbs.
  cv,

  /// Unknown / unrecognised carb spec: show generic guidance.
  other,
}

/// Parse a free-text [carburetorType] string from the Bike model into a
/// [CarbType] enum for guidance lookup.
CarbType parseCarbType(String? carburetorType) {
  if (carburetorType == null) return CarbType.other;
  final lower = carburetorType.toLowerCase();
  if (lower.contains('slide') ||
      lower.contains('vm') ||
      lower.contains('pe ') ||
      lower.contains('cr ') ||
      lower.contains('round')) {
    return CarbType.slide;
  }
  if (lower.contains('cv') ||
      lower.contains('bst') ||
      lower.contains('bs ') ||
      lower.contains('cvk') ||
      lower.contains('constant velocity')) {
    return CarbType.cv;
  }
  return CarbType.other;
}

/// Lean running risk warning when density ratio > 1.0 (denser air than tuned baseline).
/// TODO: verify wording with a certified motorcycle mechanic before release.
const String leanRunningRiskWarning =
    'Your setup was tuned for thinner air. At this altitude it may run lean, '
    'which can damage the engine. Return to or re-tune for this altitude before riding hard.';

/// Warning banner that must appear on EVERY jetting recommendation, including minimal.
/// TODO: verify wording with a certified motorcycle mechanic before release.
const String returnToBaselineWarning =
    'Return to your baseline setup when you come back down. '
    'A high-altitude setup runs lean at low altitude and can damage the engine.';

/// Altitude-aware jetting guidance for a given [band], [carbType], and [densityRatio].
///
/// Handles both directions:
///   - ratio < 1 (thinner air than baseline setup): mixture runs richer.
///   - ratio > 1 (denser air than baseline setup): mixture runs leaner (engine damage risk).
///
/// "No adjustment needed" is allowed ONLY when |1 - ratio| < 0.05 in either direction.
/// Every recommendation includes the return-to-baseline warning and is marked unverified.
/// TODO: verify every recommendation with a qualified mechanic before release.
String jetingGuidanceText(
  DensityBand band,
  CarbType carbType, {
  double densityRatio = 1.0,
}) {
  final isLean = densityRatio > 1.0;

  if (band == DensityBand.minimal) {
    return 'Carburetor jetting likely matches this altitude — no adjustment needed.\n\n'
        'Air density change is less than 5% relative to your baseline. Monitor idle quality; '
        'adjust the mixture screw per your carb\'s manual if the idle becomes rough.\n\n'
        '⚠️  $returnToBaselineWarning\n\n'
        '⚠️ Guidance only — TODO: verify with a mechanic before release.';
  }

  if (isLean) {
    final String specificGuidance;
    switch (band) {
      case DensityBand.minimal:
        specificGuidance = '';
        break;
      case DensityBand.slight:
        switch (carbType) {
          case CarbType.slide:
            specificGuidance =
                'Air density is 5–10% higher than your baseline setup (denser air). '
                'The engine draws more oxygen per stroke and may run slightly lean on idle and pilot circuits. '
                'Adjust the mixture screw richer per your carb\'s manual and monitor engine temperature. '
                'Avoid sustained wide-open throttle until verified.';
          case CarbType.cv:
            specificGuidance =
                'Air density is 5–10% higher than your baseline setup (denser air). '
                'CV vacuum lift will respond, but the idle/pilot mixture may run slightly lean. '
                'Turn the pilot mixture screw richer per your manual if you notice backfiring on decel or lean hesitation.';
          case CarbType.other:
            specificGuidance =
                'Air density is 5–10% higher than your baseline setup (denser air). '
                'The mixture may run slightly lean. Adjust the mixture screw richer per your manual if idle surges or engine runs hot.';
        }
      case DensityBand.noticeable:
        switch (carbType) {
          case CarbType.slide:
            specificGuidance =
                'Air density is 10–20% higher than your baseline setup (noticeable lean condition). '
                'A slide carb will run noticeably lean through the midrange and top end, causing hesitation under load and elevated exhaust temperatures. '
                'Raise the jet needle (move clip down one position) and turn mixture screw richer. Consider reinstalling your baseline lower-altitude main jet.';
          case CarbType.cv:
            specificGuidance =
                'Air density is 10–20% higher than your baseline setup (noticeable lean condition). '
                'CV needle taper and main circuit will run lean under load, creating risk of overheating. '
                'Richen the pilot screw and raise the jet needle clip one position if adjustable, or re-jet closer to standard low-altitude specifications.';
          case CarbType.other:
            specificGuidance =
                'Air density is 10–20% higher than your baseline setup (noticeable lean condition). '
                'The engine is running leaner than intended. Midrange needle adjustment and richer pilot setting are advised before sustained riding.';
        }
      case DensityBand.significant:
        switch (carbType) {
          case CarbType.slide:
            specificGuidance =
                'Air density is over 20% higher than your baseline setup (severe lean condition). '
                'CRITICAL RISK: Riding a high-altitude slide carb setup at low altitude can cause severe overheating, pre-ignition, and piston seizure. '
                'Reinstall baseline low-altitude main and pilot jets immediately or have a motorcycle mechanic re-jet before riding hard.';
          case CarbType.cv:
            specificGuidance =
                'Air density is over 20% higher than your baseline setup (severe lean condition). '
                'CRITICAL RISK: While CV carbs partially self-compensate, high-speed and full-throttle operation will run dangerously lean. '
                'Restore standard low-altitude jet sizes immediately and consult a mechanic before extended highway or trail use.';
          case CarbType.other:
            specificGuidance =
                'Air density is over 20% higher than your baseline setup (severe lean condition). '
                'CRITICAL RISK: Severe lean running risks severe engine damage. '
                'Restore baseline low-altitude jetting or seek professional mechanic service before riding.';
        }
    }

    return '⚠️ LEAN-RISK WARNING: $leanRunningRiskWarning\n\n'
        '$specificGuidance\n\n'
        '⚠️  $returnToBaselineWarning\n\n'
        '⚠️ Guidance only — TODO: verify with a mechanic before release.';
  }

  // Thinner air (ratio < 1.0, altitude > baseline) -> rich running
  final String richGuidance;
  switch (band) {
    case DensityBand.minimal:
      richGuidance = '';
      break;
    case DensityBand.slight:
      switch (carbType) {
        case CarbType.slide:
          richGuidance =
              'Air density has dropped 5–10%. A slide-type carb may idle '
              'slightly richer at this elevation. Check idle quality and, if '
              'needed, adjust the mixture screw per your carb\'s manual '
              '(direction depends on whether yours is an air screw or fuel '
              'screw — they work opposite ways).';
        case CarbType.cv:
          richGuidance =
              'Air density has dropped 5–10%. CV-type carbs compensate '
              'partially via vacuum-operated needle lift, but the pilot '
              'circuit may still run slightly rich. Adjust the mixture screw '
              'per your carb\'s manual if idle is rough or plug shows heavy '
              'black sooting.';
        case CarbType.other:
          richGuidance =
              'Air density has dropped 5–10%. Check idle quality; if the '
              'engine idles roughly or runs rich, adjust the mixture screw '
              'per your carb\'s manual (consult it for screw type and '
              'turn direction before adjusting).';
      }
    case DensityBand.noticeable:
      switch (carbType) {
        case CarbType.slide:
          richGuidance =
              'Air density has dropped 10–20%. A slide-type carb will '
              'likely run noticeably rich, causing hesitation on snap '
              'throttle. Consider dropping the jet needle clip by one position '
              '(raises the needle, leaning the mid-range) and adjusting the '
              'mixture screw per your carb\'s manual. A smaller main jet may '
              'also help if the issue persists.';
        case CarbType.cv:
          richGuidance =
              'Air density has dropped 10–20%. CV carbs may show sluggish '
              'throttle response or black exhaust at altitude. Dropping the '
              'needle clip one position (raises needle = leaner midrange) and '
              'adjusting the pilot mixture screw per your carb\'s manual can '
              'restore crisp response. Consult your manual for screw type '
              'and direction before touching.';
        case CarbType.other:
          richGuidance =
              'Air density has dropped 10–20%. The engine likely runs '
              'richer than baseline. Needle clip position and pilot mixture '
              'screw adjustment (per your carb\'s manual) may be needed to '
              'restore performance. Confirm screw type before adjusting.';
      }
    case DensityBand.significant:
      switch (carbType) {
        case CarbType.slide:
          richGuidance =
              'Air density has dropped over 20%. A slide-type carb will '
              'run very rich at this elevation — risk of plug fouling, heavy '
              'fuel smell, and severe power loss. A smaller main jet size '
              'and/or raised needle clip are commonly used, but the exact '
              'spec depends on your model. Professional re-jetting by a '
              'mechanic is strongly advised for extended riding at this '
              'altitude.';
        case CarbType.cv:
          richGuidance =
              'Air density has dropped over 20%. A CV carb partially '
              'self-compensates but the pilot and main circuits will still '
              'run significantly rich. A main jet change and/or needle clip '
              'adjustment is commonly performed, but spec varies by model. '
              'Professional re-jetting is strongly recommended for extended '
              'high-altitude riding.';
        case CarbType.other:
          richGuidance =
              'Air density has dropped over 20%. Running this rich risks '
              'plug fouling and engine damage over extended periods. '
              'Professional re-jetting by a qualified mechanic is strongly '
              'recommended before extended riding at this altitude.';
      }
  }

  return '$richGuidance\n\n'
      '⚠️  $returnToBaselineWarning\n\n'
      '⚠️ Guidance only — TODO: verify with a mechanic before release.';
}
