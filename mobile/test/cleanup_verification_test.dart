import 'dart:io';

import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/garage/presentation/screens/bike_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStore.instance.resetForTesting();
    ActiveBikeController.instance.resetForTesting();
  });

  group('Cleanup Tests', () {
    testWidgets('Bike Profile with an id-like value shows no id in subtitle',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const bikeWithObviousId = Bike(
        id: 'SECRET_ID_99999',
        nickname: 'Desert Runner',
        make: 'KTM',
        modelName: '890 Adventure R',
        modelYear: 2024,
        odometerKm: 12000,
      );

      ActiveBikeController.instance.addBike(bikeWithObviousId, setActive: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: BikeProfileScreen(bike: bikeWithObviousId),
        ),
      );
      await tester.pumpAndSettle();

      // Subtitle should be "<year> • <make>" only
      expect(find.text('2024 • KTM'), findsOneWidget);
      // The id SECRET_ID_99999 should NEVER be visible anywhere
      expect(find.textContaining('SECRET_ID_99999'), findsNothing);
    });

    test('Fuel level round-trips through persistence and old data loads as null',
        () async {
      final store = LocalStore();
      store.resetForTesting();

      // 1. Old data without fuelLevelPercent loads as null
      final legacyBikeJson = {
        'id': 'legacy-bike-1',
        'name': 'Legacy Cruiser',
        'make': 'Yamaha',
        'modelName': 'Bolt',
        'modelYear': 2018,
      };

      final legacyBike = Bike.fromJson(legacyBikeJson);
      expect(legacyBike.fuelLevelPercent, isNull);

      // 2. Bike with fuelLevelPercent serializes and deserializes correctly
      final bikeWithFuel = legacyBike.copyWith(fuelLevelPercent: 68);
      expect(bikeWithFuel.fuelLevelPercent, 68);

      final json = bikeWithFuel.toJson();
      expect(json['fuelLevelPercent'], 68);

      final reloadedBike = Bike.fromJson(json);
      expect(reloadedBike.fuelLevelPercent, 68);

      // 3. Round-trip through ActiveBikeController and LocalStore
      ActiveBikeController.instance.addBike(bikeWithFuel, setActive: true);
      await ActiveBikeController.instance.save(store);

      // Reset controller and reload from store
      ActiveBikeController.instance.resetForTesting();
      expect(ActiveBikeController.instance.bikes, isEmpty);

      await store.markFirstRunCompleted();
      await ActiveBikeController.instance.load(store);

      expect(ActiveBikeController.instance.bikes.length, 1);
      final loaded = ActiveBikeController.instance.bikes.first;
      expect(loaded.id, 'legacy-bike-1');
      expect(loaded.fuelLevelPercent, 68);
    });

    test('No string "telemetry" remains in user-facing UI text across lib/',
        () {
      // Scan lib/ directory (excluding navigation, settings, mechanics per instructions)
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final skippedFolders = ['navigation', 'settings', 'mechanics'];
      final userVisibleTelemetryViolations = <String>[];

      // Regex to capture user-visible Text strings containing 'telemetry'
      final userFacingPattern = RegExp(
        r'''(?:Text\s*\(\s*['"][^'"]*telemetry[^'"]*['"]|content:\s*Text\s*\(\s*['"][^'"]*telemetry|title:\s*Text\s*\(\s*['"][^'"]*telemetry|subtitle:\s*['"][^'"]*telemetry|message:\s*['"][^'"]*telemetry)''',
        caseSensitive: false,
      );

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalizedPath = entity.path.replaceAll(r'\', '/');
          final isSkipped = skippedFolders
              .any((folder) => normalizedPath.contains('/$folder/'));
          if (isSkipped) continue;

          final content = entity.readAsStringSync();
          final matches = userFacingPattern.allMatches(content);
          for (final m in matches) {
            userVisibleTelemetryViolations
                .add('${entity.path}: "${m.group(0)}"');
          }
        }
      }

      expect(
        userVisibleTelemetryViolations,
        isEmpty,
        reason:
            'Found user-visible strings with "telemetry":\n${userVisibleTelemetryViolations.join('\n')}',
      );
    });
  });
}
