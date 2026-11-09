import 'dart:convert';

import 'package:camp/app/routes.dart';
import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/mechanics/controllers/mechanic_controller.dart';
import 'package:camp/features/mechanics/domain/mechanic_model.dart';
import 'package:camp/features/mechanics/presentation/screens/add_mechanic_screen.dart';
import 'package:camp/features/mechanics/presentation/screens/mechanics_home_screen.dart';
import 'package:camp/features/mechanics/presentation/widgets/map_pin_picker_modal.dart';
import 'package:camp/features/navigation/controllers/navigation_controller.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
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

Widget _testApp({
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LocalStore(prefs);
    LocalStore.instance = store;
    AppRepositories.resetWith();
    MechanicController.instance.resetForTesting();
  });

  group('Mechanic Start Guidance & Location Tests', () {
    testWidgets('1. Shop with saved coordinates opens Maps with destination and route preview',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const mechanicWithCoords = Mechanic(
        id: 'mech-coords-1',
        name: 'Lahore Express Moto',
        durationOrLocation: 'Mall Road, Lahore',
        address: 'Mall Road, Lahore',
        latitude: 31.5500,
        longitude: 74.3400,
        phone: '03001234567',
      );
      MechanicController.instance.addMechanic(mechanicWithCoords);

      PlaceSearchResult? receivedDestination;

      await tester.pumpWidget(
        _testApp(
          home: const MechanicsHomeScreen(),
          routes: {
            CampRoutes.navigationMap: (ctx) {
              receivedDestination =
                  ModalRoute.of(ctx)?.settings.arguments as PlaceSearchResult?;
              return Scaffold(
                body: Text('Maps Screen: ${receivedDestination?.name}'),
              );
            },
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Route GPS button to open Navigation Route modal
      final routeIconFinder = find.text('Route GPS');
      expect(routeIconFinder, findsOneWidget);
      await tester.tap(routeIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert Navigation Route modal is shown with 'Start Guidance'
      expect(find.text('Navigation Route'), findsOneWidget);
      expect(find.text('Start Guidance'), findsOneWidget);

      // Tap Start Guidance
      await tester.tap(find.text('Start Guidance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Maps opened with the shop's coordinates and name as destination
      expect(receivedDestination, isNotNull);
      expect(receivedDestination!.name, 'Lahore Express Moto');
      expect(receivedDestination!.location.latitude, 31.5500);
      expect(receivedDestination!.location.longitude, 74.3400);
      expect(find.text('Maps Screen: Lahore Express Moto'), findsOneWidget);
    });

    testWidgets('2. Shop with text address only: looks up address, shows Found/Confirm, and saves coordinates',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const mechanicAddressOnly = Mechanic(
        id: 'mech-addr-1',
        name: 'Tajpure Bike Clinic',
        durationOrLocation: 'tajpure Lahore',
        address: 'tajpure Lahore',
        latitude: null,
        longitude: null,
        phone: '03007654321',
      );
      MechanicController.instance.addMechanic(mechanicAddressOnly);

      final fakeGeocoding = FakeGeocodingService(
        searchResults: [
          const PlaceSearchResult(
            name: 'Tajpura Scheme',
            displayName: 'Tajpura Scheme, Lahore, Punjab, Pakistan',
            location: LatLng(31.5678, 74.3890),
          ),
        ],
      );

      PlaceSearchResult? receivedDestination;

      await tester.pumpWidget(
        _testApp(
          home: MechanicsHomeScreen(geocodingService: fakeGeocoding),
          routes: {
            CampRoutes.navigationMap: (ctx) {
              receivedDestination =
                  ModalRoute.of(ctx)?.settings.arguments as PlaceSearchResult?;
              return Scaffold(
                body: Text('Maps Screen: ${receivedDestination?.name}'),
              );
            },
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open route modal
      await tester.tap(find.text('Route GPS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Start Guidance
      await tester.tap(find.text('Start Guidance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Found / Confirm step is shown
      expect(
        find.textContaining('Found: Tajpura Scheme, Lahore'),
        findsOneWidget,
      );
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Coordinates must be saved on mechanic in controller
      final updated = MechanicController.instance.mechanics.firstWhere(
        (m) => m.id == 'mech-addr-1',
      );
      expect(updated.latitude, 31.5678);
      expect(updated.longitude, 74.3890);

      // Verify route was started with the resolved coordinates
      expect(receivedDestination, isNotNull);
      expect(receivedDestination!.location.latitude, 31.5678);
      expect(receivedDestination!.location.longitude, 74.3890);
    });

    testWidgets('3. Shop with address not found: shows message and button to edit shop',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const mechanicUnknownAddr = Mechanic(
        id: 'mech-unknown-1',
        name: 'Secret Mountain Shed',
        durationOrLocation: 'unreachable_fictional_place_xyz',
        address: 'unreachable_fictional_place_xyz',
        latitude: null,
        longitude: null,
      );
      MechanicController.instance.addMechanic(mechanicUnknownAddr);

      final fakeGeocoding = FakeGeocodingService(searchResults: []);

      await tester.pumpWidget(
        _testApp(
          home: MechanicsHomeScreen(geocodingService: fakeGeocoding),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open route modal
      await tester.tap(find.text('Route GPS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Start Guidance
      await tester.tap(find.text('Start Guidance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify message: "Couldn't find this address. Add the shop's location."
      expect(
        find.text("Couldn't find this address. Add the shop's location."),
        findsOneWidget,
      );
      expect(find.text('Edit Shop'), findsOneWidget);
    });

    testWidgets('4. Shop with no address and no coordinates: shows no location message and edit button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const mechanicNoLoc = Mechanic(
        id: 'mech-noloc-1',
        name: 'Ghost Workshop',
        durationOrLocation: '',
        address: null,
        latitude: null,
        longitude: null,
      );
      MechanicController.instance.addMechanic(mechanicNoLoc);

      await tester.pumpWidget(
        _testApp(
          home: const MechanicsHomeScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open route modal
      await tester.tap(find.text('Route GPS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Start Guidance
      await tester.tap(find.text('Start Guidance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify message: "This shop has no location saved." and Edit button
      expect(find.text('This shop has no location saved.'), findsOneWidget);
      expect(find.text('Edit Shop'), findsOneWidget);
    });

    testWidgets('5. Routing failure in NavigationMapScreen shows Retry and no invented route',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService();
      final fakeRouting = FakeRoutingService(
        shouldThrow: true,
        errorMessage: 'Network timeout: offline or server unavailable',
      );
      final fakeGeocoding = FakeGeocodingService();

      final controller = NavigationController(
        locationService: fakeLocation,
        routingService: fakeRouting,
        geocodingService: fakeGeocoding,
      );

      const dest = PlaceSearchResult(
        name: 'Peak Garage',
        displayName: 'Peak Garage, Pass Summit',
        location: LatLng(35.8812, 74.4512),
      );

      await tester.pumpWidget(
        _testApp(
          home: NavigationMapScreen(
            initialDestination: dest,
            controller: controller,
            locationService: fakeLocation,
            tileProvider: _FakeTileProvider(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Routing error must be visible with Retry button
      expect(
        find.textContaining('Network timeout: offline or server unavailable'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      // Verify no invented duration or distance is displayed
      expect(controller.route, isNull);
      expect(find.text('Fastest route'), findsNothing);

      controller.dispose();
      fakeLocation.dispose();
    });

    testWidgets('6. AddMechanicScreen: form has NO latitude or longitude text fields',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          home: const AddMechanicScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert no latitude or longitude text fields exist
      expect(find.textContaining('Latitude'), findsNothing);
      expect(find.textContaining('Longitude'), findsNothing);

      // Assert typed address field is present
      expect(find.text('Address / Location'), findsOneWidget);

      // Assert Location status shows 'No location yet'
      expect(find.text('No location yet'), findsOneWidget);

      // Assert action buttons exist
      expect(find.byKey(const ValueKey('use_current_location_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('choose_on_map_button')), findsOneWidget);
    });

    testWidgets('7. AddMechanicScreen: Use my current location button saves phone position',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLocation = FakeLocationService(
        initialPosition: PositionData(
          latitude: 31.4800,
          longitude: 74.3200,
          timestamp: DateTime.now(),
        ),
      );

      Mechanic? savedMechanic;

      await tester.pumpWidget(
        _testApp(
          home: AddMechanicScreen(
            locationService: fakeLocation,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fill in shop name
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Peak Moto & Adventure Rig Prep'),
        'Gulberg Moto Hub',
      );

      // Tap "Use my current location"
      await tester.tap(find.byKey(const ValueKey('use_current_location_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert status updated to "Location saved"
      expect(find.text('Location saved'), findsOneWidget);
      expect(find.textContaining('31.4800°'), findsOneWidget);
      expect(find.textContaining('74.3200°'), findsOneWidget);

      // Save the mechanic
      await tester.ensureVisible(find.text('Save Mechanic'));
      await tester.tap(find.text('Save Mechanic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      savedMechanic = MechanicController.instance.mechanics.firstWhere(
        (m) => m.name == 'Gulberg Moto Hub',
      );
      expect(savedMechanic.latitude, 31.4800);
      expect(savedMechanic.longitude, 74.3200);

      fakeLocation.dispose();
    });

    testWidgets('8. MapPinPickerModal: tapping on map drops pin and confirms location',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      LatLng? pickedLocation;

      await tester.pumpWidget(
        _testApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  pickedLocation = await showDialog<LatLng>(
                    context: ctx,
                    builder: (modalCtx) => MapPinPickerModal(
                      initialCenter: const LatLng(31.5204, 74.3587),
                      tileProvider: _FakeTileProvider(),
                    ),
                  );
                },
                child: const Text('Open Map Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open Map Picker
      await tester.tap(find.text('Open Map Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose on Map'), findsOneWidget);
      expect(find.textContaining('Pin at'), findsOneWidget);

      // Confirm button should be enabled
      final confirmBtn = find.byKey(const ValueKey('confirm_map_pin_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify location was picked
      expect(pickedLocation, isNotNull);
      expect(pickedLocation!.latitude, 31.5204);
      expect(pickedLocation!.longitude, 74.3587);
    });

    testWidgets('9. Saving with only a typed address still works (null coordinates)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _testApp(
          home: const AddMechanicScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter name and address only (no GPS location action)
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Peak Moto & Adventure Rig Prep'),
        'Address Only Garage',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. 42 Timberline Rd, Babusar Valley'),
        'tajpure Lahore',
      );

      // Tap Save Mechanic
      await tester.ensureVisible(find.text('Save Mechanic'));
      await tester.tap(find.text('Save Mechanic'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final saved = MechanicController.instance.mechanics.firstWhere(
        (m) => m.name == 'Address Only Garage',
      );
      expect(saved.address, 'tajpure Lahore');
      expect(saved.latitude, isNull);
      expect(saved.longitude, isNull);
    });
  });
}
