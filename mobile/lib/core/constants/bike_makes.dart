/// Canonical motorcycle make names used for autocomplete suggestions.
///
/// Single source of truth — do not duplicate this list across screens.
/// Order: South Asian / common regional makes first, then global brands alphabetically.
const List<String> kCanonicalBikeMakes = [
  // South Asian / regional
  'Bajaj',
  'Benelli',
  'Crown',
  'Hero',
  'Hi-Speed',
  'Metro',
  'Road Prince',
  'Super Power',
  'TVS',
  'Unique',
  'United',
  // Global
  'Aprilia',
  'BMW',
  'Ducati',
  'Harley-Davidson',
  'Honda',
  'Husqvarna',
  'Kawasaki',
  'KTM',
  'Royal Enfield',
  'Suzuki',
  'Triumph',
  'Yamaha',
];

/// Map of lower-case make name → canonical spelling for fast lookup.
final Map<String, String> _canonicalMakeMap = {
  for (final m in kCanonicalBikeMakes) m.toLowerCase(): m,
};

/// Given user input, returns the canonical make name if a case-insensitive
/// match is found; otherwise returns the input trimmed and title-cased.
String canonicaliseMake(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final canon = _canonicalMakeMap[trimmed.toLowerCase()];
  if (canon != null) return canon;
  // Title-case each word (e.g. "united motors" → "United Motors").
  return trimmed.split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
}
