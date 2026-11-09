import 'package:camera/camera.dart';
import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/data/bike_repository.dart';
import 'package:camp/core/data/last_known_place_model.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/bike_scan/controllers/bike_onboarding_controller.dart';
import 'package:camp/features/bike_scan/domain/camera_permission_service.dart';
import 'package:camp/features/bike_scan/presentation/screens/bike_scan_screen.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/presentation/widgets/cockpit_status_card_widget.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/navigation/controllers/current_place_controller.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_in_progress_ride_repository.dart';
import 'helpers/fake_last_known_place_repository.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_ride_report_repository.dart';

/// Fake implementation of [CameraPermissionService] for testing.
class FakeCameraPermissionService implements CameraPermissionService {
  FakeCameraPermissionService({
    this.status = CameraPermissionStatus.denied,
    this.requestResult,
  });

  CameraPermissionStatus status;
  CameraPermissionStatus? requestResult;
  int checkCalls = 0;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<CameraPermissionStatus> checkPermission() async {
    checkCalls++;
    return status;
  }

  @override
  Future<CameraPermissionStatus> requestPermission() async {
    requestCalls++;
    final next = requestResult ?? status;
    status = next;
    return next;
  }

  @override
  Future<void> openAppSettings() async {
    openSettingsCalls++;
  }
}

/// Fake [BikeRepository] for test setup.
class _FakeBikeRepository implements BikeRepository {
  List<Bike> _bikes = [];
  String? _activeBikeId;
  bool _firstRun = false;

  @override
  Future<bool> isFirstRun() async => _firstRun;

  @override
  Future<void> markFirstRunCompleted() async => _firstRun = false;

  @override
  Future<List<Bike>> loadBikes() async => List<Bike>.from(_bikes);

  @override
  Future<void> saveBikes(List<Bike> bikes) async =>
      _bikes = List<Bike>.from(bikes);

  @override
  Future<String?> loadActiveBikeId() async => _activeBikeId;

  @override
  Future<void> saveActiveBikeId(String? id) async => _activeBikeId = id;

  @override
  Future<void> deleteBike(String id) async =>
      _bikes.removeWhere((b) => b.id == id);

  @override
  Future<void> clear() async {
    _bikes = [];
    _activeBikeId = null;
  }

  @override
  Future<void> flush() async {}
}

/// Fake camera controller for widget tests.
class FakeTestCameraController extends CameraController {
  FakeTestCameraController({
    CameraDescription? cameraDescription,
    this.shouldThrowOnInitialize = false,
  })  : _desc = cameraDescription ??
            const CameraDescription(
              name: 'test_back_camera',
              lensDirection: CameraLensDirection.back,
              sensorOrientation: 0,
            ),
        super(
          cameraDescription ??
              const CameraDescription(
                name: 'test_back_camera',
                lensDirection: CameraLensDirection.back,
                sensorOrientation: 0,
              ),
          ResolutionPreset.high,
          enableAudio: false,
        );

  final CameraDescription _desc;
  bool shouldThrowOnInitialize;
  bool isInitializeCalled = false;
  bool _initialized = false;

  @override
  CameraDescription get description => _desc;

  @override
  CameraValue get value => CameraValue.uninitialized(_desc).copyWith(
        isInitialized: _initialized,
        previewSize: const Size(1920, 1080),
      );

  @override
  Future<void> initialize() async {
    isInitializeCalled = true;
    if (shouldThrowOnInitialize) {
      throw CameraException(
          'CameraInitFailure', 'Simulated hardware initialization error');
    }
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    super.dispose();
  }
}

void main() {
  group('1. Home Hero Card Location Chip Overflow', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LocalStore.instance.resetForTesting();
      AppRepositories.resetWith(
        bikeRepository: _FakeBikeRepository(),
        rideReportRepository: FakeRideReportRepository(),
        inProgressRideRepository: FakeInProgressRideRepository(),
      );

      ProfileController.instance.resetForTesting();
      ActiveBikeController.instance.resetForTesting();
    });

    testWidgets(
      'Narrow card with long mixed English/Urdu place label renders without overflow and with ellipsis',
      (tester) async {
        const longMixedLabel =
            'Margalla Avenue, Sector E-9, اسلام آباد, Islamabad Capital Territory, Pakistan - Near Air University Campus Complex';

        final now = DateTime.utc(2026, 6, 1, 10, 0, 0);
        final fakeLastKnownRepo = FakeLastKnownPlaceRepository(
          cachedPlace: LastKnownPlace(
            id: 'lkp-test',
            latitude: 33.7182,
            longitude: 73.0605,
            label: longMixedLabel,
            timestamp: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final fakeLocation = FakeLocationService(
          initialPosition: PositionData(
            latitude: 33.7182,
            longitude: 73.0605,
            accuracy: 10.0,
            speed: 0.0,
            heading: 0.0,
            timestamp: DateTime.utc(2026, 6, 1, 10, 0, 0),
          ),
        );

        CurrentPlaceController.resetWith(
          locationService: fakeLocation,
          lastKnownPlaceRepository: fakeLastKnownRepo,
        );

        await CurrentPlaceController.instance.initialize();
        await tester.pump();

        expect(
          CurrentPlaceController.instance.displayLabel,
          'Last known: $longMixedLabel',
        );

        // Catch any overflow exceptions during layout
        final originalOnError = FlutterError.onError;
        final overflowErrors = <FlutterErrorDetails>[];
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed') ||
              details.toString().contains('RenderFlex')) {
            overflowErrors.add(details);
          }
          originalOnError?.call(details);
        };

        try {
          // Render the hero card at a constrained narrow width (280 px)
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 280,
                    child: CockpitStatusCardWidget(
                      onProfilePressed: () {},
                      onCtaPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          // Assert zero overflow errors occurred
          expect(overflowErrors, isEmpty,
              reason: 'Location chip must not overflow narrow card width');

          // Find the Text widget that displays the label
          final labelFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data != null &&
                widget.data!.contains('Last known: Margalla Avenue'),
          );
          expect(labelFinder, findsOneWidget);

          final textWidget = tester.widget<Text>(labelFinder);
          expect(textWidget.maxLines, 1);
          expect(textWidget.overflow, TextOverflow.ellipsis);

          // Full text must remain accessible in Semantics for screen readers
          final semanticsFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label != null &&
                widget.properties.label!.contains('Last known: Margalla Avenue'),
          );
          expect(semanticsFinder, findsOneWidget);
        } finally {
          FlutterError.onError = originalOnError;
        }
      },
    );
  });

  group('2. Camera Permission and Multi-State Handling', () {
    const testCameraDesc = CameraDescription(
      name: 'back_cam',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 0,
    );

    setUp(() {
      BikeOnboardingController.instance.reset();
      ActiveBikeController.instance.resetForTesting();
    });

    testWidgets(
      'State (a): Denied on first start then granted via "Grant permission" button starts preview without reopening',
      (tester) async {
        final fakePermissionService = FakeCameraPermissionService(
          status: CameraPermissionStatus.denied,
          requestResult: CameraPermissionStatus.denied,
        );

        final fakeController = FakeTestCameraController();

        await tester.pumpWidget(
          MaterialApp(
            home: BikeScanScreen(
              permissionService: fakePermissionService,
              camerasFetcher: () async => [testCameraDesc],
              controllerCreator: (_) => fakeController,
            ),
          ),
        );
        await tester.pump();

        // Initially shows permission denied message and "Grant permission" button
        expect(find.text('Camera permission is needed to scan'), findsOneWidget);
        expect(find.text('Grant permission'), findsOneWidget);
        expect(find.text('Enter details manually'), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
        expect(fakeController.isInitializeCalled, isFalse);

        // When rider taps "Grant permission", grant it
        fakePermissionService.requestResult = CameraPermissionStatus.granted;
        await tester.tap(find.text('Grant permission'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        // Camera starts without reopening the screen
        expect(fakeController.isInitializeCalled, isTrue);
        expect(fakeController.value.isInitialized, isTrue);
        expect(find.text('Camera permission is needed to scan'), findsNothing);
      },
    );

    testWidgets(
      'State (a): Permanently denied shows "Camera permission is needed to scan" with "Open app settings" button',
      (tester) async {
        final fakePermissionService = FakeCameraPermissionService(
          status: CameraPermissionStatus.permanentlyDenied,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BikeScanScreen(
              permissionService: fakePermissionService,
              camerasFetcher: () async => [testCameraDesc],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Camera permission is needed to scan'), findsOneWidget);
        expect(find.text('Open app settings'), findsOneWidget);
        expect(find.text('Enter details manually'), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);

        // Tapping "Open app settings" triggers openAppSettings
        await tester.tap(find.text('Open app settings'));
        await tester.pump();
        expect(fakePermissionService.openSettingsCalls, 1);
      },
    );

    testWidgets(
      'State (b): No camera hardware found shows "Camera unavailable on this device."',
      (tester) async {
        final fakePermissionService = FakeCameraPermissionService(
          status: CameraPermissionStatus.granted,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: BikeScanScreen(
              permissionService: fakePermissionService,
              camerasFetcher: () async =>
                  <CameraDescription>[], // Empty hardware list
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Camera unavailable on this device.'), findsOneWidget);
        expect(find.text('Enter details manually'), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'State (c): Initialization failure shows "Couldn\'t start the camera. Try again" with "Retry" button',
      (tester) async {
        final fakePermissionService = FakeCameraPermissionService(
          status: CameraPermissionStatus.granted,
        );

        var throwError = true;
        FakeTestCameraController? lastCreatedController;

        await tester.pumpWidget(
          MaterialApp(
            home: BikeScanScreen(
              permissionService: fakePermissionService,
              camerasFetcher: () async => [testCameraDesc],
              controllerCreator: (_) {
                final ctrl = FakeTestCameraController(shouldThrowOnInitialize: throwError);
                lastCreatedController = ctrl;
                return ctrl;
              },
            ),
          ),
        );
        await tester.pump();

        expect(
            find.text("Couldn't start the camera. Try again"), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Enter details manually'), findsOneWidget);
        expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);

        // Fix the controller factory and tap Retry
        throwError = false;
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(lastCreatedController?.value.isInitialized, isTrue);
        expect(find.text("Couldn't start the camera. Try again"), findsNothing);
      },
    );

    testWidgets(
      'Resuming app from Settings automatically re-checks permission and starts camera preview',
      (tester) async {
        final fakePermissionService = FakeCameraPermissionService(
          status: CameraPermissionStatus.permanentlyDenied,
        );

        final fakeController = FakeTestCameraController();

        await tester.pumpWidget(
          MaterialApp(
            home: BikeScanScreen(
              permissionService: fakePermissionService,
              camerasFetcher: () async => [testCameraDesc],
              controllerCreator: (_) => fakeController,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Open app settings'), findsOneWidget);
        expect(fakeController.isInitializeCalled, isFalse);

        // User grants permission in system Settings and returns to CAMP
        fakePermissionService.status = CameraPermissionStatus.granted;

        // Simulate app pause & resume lifecycle transition
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        // Controller initialized automatically without requiring user interaction
        expect(fakeController.isInitializeCalled, isTrue);
        expect(fakeController.value.isInitialized, isTrue);
        expect(find.text('Open app settings'), findsNothing);
      },
    );
  });
}
