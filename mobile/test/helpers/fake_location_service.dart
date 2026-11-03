import 'dart:async';

import 'package:camp/features/navigation/domain/location_service.dart';

/// Fake implementation of [LocationService] for testing.
class FakeLocationService implements LocationService {
  FakeLocationService({
    PositionData? initialPosition,
    bool nullInitialPosition = false,
    this.hasPermission = true,
    this.serviceEnabled = true,
  }) : _currentPosition = nullInitialPosition
            ? null
            : (initialPosition ??
                PositionData(
                  latitude: 48.515,
                  longitude: -120.690,
                  heading: 45.0,
                  speed: 16.7, // ~60 km/h
                  accuracy: 5.0,
                  timestamp: DateTime.now(),
                ));

  PositionData? _currentPosition;
  bool hasPermission;
  bool serviceEnabled;
  final StreamController<PositionData> _controller =
      StreamController<PositionData>.broadcast();

  void clearPosition() {
    _currentPosition = null;
  }

  void emitPosition(PositionData position) {
    _currentPosition = position;
    _controller.add(position);
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> checkPermission() async => hasPermission;

  @override
  Future<bool> requestPermission() async => hasPermission;

  @override
  Future<PositionData?> getCurrentPosition() async => _currentPosition;

  @override
  Future<PositionData?> getLastKnownPosition() async => _currentPosition;

  @override
  Stream<PositionData> getPositionStream({
    bool highAccuracy = false,
    bool enableForegroundNotification = false,
  }) {
    return _controller.stream;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  void dispose() {
    _controller.close();
  }
}
