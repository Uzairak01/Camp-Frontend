import 'package:camp/features/bike_scan/presentation/screens/add_motorcycle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AddMotorcycleScreen renders cards and components with correct text',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/add-bike',
        routes: {
          '/add-bike': (context) => const AddMotorcycleScreen(),
          '/bike-scan': (context) => const Scaffold(body: Text('Bike Scan Mock')),
          '/garage': (context) => const Scaffold(body: Text('Garage Mock')),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify Header (Brand mark removed per BATCH UI-1)
    expect(find.text('CAMP'), findsNothing);
    expect(find.text('ADD BIKE'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // Verify Title & Subtitle
    expect(find.text('Add a Motorcycle'), findsOneWidget);
    expect(
      find.text('Add a photo or enter details manually.'),
      findsOneWidget,
    );

    // Verify Option 1: Take Bike Photo Card
    expect(find.text('Take Bike Photo'), findsOneWidget);
    expect(
      find.text('Take or choose a photo of your motorcycle'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

    // Verify Option 2: View Garage Card
    expect(find.text('View Garage'), findsOneWidget);
    expect(
      find.text('See your registered bikes'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.garage_rounded), findsOneWidget);

    // Verify Tip Card
    expect(
      find.text('Tip: a clear side-view photo works best.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lightbulb_rounded), findsOneWidget);

    // Verify Removed items are NOT on the screen
    expect(find.textContaining('STEP', findRichText: true), findsNothing);
    expect(find.textContaining('RECOMMENDED', findRichText: true), findsNothing);
    expect(find.textContaining('Recommended', findRichText: true), findsNothing);
    expect(find.text('Upload Photo'), findsNothing);
    expect(find.text('Enter Manually'), findsNothing);
    expect(find.textContaining('VIN', findRichText: true), findsNothing);
    expect(find.textContaining('telemetry', findRichText: true), findsNothing);
    expect(find.textContaining('AI Vision', findRichText: true), findsNothing);
  });

  testWidgets('Tapping Take Bike Photo navigates to the bike scan route',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/add-bike',
        routes: {
          '/add-bike': (context) => const AddMotorcycleScreen(),
          '/bike-scan': (context) => const Scaffold(body: Text('Bike Scan Mock')),
          '/garage': (context) => const Scaffold(body: Text('Garage Mock')),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Tap Take Bike Photo card
    final scanCard = find.text('Take Bike Photo');
    expect(scanCard, findsOneWidget);
    await tester.tap(scanCard);
    await tester.pumpAndSettle();

    // Verify navigation to bike scan route
    expect(find.text('Bike Scan Mock'), findsOneWidget);
  });

  testWidgets('Tapping View Garage navigates to the garage route',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/add-bike',
        routes: {
          '/add-bike': (context) => const AddMotorcycleScreen(),
          '/bike-scan': (context) => const Scaffold(body: Text('Bike Scan Mock')),
          '/garage': (context) => const Scaffold(body: Text('Garage Mock')),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Tap View Garage card
    final garageCard = find.text('View Garage');
    expect(garageCard, findsOneWidget);
    await tester.tap(garageCard);
    await tester.pumpAndSettle();

    // Verify navigation to garage route
    expect(find.text('Garage Mock'), findsOneWidget);
  });
}
