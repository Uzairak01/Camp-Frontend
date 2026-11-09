/// Builds the human-readable "where am I" label from a Nominatim `address`
/// object.
///
/// Why: the raw `name` / `display_name` of a reverse lookup is often the
/// nearest unrelated point of interest (a garden, a shop). Only structural
/// address parts are trusted, so the label always describes the area.
class PlaceLabelBuilder {
  const PlaceLabelBuilder._();

  /// Finest-grained area keys, in preference order (neighbourhood / suburb).
  static const List<String> _areaKeys = [
    'neighbourhood',
    'suburb',
    'quarter',
    'city_district',
  ];

  /// Settlement keys, in preference order.
  static const List<String> _cityKeys = ['city', 'town', 'village'];

  /// Returns "area, road, city" skipping missing parts (and duplicates), or
  /// null when the address has none of them. POI fields (amenity, shop,
  /// building, name...) are deliberately never read.
  static String? build(Map<String, dynamic>? address) {
    if (address == null) return null;

    final parts = <String>[];
    void add(String? value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return;
      // Skip repeats such as a suburb that equals the city name.
      if (parts.any((p) => p.toLowerCase() == v.toLowerCase())) return;
      parts.add(v);
    }

    add(_firstPresent(address, _areaKeys));
    add(_firstPresent(address, const ['road']));
    add(_firstPresent(address, _cityKeys));

    return parts.isEmpty ? null : parts.join(', ');
  }

  static String? _firstPresent(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = address[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }
}

