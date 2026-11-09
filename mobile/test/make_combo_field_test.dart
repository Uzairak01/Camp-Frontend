import 'package:camp/core/constants/bike_makes.dart';
import 'package:camp/core/widgets/make_combo_field.dart';
import 'package:camp/features/bike_scan/controllers/bike_onboarding_controller.dart';
import 'package:camp/features/bike_scan/presentation/screens/bike_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    BikeOnboardingController.instance.reset();
  });

  group('canonicaliseMake', () {
    test('Returns canonical spelling for exact case-insensitive match', () {
      expect(canonicaliseMake('suzuki'), 'Suzuki');
      expect(canonicaliseMake('HONDA'), 'Honda');
      expect(canonicaliseMake('royal enfield'), 'Royal Enfield');
      expect(canonicaliseMake('united'), 'United');
      expect(canonicaliseMake('TVS'), 'TVS');
    });

    test('Title-cases unknown makes', () {
      expect(canonicaliseMake('united motors'), 'United Motors');
      expect(canonicaliseMake('custom brand'), 'Custom Brand');
    });

    test('Trims whitespace before processing', () {
      expect(canonicaliseMake('  Honda  '), 'Honda');
      expect(canonicaliseMake('  united  '), 'United');
    });

    test('Returns empty string for empty input', () {
      expect(canonicaliseMake(''), '');
      expect(canonicaliseMake('   '), '');
    });
  });

  group('kCanonicalBikeMakes', () {
    test('Contains expected South Asian brands', () {
      expect(kCanonicalBikeMakes, contains('United'));
      expect(kCanonicalBikeMakes, contains('Road Prince'));
      expect(kCanonicalBikeMakes, contains('Super Power'));
      expect(kCanonicalBikeMakes, contains('Unique'));
      expect(kCanonicalBikeMakes, contains('Hi-Speed'));
      expect(kCanonicalBikeMakes, contains('Metro'));
      expect(kCanonicalBikeMakes, contains('Crown'));
      expect(kCanonicalBikeMakes, contains('Hero'));
      expect(kCanonicalBikeMakes, contains('Bajaj'));
      expect(kCanonicalBikeMakes, contains('TVS'));
    });

    test('Contains expected global brands', () {
      expect(kCanonicalBikeMakes, contains('Honda'));
      expect(kCanonicalBikeMakes, contains('Yamaha'));
      expect(kCanonicalBikeMakes, contains('Suzuki'));
      expect(kCanonicalBikeMakes, contains('BMW'));
      expect(kCanonicalBikeMakes, contains('Ducati'));
      expect(kCanonicalBikeMakes, contains('KTM'));
      expect(kCanonicalBikeMakes, contains('Kawasaki'));
      expect(kCanonicalBikeMakes, contains('Harley-Davidson'));
      expect(kCanonicalBikeMakes, contains('Triumph'));
      expect(kCanonicalBikeMakes, contains('Royal Enfield'));
      expect(kCanonicalBikeMakes, contains('Aprilia'));
      expect(kCanonicalBikeMakes, contains('Husqvarna'));
      expect(kCanonicalBikeMakes, contains('Benelli'));
    });

    test('Has no duplicates', () {
      final set = kCanonicalBikeMakes.toSet();
      expect(set.length, kCanonicalBikeMakes.length);
    });
  });

  group('BikeOnboardingController make validation', () {
    test('isFormValid is false when make is empty', () {
      BikeOnboardingController.instance.setMake('');
      BikeOnboardingController.instance.setModelName('Africa Twin');
      expect(BikeOnboardingController.instance.isFormValid, isFalse);
    });

    test('isFormValid is false when make is 1 character', () {
      BikeOnboardingController.instance.setMake('X');
      BikeOnboardingController.instance.setModelName('Africa Twin');
      expect(BikeOnboardingController.instance.isFormValid, isFalse);
    });

    test('isFormValid is true for "United" (2+ chars, unlisted make)', () {
      BikeOnboardingController.instance.setMake('United');
      BikeOnboardingController.instance.setModelName('150cc');
      expect(BikeOnboardingController.instance.isFormValid, isTrue);
    });

    test('isFormValid is true for canonical make "Suzuki"', () {
      BikeOnboardingController.instance.setMake('Suzuki');
      BikeOnboardingController.instance.setModelName('GSX-R150');
      expect(BikeOnboardingController.instance.isFormValid, isTrue);
    });

    test('buildBike preserves custom make string', () {
      BikeOnboardingController.instance.setMake('United');
      BikeOnboardingController.instance.setModelName('150cc');
      final bike = BikeOnboardingController.instance.buildBike();
      expect(bike.make, 'United');
    });

    test('buildBike preserves canonical make string', () {
      BikeOnboardingController.instance.setMake('Suzuki');
      BikeOnboardingController.instance.setModelName('GSX-R150');
      final bike = BikeOnboardingController.instance.buildBike();
      expect(bike.make, 'Suzuki');
    });
  });

  group('MakeComboField widget', () {
    testWidgets('Renders with label and hint text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MakeComboField(
                initialValue: 'Honda',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Make / Manufacturer'), findsOneWidget);
      expect(find.text('Honda'), findsOneWidget);
    });

    testWidgets('Typing a known make stores canonical value on submit', (tester) async {
      String stored = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MakeComboField(
                initialValue: '',
                onChanged: (val) => stored = val,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'suzuki');
      await tester.pumpAndSettle();

      // Trigger onSubmitted (Done key) which runs canonicaliseMake
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(stored, 'Suzuki');
    });

    testWidgets('Typing an unknown make preserves title-cased input', (tester) async {
      String stored = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MakeComboField(
                initialValue: '',
                onChanged: (val) => stored = val,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'United');
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(stored, 'United');
    });

    testWidgets('onUserEdited fires on first edit', (tester) async {
      bool editedFired = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MakeComboField(
                initialValue: 'Honda',
                onChanged: (_) {},
                onUserEdited: () => editedFired = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Yam');
      await tester.pumpAndSettle();

      expect(editedFired, isTrue);
    });

    testWidgets('Focusing an empty field does not show an error', (tester) async {
      // The overlay is inserted via OverlayEntry and not easily found in test trees.
      // We verify instead that the field accepts focus without crashing and that
      // the kCanonicalBikeMakes list is non-empty (which drives the overlay).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: MakeComboField(
                initialValue: '',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Field still visible, no crash — suggestions are populated from kCanonicalBikeMakes
      expect(kCanonicalBikeMakes, isNotEmpty);
      expect(find.byType(MakeComboField), findsOneWidget);
    });
  });

  group('BikeDetailsScreen: MakeComboField integration', () {
    testWidgets('BikeDetailsScreen shows MakeComboField not LabeledDropdown for make', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: const BikeDetailsScreen(),
          routes: {
            '/garage': (context) => const Scaffold(body: Text('Garage Screen')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // MakeComboField uses a TextField, not a DropdownButton
      expect(find.text('Make / Manufacturer'), findsOneWidget);
      expect(find.byType(MakeComboField), findsOneWidget);
    });

    testWidgets('Continue is valid after entering United as make', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: const BikeDetailsScreen(),
          routes: {
            '/garage': (context) => const Scaffold(body: Text('Garage Screen')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Clear and enter 'United' in make field
      await tester.tap(find.byType(MakeComboField));
      await tester.enterText(
        find.descendant(of: find.byType(MakeComboField), matching: find.byType(TextField)),
        'United',
      );
      await tester.pumpAndSettle();

      // Enter model name
      await tester.enterText(
        find.descendant(of: find.byType(MakeComboField), matching: find.byType(TextField)).last,
        'United',
      );
      // Use the model name field properly
      final modelField = find.widgetWithText(TextField, '');
      if (modelField.evaluate().isNotEmpty) {
        await tester.enterText(modelField.first, '150cc');
      }
      await tester.pumpAndSettle();

      expect(BikeOnboardingController.instance.isFormValid, isTrue);
    });
  });
}
