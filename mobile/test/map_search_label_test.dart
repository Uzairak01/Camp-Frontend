import 'dart:convert';

import 'package:camp/core/constants/app_info.dart';
import 'package:camp/features/navigation/controllers/navigation_controller.dart';
import 'package:camp/features/navigation/domain/geocoding_service.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:camp/features/navigation/domain/place_label_builder.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/fake_geocoding_service.dart';
import 'helpers/fake_location_service.dart';
import 'helpers/fake_place_repository.dart';
import 'helpers/fake_routing_service.dart';

/// A rider fix in PUEHS Town II, Lahore (used only as test input).
PositionData _fix(double lat, double lng) => PositionData(
      latitude: lat,
      longitude: lng,
      heading: 0,
      speed: 0,
      accuracy: 5,
      timestamp: DateTime.now(),
    );

const double _lat = 31.4283;
const double _lng = 74.2370;

PlaceSearchResult _androon() => const PlaceSearchResult(
      name: 'اندرون شہر لاہور',
      displayName: 'اندرون شہر لاہور, لاہور, تحصیل لاہور شہر, پنجاب, پاکستان',
      location: LatLng(31.5831841, 74.3184836),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationService location;
  late FakeGeocodingService geocoding;
  late FakePlaceRepository places;
  late NavigationController controller;

  setUp(() {
    location = FakeLocationService(initialPosition: _fix(_lat, _lng));
    geocoding = FakeGeocodingService(
      searchResults: [_androon()],
      reverseResult: const PlaceSearchResult(
        name: 'Agrics Town, PUEHS-II Main Road',
        displayName: 'PUEHS-II Main Road, Agrics Town',
        location: LatLng(_lat, _lng),
      ),
    );
    places = FakePlaceRepository();
    controller = NavigationController(
      locationService: location,
      routingService: FakeRoutingService(),
      geocodingService: geocoding,
      placeRepository: places,
    );
  });

  tearDown(() {
    controller.dispose();
    location.dispose();
  });

  Future<void> pumpSearchBar(WidgetTester tester) async {
    await controller.checkLocationPermissionAndStart();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NavSearchBar(controller: controller, onOpenProfile: () {}),
        ),
      ),
    );
  }

  group('Search submit behaviour', () {
    testWidgets('fires only on submit, never while typing', (tester) async {
      await pumpSearchBar(tester);

      await tester.enterText(find.byType(TextField), 'androon lahore');
      await tester.pump(const Duration(seconds: 2));
      expect(geocoding.searchQueries, isEmpty);
      // The empty-field panel must not show while the rider has typed text.
      expect(find.text('No saved places or recent searches'), findsNothing);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(geocoding.searchQueries, ['androon lahore']);
      // Biased toward the rider's real position.
      expect(geocoding.searchNears.single, const LatLng(_lat, _lng));
      expect(find.text('اندرون شہر لاہور'), findsOneWidget);
    });

    testWidgets('search icon tap submits too', (tester) async {
      await pumpSearchBar(tester);

      await tester.enterText(find.byType(TextField), 'androon lahore');
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(geocoding.searchQueries, ['androon lahore']);
    });

    testWidgets('results stay visible after the keyboard closes',
        (tester) async {
      await pumpSearchBar(tester);

      await tester.enterText(find.byType(TextField), 'androon lahore');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // The search action unfocuses the field; results must still be shown.
      expect(find.text('SEARCH RESULTS'), findsOneWidget);
    });

    testWidgets('tapping a result sets the destination and records a recent',
        (tester) async {
      await pumpSearchBar(tester);

      await tester.enterText(find.byType(TextField), 'androon lahore');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await tester.tap(find.text('اندرون شہر لاہور').last);
      await tester.pumpAndSettle();

      expect(controller.destination?.name, 'اندرون شہر لاہور');
      expect(controller.state, NavigationState.previewing);
      // Recorded through PlaceRepository, not just in memory.
      expect(places.recent.map((p) => p.name), ['اندرون شہر لاہور']);
    });

    testWidgets('shows the empty message when nothing matches', (tester) async {
      geocoding.searchResults = [];
      await pumpSearchBar(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(
        find.text('No results. Try a different spelling or add the city.'),
        findsOneWidget,
      );
      expect(find.text('No saved places or recent searches'), findsNothing);
    });

    testWidgets('shows the failure message when the search fails',
        (tester) async {
      geocoding.searchError = const GeocodingException('offline');
      await pumpSearchBar(tester);

      await tester.enterText(find.byType(TextField), 'androon lahore');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't search. Check your internet connection."),
        findsOneWidget,
      );
    });

    testWidgets('empty-state panel shows for an empty, idle field',
        (tester) async {
      await pumpSearchBar(tester);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('No saved places or recent searches'), findsOneWidget);
    });

    test('a newer search supersedes an older one', () async {
      final first = controller.submitSearch('first');
      geocoding.searchResults = [_androon()];
      await controller.submitSearch('second');
      await first;

      expect(controller.searchStatus, PlaceSearchStatus.results);
      expect(geocoding.searchQueries, ['first', 'second']);
    });
  });

  group('Location label', () {
    test('label builder prefers neighbourhood/suburb over unrelated POIs', () {
      final label = PlaceLabelBuilder.build({
        'amenity': 'Tariq Garden',
        'shop': 'Some Shop',
        'suburb': 'Agrics Town',
        'road': 'PUEHS-II Main Road',
        'city': 'Lahore',
      });
      expect(label, 'Agrics Town, PUEHS-II Main Road, Lahore');
      expect(label, isNot(contains('Tariq Garden')));
    });

    test('label builder prefers neighbourhood and skips missing parts', () {
      expect(
        PlaceLabelBuilder.build({
          'neighbourhood': 'PUEHS Town II',
          'suburb': 'Other',
          'city': 'Lahore',
        }),
        'PUEHS Town II, Lahore',
      );
      expect(PlaceLabelBuilder.build({'road': 'Mall Road'}), 'Mall Road');
    });

    test('label builder returns null when only POI data is present', () {
      expect(PlaceLabelBuilder.build({'amenity': 'Tariq Garden'}), isNull);
      expect(PlaceLabelBuilder.build(null), isNull);
    });

    test('falls back to "Your location" before any lookup and when empty',
        () async {
      geocoding.reverseEmpty = true;
      expect(controller.currentLocationName, 'Your location');

      await controller.initialize();
      expect(controller.currentLocationName, 'Your location');
    });

    test('uses the neighbourhood label from the reverse lookup', () async {
      await controller.initialize();
      expect(
        controller.currentLocationName,
        'Agrics Town, PUEHS-II Main Road',
      );
    });

    test('saved place name is used within 150 m and not beyond', () async {
      await controller.initialize();

      final saved = await controller.saveCurrentLocationAs('PUEHS Town II');
      expect(saved, isTrue);
      expect(controller.currentLocationName, 'PUEHS Town II');
      // Stored through PlaceRepository and listed among saved places.
      expect(places.saved.map((p) => p.name), ['PUEHS Town II']);
      expect(controller.savedPlaces.map((p) => p.name), ['PUEHS Town II']);

      // ~100 m north: still the saved name.
      location.emitPosition(_fix(_lat + 0.0009, _lng));
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentLocationName, 'PUEHS Town II');

      // ~300 m north: beyond 150 m, back to the neighbourhood label.
      location.emitPosition(_fix(_lat + 0.0027, _lng));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.currentLocationName,
        'Agrics Town, PUEHS-II Main Road',
      );
    });

    test('renaming the same spot replaces instead of duplicating', () async {
      await controller.initialize();
      await controller.saveCurrentLocationAs('Home');
      await controller.saveCurrentLocationAs('PUEHS Town II');

      expect(controller.savedPlaces.map((p) => p.name), ['PUEHS Town II']);
      expect(places.saved, hasLength(1));
    });

    test('saving needs a GPS fix and a non-blank name', () async {
      expect(await controller.saveCurrentLocationAs('Home'), isFalse);
      await controller.initialize();
      expect(await controller.saveCurrentLocationAs('   '), isFalse);
      expect(places.saved, isEmpty);
    });

    test('saved places load back through PlaceRepository', () async {
      await controller.initialize();
      await controller.saveCurrentLocationAs('Home');

      final reloaded = NavigationController(
        locationService: location,
        routingService: FakeRoutingService(),
        geocodingService: geocoding,
        placeRepository: places,
      );
      addTearDown(reloaded.dispose);
      await reloaded.loadPlaces();

      expect(reloaded.savedPlaces.map((p) => p.name), ['Home']);
    });
  });

  group('NominatimGeocodingService', () {
    test('search sends pk bias, viewbox (not bounded) and a User-Agent',
        () async {
      late http.Request seen;
      final service = NominatimGeocodingService(
        httpClient: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode([
              {
                'lat': '31.5831841',
                'lon': '74.3184836',
                'name': 'اندرون شہر لاہور',
                'display_name': 'اندرون شہر لاہور, لاہور, پنجاب, پاکستان',
                'type': 'suburb',
              }
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final results = await service.search(
        'androon lahore',
        near: const LatLng(_lat, _lng),
      );

      expect(seen.url.queryParameters['countrycodes'], 'pk');
      expect(seen.url.queryParameters['viewbox'], isNotEmpty);
      expect(seen.url.queryParameters.containsKey('bounded'), isFalse);
      expect(seen.url.queryParameters['q'], 'androon lahore');
      expect(seen.headers['User-Agent'], contains('CAMP-App'));
      expect(seen.headers['User-Agent'], contains(AppInfo.supportEmail));
      expect(results.single.name, 'اندرون شہر لاہور');
      expect(results.single.shortAddress, 'لاہور, پنجاب, پاکستان');
    });

    test('non-200 and network errors throw GeocodingException', () async {
      final bad = NominatimGeocodingService(
        httpClient: MockClient((_) async => http.Response('nope', 503)),
      );
      await expectLater(bad.search('x'), throwsA(isA<GeocodingException>()));

      final offline = NominatimGeocodingService(
        httpClient: MockClient((_) async => throw http.ClientException('down')),
      );
      await expectLater(
        offline.search('y'),
        throwsA(isA<GeocodingException>()),
      );
    });

    test('reverse uses zoom 17 and builds the label from address parts',
        () async {
      late http.Request seen;
      final service = NominatimGeocodingService(
        httpClient: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'name': 'Tariq Garden',
              'display_name': 'Tariq Garden, Somewhere',
              'address': {
                'amenity': 'Tariq Garden',
                'suburb': 'Agrics Town',
                'road': 'PUEHS-II Main Road',
                'city': 'Lahore',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await service.reverseGeocode(const LatLng(_lat, _lng));

      expect(seen.url.queryParameters['zoom'], '17');
      expect(result?.name, 'Agrics Town, PUEHS-II Main Road, Lahore');
    });
  });
}

