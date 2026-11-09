import 'dart:convert';

import 'package:camp/app/routes.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/presentation/screens/home_screen.dart';
import 'package:camp/features/navigation/controllers/navigation_controller.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:camp/features/navigation/domain/routing_service.dart';
import 'package:camp/features/navigation/presentation/screens/navigation_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_geocoding_service.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_routing_service.dart';

class _FakeTileProvider extends TileProvider {
  _FakeTileProvider();

  static const String _whiteTile =
      'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAAXNSR0IB2cksfwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAANQTFRF////p8QbyAAAAB9JREFUeJztwQENAAAAwqD3T20ON6AAAAAAAAAAAL4NIQAAAfFnIe4AAAAASUVORK5CYII=';
  static final _whiteTileBytes = base64Decode(_whiteTile);

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_whiteTileBytes);
  }
}

Widget _wrapTestApp({
  required Widget home,
  Map<String, WidgetBuilder>? routes,
}) {
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: MaterialApp(
      routes: routes ?? {},
      home: home,
    ),
  );
}

/// Test-only subclass under test/ that injects fakes through the constructor
class _TestNavigationController extends NavigationController {
  _TestNavigationController({
    required this.fakeLocationService,
    required this.fakeRoutingService,
    required this.fakeGeocodingService,
  }) : super(
          locationService: fakeLocationService,
          routingService: fakeRoutingService,
          geocodingService: fakeGeocodingService,
        );

  final FakeLocationService fakeLocationService;
  final FakeRoutingService fakeRoutingService;
  final FakeGeocodingService fakeGeocodingService;

  Future<void> startTestNavigation({
    required RouteResult route,
    required PlaceSearchResult destination,
  }) async {
    fakeRoutingService.cannedResult = route;
    await openRoutePreview(destination);
    startNavigation();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationService fakeLocation;
  late FakeRoutingService fakeRouting;
  late FakeGeocodingService fakeGeocoding;
  late _TestNavigationController testController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LocalStore.instance = LocalStore(prefs);

    fakeLocation = FakeLocationService();
    fakeRouting = FakeRoutingService();
    fakeGeocoding = FakeGeocodingService();

    testController = _TestNavigationController(
      fakeLocationService: fakeLocation,
      fakeRoutingService: fakeRouting,
      fakeGeocodingService: fakeGeocoding,
    );
    NavigationController.instance = testController;
  });

  tearDown(() {
    testController.stopNavigation();
    fakeLocation.dispose();
    NavigationController.instance = NavigationController();
  });

  group('Navigation Non-Blocking & Slim Bar Tests', () {
    testWidgets(
      '1. Leaving the Maps screen while navigating shows no dialog and keeps the navigation state',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Set up active navigation with 24.3 km remaining via real preview + start flow
        const testDest = PlaceSearchResult(
          name: 'Babusar Top',
          displayName: 'Babusar Top Pass',
          location: LatLng(35.15, 74.05),
        );
        const testRoute = RouteResult(
          polyline: [LatLng(34.0, 74.0), LatLng(35.15, 74.05)],
          distanceMeters: 24300,
          durationSeconds: 1800,
          steps: [],
        );
        await testController.startTestNavigation(
          route: testRoute,
          destination: testDest,
        );

        // Open Maps screen on top of Home screen
        await tester.pumpWidget(
          _wrapTestApp(
            home: const Scaffold(body: Text('Previous Screen')),
            routes: {
              CampRoutes.navigationMap: (ctx) => NavigationMapScreen(
                    controller: testController,
                    locationService: fakeLocation,
                    tileProvider: _FakeTileProvider(),
                  ),
            },
          ),
        );
        await tester.pump();

        // Push NavigationMapScreen
        final navContext = tester.element(find.text('Previous Screen'));
        Navigator.of(navContext).pushNamed(CampRoutes.navigationMap);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Maps direction screen is visible and navigating
        expect(find.byType(NavigationMapScreen), findsOneWidget);
        expect(testController.state, NavigationState.navigating);

        // Simulate Back button pop
        final mapContext = tester.element(find.byType(NavigationMapScreen));
        Navigator.of(mapContext).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Leaving the Maps screen never shows the "End navigation?" dialog
        expect(find.text('End navigation?'), findsNothing);

        // Previous screen is restored and Navigation state is strictly kept active
        expect(find.text('Previous Screen'), findsOneWidget);
        expect(testController.state, NavigationState.navigating);
      },
    );

    testWidgets(
      '2. The red X still asks first with End navigation confirm',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        const testDest = PlaceSearchResult(
          name: 'Naran Valley',
          displayName: 'Naran Valley Road',
          location: LatLng(34.9, 73.6),
        );
        const testRoute = RouteResult(
          polyline: [LatLng(34.0, 74.0), LatLng(34.9, 73.6)],
          distanceMeters: 15000,
          durationSeconds: 1200,
          steps: [],
        );
        await testController.startTestNavigation(
          route: testRoute,
          destination: testDest,
        );

        await tester.pumpWidget(
          _wrapTestApp(
            home: NavigationMapScreen(
              controller: testController,
              locationService: fakeLocation,
              tileProvider: _FakeTileProvider(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Red circular X button is present on active navigation bottom bar
        final redXButton = find.byIcon(Icons.close_rounded);
        expect(redXButton, findsOneWidget);

        // Tap red X button
        await tester.tap(redXButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // "End navigation?" confirmation prompt is displayed
        expect(find.text('End navigation?'), findsOneWidget);
        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('End Ride'), findsOneWidget);

        // Tap Resume -> guidance continues
        await tester.tap(find.text('Resume'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(testController.state, NavigationState.navigating);
        expect(find.text('End navigation?'), findsNothing);

        // Tap red X button again
        await tester.tap(redXButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Tap End Ride -> guidance ends and controller transitions to idle
        await tester.tap(find.text('End Ride'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(testController.state, NavigationState.idle);
      },
    );

    testWidgets(
      '3. The slim bar shows only while navigating and returns to Maps',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Start on Home screen while NOT navigating (idle)
        await tester.pumpWidget(
          _wrapTestApp(
            home: const HomeScreen(),
            routes: {
              CampRoutes.navigationMap: (ctx) => const Scaffold(body: Text('Maps Screen Opened')),
            },
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Slim bar must NOT show when navigation is not active
        expect(find.byKey(const ValueKey('active_navigation_slim_bar')), findsNothing);
        expect(find.textContaining('Navigation active'), findsNothing);

        // Now activate navigation with exactly 24.3 km left
        const testDest = PlaceSearchResult(
          name: 'Karakoram Base',
          displayName: 'Karakoram Base Camp',
          location: LatLng(35.5, 75.0),
        );
        const testRoute = RouteResult(
          polyline: [LatLng(34.0, 74.0), LatLng(35.5, 75.0)],
          distanceMeters: 24300, // 24.3 km
          durationSeconds: 2100,
          steps: [],
        );
        await testController.startTestNavigation(
          route: testRoute,
          destination: testDest,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Slim bar must show above the dock with the exact distance
        expect(find.byKey(const ValueKey('active_navigation_slim_bar')), findsOneWidget);
        expect(
          find.text('Navigation active - 24.3 km left - Return'),
          findsOneWidget,
        );

        // Tapping the slim bar navigates and returns to Maps
        await tester.tap(find.byKey(const ValueKey('active_navigation_slim_bar')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Maps Screen Opened'), findsOneWidget);
      },
    );
  });
}
