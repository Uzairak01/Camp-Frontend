import 'package:camp/app/routes.dart';
import 'package:camp/features/dashboard/presentation/widgets/voice_copilot_bar_widget.dart';
import 'package:camp/features/emergency_sos/presentation/screens/emergency_sos_screen.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/sos_hold_button.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/sos_location_card.dart';
import 'package:camp/features/maintenance/domain/maintenance_prediction_engine.dart';
import 'package:camp/features/mechanics/presentation/widgets/search_bar_widget.dart';
import 'package:camp/features/navigation/controllers/navigation_controller.dart';
import 'package:camp/features/navigation/domain/routing_service.dart';
import 'package:camp/features/navigation/presentation/widgets/nav_turn_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/fake_routing_service.dart';

/// Test-only fake navigation controller to supply maneuver steps to NavTurnBanner.
class _FakeNavTurnController extends NavigationController {
  _FakeNavTurnController({
    required this.fakeCurrentStep,
    this.fakeNextStep,
  }) : super(
          locationService: FakeLocationService(),
          routingService: FakeRoutingService(),
        );

  final RouteStep? fakeCurrentStep;
  final RouteStep? fakeNextStep;

  @override
  RouteStep? get currentStep => fakeCurrentStep;

  @override
  RouteStep? get nextStep => fakeNextStep;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch G3 Cleanup & Honesty Verifications', () {
    testWidgets('Mechanics search box has honest hint and no mic button (#131, #132)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBarWidget(
              controller: TextEditingController(),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Hint is honest
      expect(find.text('Search mechanics or area'), findsOneWidget);
      expect(find.textContaining('BMW'), findsNothing);
      expect(find.textContaining('certified'), findsNothing);

      // Mic button removed since it has no real speech-to-text backend (#132)
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('Navigation turn banner has no speaker audio button (#146)',
        (WidgetTester tester) async {
      final fakeController = _FakeNavTurnController(
        fakeCurrentStep: const RouteStep(
          maneuverType: 'turn',
          maneuverModifier: 'right',
          streetName: 'Mall Road',
          distanceMeters: 300,
          durationSeconds: 30,
          location: LatLng(31.5204, 74.3587),
          instruction: 'Turn right onto Mall Road',
        ),
        fakeNextStep: const RouteStep(
          maneuverType: 'continue',
          streetName: 'Canal Road',
          distanceMeters: 1200,
          durationSeconds: 90,
          location: LatLng(31.5250, 74.3600),
          instruction: 'Continue on Canal Road',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavTurnBanner(
              controller: fakeController,
            ),
          ),
        ),
      );

      // Verify turn instructions are displayed
      expect(find.text('300 M'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);

      // Speaker button removed since there is no TTS / audio engine (#146)
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
      expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
    });

    testWidgets('Voice copilot bar has honest hint text (#74)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VoiceCopilotBarWidget(),
          ),
        ),
      );

      // No unbacked tire pressure query
      expect(find.textContaining("how's tire pressure"), findsNothing);
      expect(find.text('Ask about fuel, service, or mechanics...'), findsOneWidget);
    });

    test('Maintenance ComponentPrediction status badge uses Up to date instead of 0% Wear (#136)',
        () {
      const pred = ComponentPrediction(
        id: 'test-brake-pad',
        name: 'Front Brake Pads',
        subtitle: 'Front Caliper',
        wearPercent: 0,
        status: ComponentStatus.ok,
        reason: 'Within safe operating threshold',
        remainingKm: 5000,
        diyGuideTitle: 'Brake Pad Replacement Guide',
        diySteps: ['Loosen caliper bolts', 'Inspect thickness'],
      );

      // Honest badge text instead of misleading "0% Wear"
      expect(pred.statusBadgeText, equals('Up to date'));
    });

    testWidgets('Emergency SOS screen renders SosHoldButton and SosLocationCard (#73)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: EmergencySosScreen(),
        ),
      );
      await tester.pump();

      // Honest hold button and location card are present
      expect(find.byType(SosHoldButton), findsOneWidget);
      expect(find.byType(SosLocationCard), findsOneWidget);

      // No leftover telemetry claims or mock auto crash cards
      expect(find.textContaining('±20m accuracy'), findsNothing);
      expect(find.textContaining('HARDWARE TELEMATICS'), findsNothing);
      expect(find.textContaining('AUTO CRASH DETECTION'), findsNothing);
    });

    test('CampRoutes has no legacy aliases in canonicalRoutes (#76)', () {
      expect(CampRoutes.canonicalRoutes.contains('/mechanics/map'), isFalse);
      expect(CampRoutes.canonicalRoutes.contains('/mechanics/voice-assistant'), isFalse);
    });
  });
}
