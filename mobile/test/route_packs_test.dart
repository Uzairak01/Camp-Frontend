import 'package:camp/features/navigation/presentation/screens/route_packs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_location_service.dart';

Widget noAnimApp(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocationService fakeLocationService;

  setUp(() async {
    fakeLocationService = FakeLocationService();
  });

  group('Route Packs Honesty Pass Tests', () {
    testWidgets('Every pack shows Coming soon and no sizes, download buttons, or progress',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 2400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(noAnimApp(RoutePacksScreen(locationService: fakeLocationService)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Pack titles are present
      expect(find.text('Karakoram Highway (KKH)'), findsOneWidget);
      expect(find.text('Babusar Pass & Kaghan'), findsOneWidget);
      expect(find.text('Makran Coastal Highway'), findsOneWidget);
      expect(find.text('Cholistan Desert Rally Route'), findsOneWidget);
      expect(find.text('Deosai Plains Plateau'), findsOneWidget);

      // 2. Every pack displays "Coming soon"
      final comingSoonPills = find.text('Coming soon');
      expect(comingSoonPills, findsWidgets);
      expect(comingSoonPills.evaluate().length, greaterThanOrEqualTo(6));

      // 3. NO size claims (GB or MB) anywhere on screen
      expect(find.textContaining(' GB'), findsNothing);
      expect(find.textContaining(' MB'), findsNothing);
      expect(find.textContaining('GB Free'), findsNothing);

      // 4. NO fake download / sync / pause buttons or progress
      expect(find.text('Download Pack'), findsNothing);
      expect(find.text('Sync Update'), findsNothing);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Saved'), findsNothing);
      expect(find.textContaining('DOWNLOADING'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // 5. NO unbacked region claims
      expect(find.text('5 Regions Available'), findsNothing);
      expect(find.text('OFFLINE TELEMETRY & TOPO PACKS'), findsNothing);
      expect(find.textContaining('Alps'), findsNothing);
      expect(find.textContaining('Cascades'), findsNothing);

      // 6. Header is honest: Displays ROUTE PACKS (renamed from TELEMETRY HUB) and no Topo V4.8
      expect(find.text('ROUTE PACKS'), findsWidgets);
      expect(find.text('TELEMETRY HUB'), findsNothing);
      expect(find.text('Topo V4.8'), findsNothing);
      expect(find.textContaining('Topo V4.8'), findsNothing);
      expect(find.byIcon(Icons.sync_rounded), findsNothing);

      // 7. Wi-Fi auto-update switch removed (#135)
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('Wi-Fi Auto-Update'), findsNothing);

      // No overflows occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('GPS LIVE pill shows when location service is active with recent fix',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 2400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeLocationService = FakeLocationService(
        serviceEnabled: true,
        hasPermission: true,
      );

      await tester.pumpWidget(noAnimApp(RoutePacksScreen(locationService: fakeLocationService)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('GPS LIVE'), findsOneWidget);
    });

    testWidgets('GPS LIVE pill is hidden when location service is disabled or has no recent fix',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360 * 2, 2400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeLocationService = FakeLocationService(
        serviceEnabled: false,
        nullInitialPosition: true,
      );

      await tester.pumpWidget(noAnimApp(RoutePacksScreen(locationService: fakeLocationService)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('GPS LIVE'), findsNothing);
    });
  });
}
