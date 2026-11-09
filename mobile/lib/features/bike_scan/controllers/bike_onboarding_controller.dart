import 'package:flutter/foundation.dart';

import '../../garage/domain/bike_model.dart';
import '../domain/bike_recognition_service.dart';

/// Controller that preserves motorcycle onboarding form state across screens
/// (e.g. when backing out to registration options or arriving from optical AI scan).
class BikeOnboardingController extends ChangeNotifier {
  BikeOnboardingController._();

  /// Shared singleton instance.
  static final BikeOnboardingController instance = BikeOnboardingController._();

  String _make = 'Honda';
  String _modelName = '';
  int _modelYear = 2024;
  int? _displacement = 1100;
  String _bikeType = 'Adventure';
  FuelSystem _fuelSystem = FuelSystem.carburetor;
  String? _carburetorType;
  double? _fuelTankCapacityLiters;
  int? _odometerKm;
  double? _currentFuelLiters;
  double? _fuelAverageKmpl;
  ServiceRecord _lastOilChange = const ServiceRecord(
    mode: TrackingMode.byDistance,
    km: 3200,
  );
  ServiceRecord _lastTuneUp = const ServiceRecord(
    mode: TrackingMode.byDistance,
    km: 5000,
  );
  String? _vin;
  String? _nickname;
  String? _plateNumber;
  String? _color;
  String? _imagePath;

  // ── Getters ────────────────────────────────────────────────────────────────
  String get make => _make;
  String get modelName => _modelName;
  int get modelYear => _modelYear;
  int? get displacement => _displacement;
  String get bikeType => _bikeType;
  FuelSystem get fuelSystem => _fuelSystem;
  String? get carburetorType => _carburetorType;
  double? get fuelTankCapacityLiters => _fuelTankCapacityLiters;
  int? get odometerKm => _odometerKm;
  double? get currentFuelLiters => _currentFuelLiters;
  double? get fuelAverageKmpl => _fuelAverageKmpl;
  ServiceRecord get lastOilChange => _lastOilChange;
  ServiceRecord get lastTuneUp => _lastTuneUp;
  String? get vin => _vin;
  String? get nickname => _nickname;
  String? get plateNumber => _plateNumber;
  String? get color => _color;
  String? get colour => _color;
  String? get imagePath => _imagePath;

  /// Whether the 3 mandatory gating fields are populated and valid:
  /// 1. Make (2–30 characters)
  /// 2. Model Name
  /// 3. Model Year
  /// Odometer is optional and defaults to 0.
  bool get isFormValid {
    final makeLen = _make.trim().length;
    return makeLen >= 2 &&
        makeLen <= 30 &&
        _modelName.trim().isNotEmpty &&
        _modelYear > 1900;
  }

  // ── Setters & Updaters ─────────────────────────────────────────────────────
  void setMake(String value) {
    if (_make == value) return;
    _make = value;
    notifyListeners();
  }

  void setModelName(String value) {
    if (_modelName == value) return;
    _modelName = value;
    notifyListeners();
  }

  void setModelYear(int value) {
    if (_modelYear == value) return;
    _modelYear = value;
    notifyListeners();
  }

  void setDisplacement(int? value) {
    if (_displacement == value) return;
    _displacement = value;
    notifyListeners();
  }

  void setBikeType(String value) {
    if (_bikeType == value) return;
    _bikeType = value;
    notifyListeners();
  }

  void setFuelSystem(FuelSystem value) {
    if (_fuelSystem == value) return;
    _fuelSystem = value;
    if (_fuelSystem == FuelSystem.efi) {
      _carburetorType = null;
    }
    notifyListeners();
  }

  void setCarburetorType(String? value) {
    if (_carburetorType == value) return;
    _carburetorType = value;
    notifyListeners();
  }

  void setFuelTankCapacity(double? value) {
    if (_fuelTankCapacityLiters == value) return;
    _fuelTankCapacityLiters = value;
    notifyListeners();
  }

  void setOdometerKm(int? value) {
    if (_odometerKm == value) return;
    _odometerKm = value;
    notifyListeners();
  }

  void setCurrentFuelLiters(double? value) {
    if (_currentFuelLiters == value) return;
    _currentFuelLiters = value;
    notifyListeners();
  }

  void setFuelAverageKmpl(double? value) {
    if (_fuelAverageKmpl == value) return;
    _fuelAverageKmpl = value;
    notifyListeners();
  }

  void setLastOilChange(ServiceRecord record) {
    _lastOilChange = record;
    notifyListeners();
  }

  void setLastTuneUp(ServiceRecord record) {
    _lastTuneUp = record;
    notifyListeners();
  }

  void setVin(String? value) {
    if (_vin == value) return;
    _vin = value;
    notifyListeners();
  }

  void setNickname(String? value) {
    if (_nickname == value) return;
    _nickname = value;
    notifyListeners();
  }

  void setPlateNumber(String? value) {
    final clean = value?.trim().toUpperCase();
    final effective = (clean != null && clean.isNotEmpty) ? clean : null;
    if (_plateNumber == effective) return;
    _plateNumber = effective;
    notifyListeners();
  }

  void setColor(String? value) {
    final clean = value?.trim();
    final effective = (clean != null && clean.isNotEmpty) ? clean : null;
    if (_color == effective) return;
    _color = effective;
    notifyListeners();
  }

  void setImagePath(String? value) {
    if (_imagePath == value) return;
    _imagePath = value;
    notifyListeners();
  }

  /// Construct the immutable Bike model from current form state.
  Bike buildBike({String? id}) {
    return Bike(
      id: id ?? 'bike-${DateTime.now().millisecondsSinceEpoch}',
      make: _make,
      modelName: _modelName,
      modelYear: _modelYear,
      displacement: _displacement,
      bikeType: _bikeType,
      fuelSystem: _fuelSystem,
      carburetorType: _fuelSystem == FuelSystem.carburetor ? _carburetorType : null,
      fuelTankCapacityLiters: _fuelTankCapacityLiters,
      fuelAverageKmPerLiter: _fuelAverageKmpl,
      odometerKm: _odometerKm ?? 0,
      currentFuelLiters: _currentFuelLiters,
      lastOilChange: _lastOilChange,
      lastTuneUp: _lastTuneUp,
      vin: _vin,
      nickname: _nickname,
      plateNumber: _plateNumber,
      color: _color,
      imagePath: _imagePath,
    );
  }

  /// Populates onboarding form fields from a typed recognition result.
  ///
  /// Fills only the fields the result provides and leaves odometer, fuel level,
  /// VIN, and nickname blank. Never sets the fuel system (the rider chooses).
  ///
  /// Note: A real implementation needs a backend call (Firebase AI Logic with Gemini),
  /// parked for the Firebase phase.
  void populateFromRecognition(BikeRecognitionResult result) {
    if (result.make != null && result.make!.isNotEmpty) {
      _make = result.make!;
    }
    if (result.model != null && result.model!.isNotEmpty) {
      _modelName = result.model!;
    }
    if (result.year != null && result.year! > 1900) {
      _modelYear = result.year!;
    }
    if (result.displacementCc != null) {
      _displacement = result.displacementCc;
    }
    if (result.tankCapacityLiters != null) {
      _fuelTankCapacityLiters = result.tankCapacityLiters;
    }
    if (result.category != null && result.category!.isNotEmpty) {
      _bikeType = result.category!;
    }

    // Leave odometer, fuel level, VIN, and nickname blank
    _odometerKm = null;
    _currentFuelLiters = null;
    _vin = null;
    _nickname = null;

    // Never sets the fuel system (the rider chooses).

    notifyListeners();
  }

  /// Reset form state to defaults.
  void reset() {
    _make = 'Honda';
    _modelName = '';
    _modelYear = 2024;
    _displacement = 1100;
    _bikeType = 'Adventure';
    _fuelSystem = FuelSystem.carburetor;
    _carburetorType = null;
    _fuelTankCapacityLiters = null;
    _odometerKm = null;
    _currentFuelLiters = null;
    _fuelAverageKmpl = null;
    _lastOilChange = const ServiceRecord(
      mode: TrackingMode.byDistance,
      km: 3200,
    );
    _lastTuneUp = const ServiceRecord(
      mode: TrackingMode.byDistance,
      km: 5000,
    );
    _vin = null;
    _nickname = null;
    _plateNumber = null;
    _color = null;
    _imagePath = null;
    notifyListeners();
  }
}
