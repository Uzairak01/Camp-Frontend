import 'dart:async';
import 'dart:convert';

import 'package:camp/core/widgets/camp_bottom_nav.dart';
import 'package:camp/features/garage/services/fuel_tracker_service.dart';
import 'package:camp/features/navigation/controllers/navigation_controller.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:camp/features/navigation/domain/routing_service.dart';
import 'package:camp/features/navigation/presentation/screens/navigation_map_screen.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_active_bottom_bar.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_active_navigation_overlay.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_compass_button.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_location_sheet.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_permission_banner.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_riding_bottom_bar.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_riding_turn_banner.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_route_preview_panel.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_route_preview_sheet.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_speed_bubble.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_turn_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/fake_geocoding_service.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_routing_service.dart';

class FakeTileProvider extends TileProvider {
  FakeTileProvider();

  static const String _whiteTile =
      'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAAXNSR0IB2cksfwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAANQTFRF////p8QbyAAAAB9JREFUeJztwQENAAAAwqD3T20ON6AAAAAAAAAAAL4NIQAAAfFnIe4AAAAASUVORK5CYII=';
  static final _whiteTileBytes = base64Decode(_whiteTile);

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_whiteTileBytes);
  }
}

void main() {
  Widget buildTestScreen({
    required NavigationController controller,
    required LocationService locationService,
  }) {
    return MaterialApp(
      routes: {
        '/profile': (ctx) => const Scaffold(body: Text('Profile Mock')),
        '/route-packs': (ctx) => const Scaffold(body: Text('Route Packs Mock')),
      },
      home: NavigationMapScreen(
        controller: controller,
        locationService: locationService,
        tileProvider: FakeTileProvider(),
      ),
    );
  }

  group('NavigationMapScreen 3-State Widget Tests', () {
    setUp(() {
      FuelTrackerService.instance.resetForTesting();
    });
    tearDown(() {
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('State 1 (Idle): Shows location sheet, search bar, and bottom nav', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      // State 1 verifies
      expect(find.byType(NavLocationSheet), findsOneWidget);
      expect(find.text('YOUR LOCATION'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);
      expect(find.byType(CampBottomNav), findsOneWidget);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('State 1 -> State 2: Tapping Directions opens Route Preview', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      controller.toggleSavedPlace(
        const PlaceSearchResult(
          name: 'Test Destination',
          displayName: 'Test Destination Point',
          location: LatLng(34.0, 74.0),
        ),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      debugPrint('Scaffold rect: ${tester.getRect(find.byType(Scaffold))}');
      debugPrint('Stack rect: ${tester.getRect(find.byType(Stack).first)}');
      debugPrint('LocationSheet rect: ${tester.getRect(find.byType(NavLocationSheet))}');
      debugPrint('Directions rect: ${tester.getRect(find.text('Directions'))}');
      // Tap Directions button
      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();

      // State 2: Route Preview verified
      expect(controller.state, NavigationState.previewing);
      expect(find.byType(NavRoutePreviewPanel), findsOneWidget);
      expect(find.byType(NavRoutePreviewSheet), findsOneWidget);
      expect(find.text('ROUTE PREVIEW'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('State 2 -> State 3: Tapping Start enters active guidance and hides bottom nav', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      controller.toggleSavedPlace(
        const PlaceSearchResult(
          name: 'Test Destination',
          displayName: 'Test Destination Point',
          location: LatLng(34.0, 74.0),
        ),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      // Open preview then start navigation
      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // State 3: Guidance verified
      expect(controller.state, NavigationState.navigating);
      expect(find.byType(NavTurnBanner), findsOneWidget);
      expect(find.byType(NavActiveNavigationOverlay), findsOneWidget);
      expect(find.byType(NavActiveBottomBar), findsOneWidget);

      // Speedometer & shortcuts present
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Offline Route Packs'), findsOneWidget);

      // CampBottomNav remains visible in READY state
      expect(find.byType(CampBottomNav), findsOneWidget);
      // Slim bar is NOT shown on Maps screen itself
      expect(find.byKey(const ValueKey('active_navigation_slim_bar')), findsNothing);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('State 3 Exit button displays confirmation dialog and resumes/ends', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      controller.toggleSavedPlace(
        const PlaceSearchResult(
          name: 'Test Destination',
          displayName: 'Test Destination Point',
          location: LatLng(34.0, 74.0),
        ),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Tap Exit button (close icon)
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('End navigation?'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('End Ride'), findsOneWidget);

      // Tap Resume: ride continues
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(controller.state, NavigationState.navigating);

      // Tap Exit again, then End Ride: exits to idle
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End Ride'));
      await tester.pumpAndSettle();

      expect(controller.state, NavigationState.idle);
      expect(find.byType(CampBottomNav), findsOneWidget);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('Permission denied displays the alert banner with Open Settings', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService(hasPermission: false);
      final controller = NavigationController(locationService: fakeLocation);
      await controller.checkLocationPermissionAndStart();

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      // Alert banner is displayed
      expect(find.byType(NavPermissionBanner), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('When device location service is off, displays non-blocking hint banner and never blocks the screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService(
        serviceEnabled: false,
        nullInitialPosition: true,
      );
      final controller = NavigationController(locationService: fakeLocation);
      await controller.checkLocationPermissionAndStart();

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      // Non-blocking hint banner is displayed
      expect(find.byType(NavPermissionBanner), findsOneWidget);
      expect(find.text('Location services are disabled on your device.'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      // Verify no blocking dialogs are present
      expect(find.byType(AlertDialog), findsNothing);

      // Verify userLatLng is null and camera center is positioned at Lahore fallback
      expect(controller.userLatLng, isNull);
      expect(controller.cameraCenter, NavigationController.defaultFallbackCenter);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('S4-4a: READY state shows old bottom card, Google Maps, Offline Route Packs, and CampBottomNav', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      FuelTrackerService.instance.setDependenciesForTesting(
        locationService: fakeLocation,
      );
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      controller.toggleSavedPlace(
        const PlaceSearchResult(
          name: 'Test Destination',
          displayName: 'Test Destination Point',
          location: LatLng(34.0, 74.0),
        ),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Navigation is active, but rider has not yet started moving -> READY state
      expect(controller.state, NavigationState.navigating);
      expect(controller.hasStartedMoving, isFalse);

      // Old bottom card and top banner are visible
      expect(find.byType(NavTurnBanner), findsOneWidget);
      expect(find.byType(NavActiveBottomBar), findsOneWidget);
      expect(find.byType(CampBottomNav), findsOneWidget);

      // The two shortcut buttons are visible
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Offline Route Packs'), findsOneWidget);

      // RIDING state bar and top banner are NOT shown
      expect(find.byType(NavRidingBottomBar), findsNothing);
      expect(find.byType(NavRidingTurnBanner), findsNothing);
      expect(find.byType(NavSpeedBubble), findsNothing);
      expect(find.byType(NavCompassButton), findsNothing);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('S4-4a: RIDING state switches to Google-Maps layout: new bar, Then tab, Tracking pill + Finish, and hides old card & CampBottomNav', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      FuelTrackerService.instance.resetForTesting();
      FuelTrackerService.instance.setDependenciesForTesting(
        locationService: fakeLocation,
      );

      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      controller.toggleSavedPlace(
        const PlaceSearchResult(
          name: 'Test Destination',
          displayName: 'Test Destination Point',
          location: LatLng(34.0, 74.0),
        ),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Rider starts moving (speed >= 1.4 m/s for >= 3s -> hasStartedMoving = true)
      final moveTime1 = DateTime.now();
      fakeLocation.emitPosition(
        PositionData(
          latitude: 48.500,
          longitude: -120.600,
          accuracy: 5.0,
          speed: 2.0,
          timestamp: moveTime1,
        ),
      );
      fakeLocation.emitPosition(
        PositionData(
          latitude: 48.500,
          longitude: -120.600,
          accuracy: 5.0,
          speed: 2.0,
          timestamp: moveTime1.add(const Duration(seconds: 3)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // RIDING state widgets are shown
      expect(find.byType(NavRidingTurnBanner), findsOneWidget);
      expect(find.byType(NavRidingBottomBar), findsOneWidget);
      expect(find.byType(NavCompassButton), findsOneWidget);
      expect(find.byType(NavSpeedBubble), findsOneWidget);

      // "Then" tab attached under banner
      expect(find.text('Then'), findsOneWidget);

      // Both shortcut buttons stay visible
      expect(find.text('Google Maps'), findsOneWidget);
      expect(find.text('Offline Route Packs'), findsOneWidget);

      // Tracking ride pill with Finish button
      expect(find.byKey(const ValueKey('tracking_ride_chip')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracking_ride_chip_finish_button')), findsOneWidget);

      // Old bottom card and CampBottomNav are NOT shown
      expect(find.byType(NavActiveBottomBar), findsNothing);
      expect(find.byType(CampBottomNav), findsNothing);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('S4-4a: RIDING state X button opens existing exit sheet with Finish ride, Keep tracking, and Discard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      FuelTrackerService.instance.resetForTesting();
      FuelTrackerService.instance.setDependenciesForTesting(
        locationService: fakeLocation,
      );

      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      controller.toggleSavedPlace(
        const PlaceSearchResult(
          name: 'Test Destination',
          displayName: 'Test Destination Point',
          location: LatLng(34.0, 74.0),
        ),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Enter RIDING state (speed >= 1.4 m/s for >= 3s -> hasStartedMoving = true)
      final moveTime2 = DateTime.now();
      fakeLocation.emitPosition(
        PositionData(
          latitude: 48.500,
          longitude: -120.600,
          accuracy: 5.0,
          speed: 2.0,
          timestamp: moveTime2,
        ),
      );
      fakeLocation.emitPosition(
        PositionData(
          latitude: 48.500,
          longitude: -120.600,
          accuracy: 5.0,
          speed: 2.0,
          timestamp: moveTime2.add(const Duration(seconds: 3)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the outlined X button on the new bottom bar
      final exitBtn = find.byKey(const ValueKey('nav_exit_button'));
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Existing exit sheet options appear: Finish ride, Keep tracking, Discard
      expect(find.text('Finish ride?'), findsOneWidget);
      expect(find.text('Finish ride'), findsWidgets);
      expect(find.text('Keep tracking'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_exit_discard_ride_button')), findsOneWidget);

      // Tap Keep tracking to dismiss
      await tester.tap(find.text('Keep tracking'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('S4-4a: Long Urdu road name does not overflow on a 360 px wide screen', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      FuelTrackerService.instance.setDependenciesForTesting(
        locationService: fakeLocation,
      );
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      controller.toggleSavedPlace(
        const PlaceSearchResult(
          name: 'شاہراہِ پاکستان براستہ راولپنڈی مری روڈ نزدیک پشاور موڑ اسلام آباد',
          displayName: 'شاہراہِ پاکستان براستہ راولپنڈی مری روڈ نزدیک پشاور موڑ اسلام آباد',
          location: LatLng(34.0, 74.0),
        ),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Enter RIDING state (speed >= 1.4 m/s for >= 3s -> hasStartedMoving = true)
      final moveTime3 = DateTime.now();
      fakeLocation.emitPosition(
        PositionData(
          latitude: 48.500,
          longitude: -120.600,
          accuracy: 5.0,
          speed: 2.0,
          timestamp: moveTime3,
        ),
      );
      fakeLocation.emitPosition(
        PositionData(
          latitude: 48.500,
          longitude: -120.600,
          accuracy: 5.0,
          speed: 2.0,
          timestamp: moveTime3.add(const Duration(seconds: 3)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no RenderFlex overflow exception
      expect(tester.takeException(), isNull);
      expect(find.byType(NavRidingTurnBanner), findsOneWidget);
      expect(find.byType(NavRidingBottomBar), findsOneWidget);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('S4-4a: Amber no-internet strip appears under Then tab when reroute fails and disappears when restored', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      FuelTrackerService.instance.setDependenciesForTesting(
        locationService: fakeLocation,
      );
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      controller.toggleSavedPlace(
        const PlaceSearchResult(
          name: 'Test Destination',
          displayName: 'Test Destination Point',
          location: LatLng(34.0, 74.0),
        ),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Enter RIDING state (speed >= 1.4 m/s for >= 3s -> hasStartedMoving = true)
      final moveTime4 = DateTime.now();
      // On-route fix at start
      fakeLocation.emitPosition(
        PositionData(
          latitude: 31.5204,
          longitude: 74.3587,
          accuracy: 5.0,
          speed: 2.0,
          timestamp: moveTime4,
        ),
      );
      fakeLocation.emitPosition(
        PositionData(
          latitude: 31.5204,
          longitude: 74.3587,
          accuracy: 5.0,
          speed: 2.0,
          timestamp: moveTime4.add(const Duration(seconds: 3)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Banner initially absent
      expect(find.byKey(const ValueKey('nav_no_internet_banner')), findsNothing);

      // Trigger failed reroute (network down) by making routing fail on off-route fixes
      fakeRouting.shouldThrow = true;
      for (int i = 1; i <= 4; i++) {
        fakeLocation.emitPosition(
          PositionData(
            latitude: 31.6500, // off-route
            longitude: 74.3587,
            accuracy: 5.0,
            speed: 5.0,
            timestamp: moveTime4.add(Duration(seconds: 3 + (i * 3))),
          ),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Amber strip appears with honest copy
      expect(find.byKey(const ValueKey('nav_no_internet_banner')), findsOneWidget);
      expect(find.textContaining('No internet.', findRichText: true), findsOneWidget);
      expect(
        find.textContaining(
          'Rerouting and new map tiles are unavailable. GPS tracking keeps running.',
          findRichText: true,
        ),
        findsOneWidget,
      );

      // Restore network and trigger successful reroute after 30s cooldown
      fakeRouting.shouldThrow = false;
      fakeLocation.emitPosition(
        PositionData(
          latitude: 31.6500,
          longitude: 74.3587,
          accuracy: 5.0,
          speed: 5.0,
          timestamp: moveTime4.add(const Duration(seconds: 40)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav_no_internet_banner')), findsNothing);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('Route Preview: Location unavailable displays error with Retry and does NOT display Calculating... or Start', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService(
        nullInitialPosition: true,
        serviceEnabled: false,
      );
      final fakeRouting = FakeRoutingService();
      final fakeGeocoding = FakeGeocodingService();
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );
      const destination = PlaceSearchResult(
        name: 'Test Destination',
        displayName: 'Test Destination Point',
        location: LatLng(34.0, 74.0),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      // Enter preview mode
      await controller.openRoutePreview(destination);
      await tester.pumpAndSettle();

      expect(controller.state, NavigationState.previewing);
      expect(controller.routeError, 'Location unavailable. Turn on GPS to calculate route.');

      // Error banner with Retry is shown in bottom area
      expect(find.text('Location unavailable. Turn on GPS to calculate route.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Mutually exclusive: Calculating indicator and Start button must NOT be shown in bottom area
      expect(find.text('Calculating fastest road route...'), findsNothing);
      expect(find.text('Start'), findsNothing);

      // Top panel motorcycle pill displays "Location unavailable" and NOT "Calculating..."
      expect(find.widgetWithText(NavRoutePreviewPanel, 'Location unavailable'), findsOneWidget);
      expect(find.widgetWithText(NavRoutePreviewPanel, 'Calculating...'), findsNothing);

      // Weak GPS chip must NOT be shown during Route Preview to avoid overlapping
      expect(find.text('Weak GPS signal'), findsNothing);

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });

    testWidgets('Route Preview: When route is calculating, shows calculating state with disabled button and no error', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final routeCompleter = Completer<RouteResult>();
      final pendingRouting = _PendingRouteRoutingService(routeCompleter);
      final fakeGeocoding = FakeGeocodingService();
      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: pendingRouting,
        geocodingService: fakeGeocoding,
      );
      const destination = PlaceSearchResult(
        name: 'Pending Route Target',
        displayName: 'Pending Route Point',
        location: LatLng(34.0, 74.0),
      );

      await tester.pumpWidget(
        buildTestScreen(
          controller: controller,
          locationService: fakeLocation,
        ),
      );
      await tester.pumpAndSettle();

      // Open preview with async route pending
      unawaited(controller.openRoutePreview(destination));
      await tester.pump();

      expect(controller.isCalculatingRoute, isTrue);

      // Bottom area displays calculating indicator and disabled Calculating... button
      expect(find.text('Calculating fastest road route...'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Calculating...'), findsOneWidget);

      // Verify button is disabled (onPressed is null)
      final elevatedBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Calculating...'),
      );
      expect(elevatedBtn.onPressed, isNull);

      // Error and active Start button must NOT be present
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Start'), findsNothing);

      // Clean up completer and controller
      routeCompleter.complete(
        const RouteResult(
          polyline: [LatLng(33.7, 73.0), LatLng(34.0, 74.0)],
          distanceMeters: 5000,
          durationSeconds: 300,
          steps: [],
        ),
      );
      await tester.pumpAndSettle();

      controller.dispose();
      fakeLocation.dispose();
      FuelTrackerService.instance.resetForTesting();
    });
  });
}

class _PendingRouteRoutingService extends FakeRoutingService {
  _PendingRouteRoutingService(this.routeCompleter);
  final Completer<RouteResult> routeCompleter;

  @override
  Future<RouteResult> getRoute({
    required List<LatLng> waypoints,
    String mode = 'motorcycle',
    bool requestAlternatives = false,
    double? startBearingDegrees,
    double startBearingToleranceDegrees = 45.0,
    double? startRadiusMeters,
  }) =>
      routeCompleter.future;
}
