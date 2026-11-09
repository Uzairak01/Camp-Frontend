import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/mechanics/controllers/mechanic_controller.dart';
import 'package:camp/features/mechanics/domain/mechanic_model.dart';
import 'package:camp/features/voice_copilot/controllers/voice_chat_controller.dart';
import 'package:camp/features/voice_copilot/presentation/screens/voice_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-only subclass under test/ providing isolated state for widget tests.
class _TestVoiceChatController extends VoiceChatController {}

void main() {
  setUp(() {
    ActiveBikeController.instance.reset();
    MechanicController.instance.resetForTesting();
    VoiceChatController.instance = _TestVoiceChatController();
  });

  Widget buildTestableWidget() {
    return const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: VoiceAssistantScreen(),
      ),
    );
  }

  group('VoiceAssistantScreen - BATCH G2-A Redesign', () {
    testWidgets('Header displays menu button and close button, with no legacy chips',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Menu button (left) and close button (right)
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify removed header widgets are absent
      expect(find.text('COPILOT'), findsNothing);
      expect(find.textContaining('MESH'), findsNothing);
      expect(find.byIcon(Icons.keyboard_alt_outlined), findsNothing);
    });

    testWidgets('Idle body shows heading, subtext, and the 4 required chips',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      expect(find.text('How can I help on this ride?'), findsOneWidget);
      expect(
        find.text('Ask about your bike, fuel, service or saved mechanics.'),
        findsOneWidget,
      );

      // Four tappable chips
      expect(find.text('How much fuel do I have left?'), findsOneWidget);
      expect(find.text('What service is due next?'), findsOneWidget);
      expect(find.text('Find my nearest mechanic'), findsOneWidget);
      expect(find.text('Log a refill'), findsOneWidget);
    });

    testWidgets('Tapping a chip adds a user bubble and assistant answer',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Tap the fuel chip
      final chipFinder = find.text('How much fuel do I have left?');
      await tester.tap(chipFinder);
      await tester.pump();

      // User bubble exists
      expect(find.text('How much fuel do I have left?'), findsOneWidget);

      // Assistant response exists (with no bike in garage)
      expect(
        find.text('No active bike selected in your garage.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Unanswerable typed question returns "I can\'t answer that yet."',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Type an unanswerable question
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, 'What is the weather in Tokyo?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      // User bubble is present
      expect(find.text('What is Tokyo weather?'), findsNothing);
      expect(find.text('What is the weather in Tokyo?'), findsOneWidget);

      // Assistant answers strictly from real app data fallback
      expect(find.text("I can't answer that yet."), findsOneWidget);
    });

    testWidgets('All removed widgets and legacy strings are completely absent',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Transcript buffer card
      expect(find.text('TRANSCRIPT BUFFER'), findsNothing);
      expect(find.textContaining('LIVE TRANSCRIPT'), findsNothing);

      // Intercom Ready
      expect(find.text('Intercom Ready'), findsNothing);
      expect(find.textContaining('Intercom'), findsNothing);

      // Speed / Alt footer
      expect(find.textContaining('Speed:'), findsNothing);
      expect(find.textContaining('Alt:'), findsNothing);
      expect(find.text('2,410m'), findsNothing);
      expect(find.text('0 km/h'), findsNothing);

      // Fake quick commands
      expect(find.textContaining('Babusar Pass'), findsNothing);
      expect(find.textContaining('Hunza Valley'), findsNothing);
      expect(find.textContaining('tire pressure'), findsNothing);
      expect(find.textContaining('high-octane fuel'), findsNothing);

      // Helmet mic & helmet tips
      expect(find.textContaining('Helmet mic input active'), findsNothing);
      expect(find.textContaining('Hey CAMP'), findsNothing);
    });

    testWidgets('Listening state shows large centered mic and stop button in bottom bar',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Find mic button inside bottom bar
      final micFinder = find.byIcon(Icons.mic_rounded);
      expect(micFinder, findsOneWidget);

      // Tap mic to enter listening state
      await tester.tap(micFinder);
      await tester.pump();

      // Listening state body is shown
      expect(find.text('Listening…'), findsOneWidget);
      expect(find.text('Say your command or ask a question'), findsOneWidget);

      // Bottom bar's mic button became a stop button
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      // Tap stop button to exit listening state
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();

      expect(find.text('Listening…'), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('Real app data responds with real mechanic information',
        (tester) async {
      // Add a real mechanic to controller
      const testMechanic = Mechanic(
        id: 'mech-1',
        name: 'Rashid Moto Works',
        durationOrLocation: 'F-10 Markaz, Islamabad',
      );
      MechanicController.instance.addMechanic(testMechanic);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Tap nearest mechanic chip
      await tester.tap(find.text('Find my nearest mechanic'));
      await tester.pump();

      expect(
        find.text('Nearest saved mechanic is Rashid Moto Works (F-10 Markaz, Islamabad).'),
        findsOneWidget,
      );
    });

    testWidgets('Real app data responds with real fuel status for active bike',
        (tester) async {
      const bike = Bike(
        id: 'bike-test-1',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2023,
        odometerKm: 12500,
        fuelTankCapacityLiters: 16.0,
        fuelRemainingLiters: 12.0,
        fuelAverageKmPerLiter: 22.0,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Tap fuel chip
      await tester.tap(find.text('How much fuel do I have left?'));
      await tester.pump();

      expect(
        find.text(
          'You have 12.0 L of fuel remaining (~75%). Estimated range is 264 km.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Log a refill returns accurate instruction',
        (tester) async {
      const bike = Bike(
        id: 'bike-test-2',
        make: 'Honda',
        modelName: 'CB500X',
        modelYear: 2022,
        odometerKm: 8000,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      await tester.tap(find.text('Log a refill'));
      await tester.pump();

      expect(
        find.text(
          'To log a refill for CB500X, tap "I Refilled" on the Home dashboard or add an expense under Finances.',
        ),
        findsOneWidget,
      );
    });
  });
}

