/// Units of measurement supported across the CAMP mobility ecosystem.
enum UnitsSystem {
  metric,
  imperial,
}

extension UnitsSystemExtension on UnitsSystem {
  /// Display label for toggle options.
  String get label {
    switch (this) {
      case UnitsSystem.metric:
        return 'Metric (km, °C)';
      case UnitsSystem.imperial:
        return 'Imperial (mi, °F)';
    }
  }

  /// Abbreviation for distance readings (km vs mi).
  String get distanceUnit => this == UnitsSystem.metric ? 'km' : 'mi';

  /// Abbreviation for ambient/engine temperature (°C vs °F).
  String get temperatureUnit => this == UnitsSystem.metric ? '°C' : '°F';

  /// Abbreviation for speed readings (km/h vs mph).
  String get speedUnit => this == UnitsSystem.metric ? 'km/h' : 'mph';

  /// Abbreviation for fuel volume (L vs gal).
  String get volumeUnit => this == UnitsSystem.metric ? 'L' : 'gal';
}
