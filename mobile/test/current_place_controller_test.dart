import 'package:camp/core/data/last_known_place_model.dart';
import 'package:camp/features/dashboard/presentation/widgets/cockpit_status_card_widget.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/sos_location_card.dart';
import 'package:camp/features/navigation/controllers/current_place_controller.dart';
import 'package:camp/features/navigation/controllers/navigation_controller.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_location_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/fake_geocoding_service.dart';
import 'helpers/fake_last_known_place_repository.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_place_repository.dart';
import 'helpers/fake_routing_service.dart';

PositionData _pos(double lat, double lng) => PositionData(
      latitude: lat,
      longitude: lng,
      heading: 0,
      speed: 0,
      accuracy: 5,
      timestamp: DateTime.now(),
    );

const double _testLat = 31.4283;
const double _testLng = 74.2370;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationService fakeLocation;
  late FakeGeocodingService fakeGeocoding;
  late FakePlaceRepository fakePlaceRepo;
  late FakeLastKnownPlaceRepository fakeLastKnownRepo;

  setUp(() {
    fakeLocation = FakeLocationService(
      initialPosition: _pos(_testLat, _testLng),
      serviceEnabled: true,
      hasPermission: true,
    );
    fakeGeocoding = FakeGeocodingService(
      reverseResult: const PlaceSearchResult(
        name: 'Agrics Town, Lahore',
        displayName: 'Agrics Town, Lahore, Punjab',
        location: LatLng(_testLat, _testLng),
      ),
    );
    fakePlaceRepo = FakePlaceRepository();
    fakeLastKnownRepo = FakeLastKnownPlaceRepository();

    CurrentPlaceController.resetWith(
      locationService: fakeLocation,
      geocodingService: fakeGeocoding,
      placeRepository: fakePlaceRepo,
      lastKnownPlaceRepository: fakeLastKnownRepo,
    );
  });

  tearDown(() {
    fakeLocation.dispose();
  });

  group('CurrentPlaceController Shared Location Label Tests', () {
    test('cold start shows the persisted label with the "Last known" hint',
        () async {
      fakeLastKnownRepo.cachedPlace = LastKnownPlace(
        id: 'last_known_place',
        label: 'PUEHS Town II, Lahore',
        latitude: _testLat,
        longitude: _testLng,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final controller = CurrentPlaceController(
        locationService: fakeLocation,
        geocodingService: fakeGeocoding,
        placeRepository: fakePlaceRepo,
        lastKnownPlaceRepository: fakeLastKnownRepo,
      );

      await controller.initialize();

      // Immediately shows the persisted label with "Last known: " hint
      expect(controller.displayLabel, 'Last known: PUEHS Town II, Lahore');
      expect(controller.isLastKnownFromCache, isTrue);

      // When fresh position fix arrives, "Last known: " hint drops
      await controller.updatePosition(_pos(_testLat, _testLng), isFreshFix: true);
      expect(controller.displayLabel, isNot(contains('Last known')));
      expect(controller.displayLabel, 'Agrics Town, Lahore');
      expect(controller.isLastKnownFromCache, isFalse);

      controller.dispose();
    });

    test('location off shows "Location off"', () async {
      final offLocation = FakeLocationService(
        initialPosition: _pos(_testLat, _testLng),
        serviceEnabled: false,
        hasPermission: false,
      );

      final controller = CurrentPlaceController(
        locationService: offLocation,
        geocodingService: fakeGeocoding,
        placeRepository: fakePlaceRepo,
        lastKnownPlaceRepository: fakeLastKnownRepo,
      );

      await controller.initialize();

      expect(controller.displayLabel, 'Location off');
      expect(controller.isLocationOff, isTrue);

      controller.dispose();
      offLocation.dispose();
    });

    test('shows "Locating..." ONLY when there has never been a label and nothing cached',
        () async {
      final noFixLocation = FakeLocationService(
        nullInitialPosition: true,
        serviceEnabled: true,
        hasPermission: true,
      );

      final controller = CurrentPlaceController(
        locationService: noFixLocation,
        geocodingService: fakeGeocoding,
        placeRepository: fakePlaceRepo,
        lastKnownPlaceRepository: fakeLastKnownRepo,
      );

      await controller.checkPermissionAndStart();

      expect(controller.displayLabel, 'Locating...');

      controller.dispose();
      noFixLocation.dispose();
    });

    test('saved place name wins within 150 m and not beyond', () async {
      final controller = CurrentPlaceController(
        locationService: fakeLocation,
        geocodingService: fakeGeocoding,
        placeRepository: fakePlaceRepo,
        lastKnownPlaceRepository: fakeLastKnownRepo,
      );

      await controller.initialize();
      expect(controller.displayLabel, 'Agrics Town, Lahore');

      // Save place at current position
      await fakePlaceRepo.saveSavedPlaces([
        const PlaceSearchResult(
          name: 'Home Base',
          displayName: 'Home Base, Sector A',
          location: LatLng(_testLat, _testLng),
        ),
      ]);
      await controller.reloadSavedPlaces();

      // Within 150m: saved place name wins
      expect(controller.displayLabel, 'Home Base');

      // Move ~100m north: still within 150m, saved place name still wins
      await controller.updatePosition(_pos(_testLat + 0.0009, _testLng));
      expect(controller.displayLabel, 'Home Base');

      // Move ~300m north (> 150m): beyond radius, falls back to reverse geocode
      await controller.updatePosition(_pos(_testLat + 0.0028, _testLng));
      expect(controller.displayLabel, 'Agrics Town, Lahore');

      controller.dispose();
    });

    test('refresh only after moving over 100 m or after 5 minutes', () async {
      final controller = CurrentPlaceController(
        locationService: fakeLocation,
        geocodingService: fakeGeocoding,
        placeRepository: fakePlaceRepo,
        lastKnownPlaceRepository: fakeLastKnownRepo,
      );

      await controller.initialize();
      final initialCalls = fakeGeocoding.reverseCalls;
      expect(initialCalls, greaterThanOrEqualTo(1));

      // Move ~50m (< 100m): NO geocode refresh
      await controller.updatePosition(_pos(_testLat + 0.0004, _testLng));
      expect(fakeGeocoding.reverseCalls, equals(initialCalls));

      // Move > 100m: triggers geocode refresh
      await controller.updatePosition(_pos(_testLat + 0.0015, _testLng));
      expect(fakeGeocoding.reverseCalls, greaterThan(initialCalls));

      controller.dispose();
    });

    test('while a refresh runs, keeps showing the old label with no "Locating..." text',
        () async {
      final controller = CurrentPlaceController(
        locationService: fakeLocation,
        geocodingService: fakeGeocoding,
        placeRepository: fakePlaceRepo,
        lastKnownPlaceRepository: fakeLastKnownRepo,
      );

      await controller.initialize();
      expect(controller.displayLabel, 'Agrics Town, Lahore');

      // Move > 100m to trigger refresh
      controller.updatePosition(_pos(_testLat + 0.002, _testLng));

      // While refreshing, displayLabel continues to show old label, NOT "Locating..."
      expect(controller.displayLabel, isNot(equals('Locating...')));
      expect(controller.displayLabel, 'Agrics Town, Lahore');

      controller.dispose();
    });
  });

  group('Cross-Screen Uniformity & Zero "Locating..." on Return Tests', () {
    testWidgets('Home, SOS and Maps show identical label for the same position',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await CurrentPlaceController.instance.initialize();
      final expectedLabel = CurrentPlaceController.instance.displayLabel;
      expect(expectedLabel, 'Agrics Town, Lahore');

      // 1. Home Cockpit card shows identical label
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CockpitStatusCardWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expectedLabel), findsOneWidget);

      // 2. SOS Location card shows identical label
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosLocationCard(locationService: fakeLocation),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expectedLabel), findsOneWidget);

      // 3. Maps NavLocationSheet shows identical label
      final navController = NavigationController(
        locationService: fakeLocation,
        routingService: FakeRoutingService(),
        geocodingService: fakeGeocoding,
        placeRepository: fakePlaceRepo,
        currentPlaceController: CurrentPlaceController.instance,
      );
      await navController.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavLocationSheet(
              controller: navController,
              onTapDirections: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expectedLabel), findsOneWidget);

      navController.dispose();
    });

    testWidgets('returning to a screen shows cached label with no "Locating..." text',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await CurrentPlaceController.instance.initialize();

      // Screen 1: Home
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CockpitStatusCardWidget()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Agrics Town, Lahore'), findsOneWidget);
      expect(find.text('Locating...'), findsNothing);

      // Switch to Screen 2: Emergency SOS
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SosLocationCard(locationService: fakeLocation)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Agrics Town, Lahore'), findsOneWidget);
      expect(find.text('Locating...'), findsNothing);

      // Return to Screen 1: Home
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CockpitStatusCardWidget()),
        ),
      );
      await tester.pumpAndSettle();

      // Must show the cached label immediately, NO "Locating..." text
      expect(find.text('Agrics Town, Lahore'), findsOneWidget);
      expect(find.text('Locating...'), findsNothing);
    });

    testWidgets('no screen except shared controller calls geocoding service for labels',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await CurrentPlaceController.instance.initialize();
      final callsAfterControllerInit = fakeGeocoding.reverseCalls;

      // Mount Home
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CockpitStatusCardWidget()),
        ),
      );
      await tester.pumpAndSettle();

      // Mount SOS
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SosLocationCard(locationService: fakeLocation)),
        ),
      );
      await tester.pumpAndSettle();

      // Return to Home
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CockpitStatusCardWidget()),
        ),
      );
      await tester.pumpAndSettle();

      // Reverse geocode calls did NOT increase on screen visits!
      expect(fakeGeocoding.reverseCalls, equals(callsAfterControllerInit));
    });
  });
}
