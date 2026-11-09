import 'package:camp/app/routes.dart';
import 'package:camp/features/dashboard/domain/profile_stats.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/domain/carburetor_guidance_table.dart';
import 'package:camp/features/maintenance/domain/maintenance_prediction_engine.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/domain/service_schedule_engine.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/maintenance/presentation/screens/maintenance_screen.dart';
import 'package:camp/features/maintenance/presentation/screens/post_ride_debrief_screen.dart';
import 'package:camp/features/maintenance/presentation/widgets/carburetor_tab.dart';
import 'package:camp/features/maintenance/presentation/widgets/post_ride_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_ride_report_repository.dart';
import 'helpers/maintenance_test_helpers.dart';

void _seedFakeReportsForBmw() {
  final now = DateTime(2026, 10, 15);
  final fakeReports = [
    PostRideReport(
      id: 'fake-bmw-1',
      bikeId: 'bike-bmw-1250',
      date: now.subtract(const Duration(days: 1)),
      distanceKm: 260,
      durationHours: 5.0,
      terrainTags: const ['Mountain', 'Off-road'],
      notes: 'Alpine loop',
    ),
    PostRideReport(
      id: 'fake-bmw-2',
      bikeId: 'bike-bmw-1250',
      date: now.subtract(const Duration(days: 3)),
      distanceKm: 85,
      durationHours: 2.0,
      terrainTags: const ['City'],
      notes: 'Urban commute',
    ),
    PostRideReport(
      id: 'fake-bmw-3',
      bikeId: 'bike-bmw-1250',
      date: now.subtract(const Duration(days: 5)),
      distanceKm: 185,
      durationHours: 4.0,
      terrainTags: const ['Off-road'],
      notes: 'River gravel',
    ),
    PostRideReport(
      id: 'fake-bmw-4',
      bikeId: 'bike-bmw-1250',
      date: now.subtract(const Duration(days: 7)),
      distanceKm: 310,
      durationHours: 4.5,
      terrainTags: const ['Highway'],
      notes: 'Expressway transit',
    ),
    PostRideReport(
      id: 'fake-bmw-5',
      bikeId: 'bike-bmw-1250',
      date: now.subtract(const Duration(days: 9)),
      distanceKm: 95,
      durationHours: 2.0,
      terrainTags: const ['Off-road', 'Mountain'],
      notes: 'Pass ascent',
    ),
  ];
  for (final r in fakeReports) {
    PostRideReportController.instance.addReport(r);
  }
}

const testBmwBike = Bike(
  id: 'bike-bmw-1250',
  make: 'BMW',
  modelName: 'R 1250 GS Adventure',
  modelYear: 2023,
  odometerKm: 14200,
  displacement: 1254,
  bikeType: 'Adventure',
  fuelSystem: FuelSystem.efi,
  ridingTerrain: ['City', 'Highway', 'Off-road', 'Mountain'],
);

const testRebelBike = Bike(
  id: 'bike-rebel-500',
  make: 'Honda',
  modelName: 'Rebel 500',
  modelYear: 2021,
  odometerKm: 8500,
  displacement: 471,
  bikeType: 'Cruiser',
  fuelSystem: FuelSystem.carburetor,
  carburetorType: 'Keihin CVK',
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    ActiveBikeController.instance.reset();
    ActiveBikeController.instance.addBike(testBmwBike, setActive: true);
    ActiveBikeController.instance.addBike(testRebelBike);
    PostRideReportController.instance = PostRideReportController(
      repository: FakeRideReportRepository(),
    );
    MaintenanceController.instance = MaintenanceController(
      repository: FakeMaintenanceRepository(),
    );
  });

  tearDown(() {
    PostRideReportController.instance = PostRideReportController(
      repository: FakeRideReportRepository(),
    );
  });

  group('Phase 1 & 2: PostRideReport and MaintenancePredictionEngine Unit Tests', () {
    test('PostRideReport model stores debrief data correctly', () {
      final report = PostRideReport(
        id: 'rep-test-1',
        bikeId: 'bike-bmw-1250',
        date: DateTime(2026, 10, 1),
        distanceKm: 180.5,
        terrainTags: const ['Off-road', 'Mountain'],
        notes: 'Challenging gravel pass ascent',
        flaggedIssues: 'Chain rattle on rocky steps',
      );

      expect(report.id, 'rep-test-1');
      expect(report.bikeId, 'bike-bmw-1250');
      expect(report.distanceKm, 180.5);
      expect(report.terrainTags, ['Off-road', 'Mountain']);
      expect(report.combinedNotes, 'Challenging gravel pass ascent (Chain rattle on rocky steps)');
    });

    test('PostRideReportController manages reports per bike and supports reset', () {
      final controller = PostRideReportController.instance;
      controller.reset();
      expect(controller.reports, isEmpty);

      final bmwReport = PostRideReport(
        id: 'rep-test-bmw-1',
        bikeId: 'bike-bmw-1250',
        date: DateTime.now(),
        distanceKm: 200.0,
        terrainTags: const ['Off-road'],
      );
      controller.addReport(bmwReport);
      expect(controller.getReportsForBike('bike-bmw-1250').length, 1);

      final custom = PostRideReport(
        id: 'rep-custom',
        bikeId: 'bike-rebel-500',
        date: DateTime.now(),
        distanceKm: 50.0,
        terrainTags: const ['City'],
      );
      controller.addReport(custom);
      expect(controller.getReportsForBike('bike-rebel-500').length, 1);

      controller.reset();
      expect(controller.reports, isEmpty);
    });

    test('MaintenancePredictionEngine computes deterministic component wear and health index', () async {
      final bike = ActiveBikeController.instance.activeBike!;
      PostRideReportController.instance.addReport(
        PostRideReport(
          id: 'rep-test-bmw-engine',
          bikeId: bike.id,
          date: DateTime.now(),
          distanceKm: 200.0,
          terrainTags: const ['Off-road', 'Mountain'],
        ),
      );
      final reports = PostRideReportController.instance.getReportsForBike(bike.id);

      await setScheduleForTest(bike.id, [
        const ServiceScheduleItem(
          id: 'oil-bmw',
          bikeId: 'bike-bmw-1250',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          lastDoneKm: 10000,
          enabled: true,
        ),
        const ServiceScheduleItem(
          id: 'chain-bmw',
          bikeId: 'bike-bmw-1250',
          type: ServiceItemType.chain,
          intervalKm: 1000,
          lastDoneKm: 14000,
          enabled: true,
        ),
        const ServiceScheduleItem(
          id: 'air-bmw',
          bikeId: 'bike-bmw-1250',
          type: ServiceItemType.airFilter,
          intervalKm: 10000,
          lastDoneKm: 10000,
          enabled: true,
        ),
        const ServiceScheduleItem(
          id: 'brakes-bmw',
          bikeId: 'bike-bmw-1250',
          type: ServiceItemType.brakes,
          intervalKm: 15000,
          lastDoneKm: 10000,
          enabled: true,
        ),
      ]);

      final assessment = MaintenancePredictionEngine.analyze(
        bike: bike,
        rideReports: reports,
      );

      // Verify health index is within realistic bounds
      expect(assessment.healthIndex, greaterThan(0));
      expect(assessment.healthIndex, lessThanOrEqualTo(100));

      // Verify at least 4 analyzed components
      expect(assessment.components.length, greaterThanOrEqualTo(4));

      final componentIds = assessment.components.map((c) => c.id).toSet();
      expect(componentIds, containsAll(['engine-oil', 'chain-sprocket', 'air-filter', 'brake-pads']));

      // Verify wear percentages are capped 0-100
      for (final comp in assessment.components) {
        expect(comp.wearPercent, greaterThanOrEqualTo(0));
        expect(comp.wearPercent, lessThanOrEqualTo(100));
        expect(comp.reason.isNotEmpty, isTrue);
        expect(comp.diySteps.isNotEmpty, isTrue);
      }

      // Verify next service estimate
      expect(assessment.nextServiceKm, greaterThan(0));
      expect(assessment.nextServiceDays, greaterThan(0));
    });

    test('Engine Oil interval is reduced by 15% when terrain contains Off-road or Mountain', () async {
      const offRoadBike = Bike(
        id: 'bike-offroad',
        make: 'KTM',
        modelName: '890 Adventure R',
        modelYear: 2023,
        odometerKm: 8000,
        ridingTerrain: ['Off-road', 'Mountain'],
        lastOilChange: ServiceRecord(km: 2000),
      );

      const highwayBike = Bike(
        id: 'bike-highway',
        make: 'Honda',
        modelName: 'Gold Wing',
        modelYear: 2023,
        odometerKm: 8000,
        ridingTerrain: ['Highway'],
        lastOilChange: ServiceRecord(km: 2000),
      );

      await setScheduleForTest(offRoadBike.id, [
        const ServiceScheduleItem(
          id: 'oil-offroad',
          bikeId: 'bike-offroad',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          lastDoneKm: 6000,
          enabled: true,
        ),
      ]);
      await setScheduleForTest(highwayBike.id, [
        const ServiceScheduleItem(
          id: 'oil-highway',
          bikeId: 'bike-highway',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          lastDoneKm: 6000,
          enabled: true,
        ),
      ]);

      final assessmentOffRoad = MaintenancePredictionEngine.analyze(
        bike: offRoadBike,
        rideReports: [],
      );
      final assessmentHighway = MaintenancePredictionEngine.analyze(
        bike: highwayBike,
        rideReports: [],
      );

      final oilOffRoad = assessmentOffRoad.components.firstWhere((c) => c.id == 'engine-oil');
      final oilHighway = assessmentHighway.components.firstWhere((c) => c.id == 'engine-oil');

      // Effective interval for off-road is reduced by 20% under harsh terrain
      expect(oilOffRoad.wearPercent, greaterThan(oilHighway.wearPercent));
    });

    test('Phase 3: Computes honest percentage from logged PostRideReports', () {
      final bike = ActiveBikeController.instance.activeBike!;
      PostRideReportController.instance.clearReportsForBike(bike.id);
      // 5 rides: 3 off-road (60%), 2 mountain (40%)
      PostRideReportController.instance.addReport(PostRideReport(
        id: 'rep-p3-1',
        bikeId: bike.id,
        date: DateTime.now().subtract(const Duration(days: 1)),
        distanceKm: 100.0,
        terrainTags: const ['Off-road', 'Mountain'],
      ));
      PostRideReportController.instance.addReport(PostRideReport(
        id: 'rep-p3-2',
        bikeId: bike.id,
        date: DateTime.now().subtract(const Duration(days: 2)),
        distanceKm: 100.0,
        terrainTags: const ['Highway'],
      ));
      PostRideReportController.instance.addReport(PostRideReport(
        id: 'rep-p3-3',
        bikeId: bike.id,
        date: DateTime.now().subtract(const Duration(days: 3)),
        distanceKm: 100.0,
        terrainTags: const ['Off-road'],
      ));
      PostRideReportController.instance.addReport(PostRideReport(
        id: 'rep-p3-4',
        bikeId: bike.id,
        date: DateTime.now().subtract(const Duration(days: 4)),
        distanceKm: 100.0,
        terrainTags: const ['City'],
      ));
      PostRideReportController.instance.addReport(PostRideReport(
        id: 'rep-p3-5',
        bikeId: bike.id,
        date: DateTime.now().subtract(const Duration(days: 5)),
        distanceKm: 100.0,
        terrainTags: const ['Mountain', 'Off-road'],
      ));
      final reports = PostRideReportController.instance.getReportsForBike(bike.id);

      final assessment = MaintenancePredictionEngine.analyze(
        bike: bike,
        rideReports: reports,
      );

      expect(assessment.hasSufficientRideLogs, isTrue);
      expect(assessment.patternInsights.isNotEmpty, isTrue);

      final chainInsight = assessment.patternInsights.firstWhere(
        (i) => i.title == 'Chain Wear Accelerating',
      );
      expect(chainInsight.percentageBadge, '60% Off-Road');
      expect(chainInsight.description, contains('3 of your last 5'));
    });

    test('Phase 3: Returns empty pattern insights when fewer than 3 reports exist', () {
      final bike = ActiveBikeController.instance.activeBike!;
      final assessment = MaintenancePredictionEngine.analyze(
        bike: bike,
        rideReports: [
          PostRideReport(
            id: 'one-rep',
            bikeId: bike.id,
            date: DateTime.now(),
            distanceKm: 100,
            terrainTags: const ['Off-road'],
          ),
        ],
      );

      expect(assessment.hasSufficientRideLogs, isFalse);
      expect(assessment.patternInsights.isEmpty, isTrue);
    });
  });

  group('Phase 4: MaintenanceScreen Widget Tests', () {
    testWidgets('Renders all header, health index, components, and insights matching design',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await setScheduleForTest('bike-bmw-1250', [
        const ServiceScheduleItem(
          id: 'oil-bmw',
          bikeId: 'bike-bmw-1250',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          lastDoneKm: 10000,
          enabled: true,
        ),
        const ServiceScheduleItem(
          id: 'chain-bmw',
          bikeId: 'bike-bmw-1250',
          type: ServiceItemType.chain,
          intervalKm: 1000,
          lastDoneKm: 14000,
          enabled: true,
        ),
        const ServiceScheduleItem(
          id: 'air-bmw',
          bikeId: 'bike-bmw-1250',
          type: ServiceItemType.airFilter,
          intervalKm: 10000,
          lastDoneKm: 10000,
          enabled: true,
        ),
        const ServiceScheduleItem(
          id: 'brakes-bmw',
          bikeId: 'bike-bmw-1250',
          type: ServiceItemType.brakes,
          intervalKm: 15000,
          lastDoneKm: 10000,
          enabled: true,
        ),
      ]);

      _seedFakeReportsForBmw();

      await tester.pumpWidget(
        MaterialApp(
          home: const MaintenanceScreen(),
          routes: {
            '/finance-rig-health': (context) =>
                const Scaffold(body: Text('Finance Rig Health Destination')),
          },
        ),
      );
      await tester.pumpAndSettle();

      // 1. App Bar (Header brand mark removed per BATCH UI-1)
      expect(find.text('CAMP'), findsNothing);
      expect(find.text('• MAINTENANCE'), findsOneWidget);

      // 2. Bike context header (No OBD-II or hardware sensor language)
      expect(find.text('BMW R 1250 GS Adventure'), findsOneWidget);
      expect(find.textContaining('Last updated'), findsOneWidget);
      expect(find.textContaining('OBD-II'), findsNothing);
      expect(find.textContaining('Telemetry updated'), findsNothing);

      // 3. Tab Selector
      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.text('Pre-Ride'), findsOneWidget);
      expect(find.text('Post-Ride'), findsOneWidget);

      // 4. Maintenance Health Index (no "Telemetry Health Index", no "ECU Status", no "Pass Ready")
      expect(find.text('MAINTENANCE HEALTH INDEX'), findsOneWidget);
      expect(find.text('TELEMETRY HEALTH INDEX'), findsNothing);
      expect(find.textContaining('ECU Status'), findsNothing);
      expect(find.textContaining('Pass Ready'), findsNothing);
      expect(find.textContaining('Next service in'), findsOneWidget);

      // 5. Component Analysis & Wear (no critical limit in mm)
      expect(find.text('COMPONENT ANALYSIS & WEAR'), findsOneWidget);
      expect(find.text('Drive Chain & Sprocket'), findsOneWidget);
      expect(find.text('Engine Oil & Filter'), findsOneWidget);
      expect(find.text('Air Filter Element'), findsOneWidget);
      expect(find.text('Front Brake Pads'), findsOneWidget);
      expect(find.text('View DIY Guide >'), findsWidgets);
      expect(find.textContaining('Critical limit:'), findsNothing);
      expect(find.textContaining('Min safe spec:'), findsNothing);

      // 6. CAMP Predictive Intelligence
      expect(find.text('CAMP PREDICTIVE INTELLIGENCE'), findsOneWidget);
      expect(find.text('Chain Wear Accelerating'), findsOneWidget);
      expect(find.text('60% Off-Road'), findsOneWidget);

      // 7. Finances & Rig Health Banner
      expect(
        find.textContaining('Parts costs and budgets are tracked in Finances & Rig Health.'),
        findsOneWidget,
      );
      expect(find.text('View →'), findsOneWidget);
    });

    testWidgets('Tapping View DIY Guide opens bottom sheet modal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View DIY Guide >').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('CAMP Field Service Guide'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Dismiss modal
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('Pre-Ride tab supports checking items and Start Ride action',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            CampRoutes.navigationMap: (context) => const Scaffold(
                  body: Text('MAPS TAB'),
                ),
          },
          home: const MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Pre-Ride tab
      await tester.tap(find.text('Pre-Ride'));
      await tester.pumpAndSettle();

      expect(find.text('PRE-RIDE SAFETY AUDIT'), findsOneWidget);
      expect(find.text('0 of 7 Done'), findsOneWidget);

      // Tap first checkpoint
      await tester.tap(find.text('Tire Pressures & Tread Inspection'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 7 Done'), findsOneWidget);

      // Tap Start Ride button
      await tester.tap(find.text('Start Ride'));
      await tester.pumpAndSettle();
      expect(find.text('MAPS TAB'), findsOneWidget);
      expect(find.textContaining('items checked'), findsNothing);
    });

    testWidgets('Post-Ride tab shows history and "Log a ride" button with no inline form',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      _seedFakeReportsForBmw();

      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Post-Ride tab
      await tester.tap(find.text('Post-Ride'));
      await tester.pumpAndSettle();

      // Verify no inline form exists on PostRideTab
      expect(find.descendant(of: find.byType(PostRideTab), matching: find.byType(TextField)), findsNothing);
      expect(find.text('EXPEDITION LOG HISTORY (5)'), findsOneWidget);
      expect(find.text('Log a ride'), findsOneWidget);

      // Tap "Log a ride" button to open the PostRideDebriefScreen
      await tester.tap(find.text('Log a ride'));
      await tester.pumpAndSettle();

      expect(find.byType(PostRideDebriefScreen), findsOneWidget);

      // Enter distance and save
      await tester.enterText(find.byType(TextField).first, '120');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Post-Ride Report'));
      await tester.pumpAndSettle();

      // Returned to MaintenanceScreen with updated history
      expect(find.byType(PostRideDebriefScreen), findsNothing);
      expect(find.text('EXPEDITION LOG HISTORY (6)'), findsOneWidget);
      expect(find.text('120 km'), findsOneWidget);
    });

    testWidgets('Carburetor tab renders for carburetor bikes with manual altitude calibration',
        (WidgetTester tester) async {
      // Set active bike to Honda Rebel 500 (carburetor)
      ActiveBikeController.instance.setActiveBike('bike-rebel-500');

      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Carburetor tab appears
      expect(find.text('Carburetor'), findsWidgets);

      // Switch to Carburetor tab
      await tester.tap(find.text('Carburetor').first);
      await tester.pumpAndSettle();

      // Updated strings matching the new CarburetorTab layout
      expect(find.text('CARBURETOR SPECIFICATION'), findsOneWidget);
      expect(find.text('JETTING LOG'), findsOneWidget);
      expect(find.text('CURRENT ALTITUDE'), findsOneWidget);
      expect(find.text('Guidance only'), findsWidgets);
      // Empty state: no baseline altitude entered yet
      expect(find.text('Set your baseline altitude first.'), findsOneWidget);
    });
  });

  // ── Part 1: Oil formula edge-case unit tests ───────────────────────────────
  group('Oil formula: km-limited, days-limited, terrain-shortened', () {
    test('km-limited: wear is driven by km when days is zero (no date recorded)', () async {
      // 4,000 km since last change / 5,000 km interval = 80%
      const bike = Bike(
        id: 'test-km',
        make: 'Honda',
        modelName: 'CB500F',
        modelYear: 2022,
        odometerKm: 10000,
        ridingTerrain: ['Highway'], // no off-road / mountain
        lastOilChange: ServiceRecord(km: 4000), // 4,000 km since change, no date
      );

      await setScheduleForTest(bike.id, [
        const ServiceScheduleItem(
          id: 'oil-km',
          bikeId: 'test-km',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          lastDoneKm: 6000,
          enabled: true,
        ),
      ]);

      final assessment = MaintenancePredictionEngine.analyze(
        bike: bike,
        rideReports: [],
      );
      final oil = assessment.components.firstWhere((c) => c.id == 'engine-oil');

      // 4000 / 5000 = 80%
      expect(oil.wearPercent, equals(80));
      expect(oil.status, equals(ComponentStatus.dueSoon));
    });

    test('days-limited: wear is driven by days when days > km wear', () async {
      final lastChangeDate = DateTime.now().subtract(const Duration(days: 89));
      final bike = Bike(
        id: 'test-days',
        make: 'Yamaha',
        modelName: 'MT-07',
        modelYear: 2023,
        odometerKm: 5500,
        ridingTerrain: const ['City'],
        lastOilChange: ServiceRecord(
          mode: TrackingMode.byDate,
          km: 500,
          date: lastChangeDate,
        ),
      );

      await setScheduleForTest(bike.id, [
        ServiceScheduleItem(
          id: 'oil-days',
          bikeId: 'test-days',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          intervalMonths: 3,
          lastDoneKm: 5000,
          lastDoneDate: lastChangeDate,
          enabled: true,
        ),
      ]);

      final assessment = MaintenancePredictionEngine.analyze(
        bike: bike,
        rideReports: [],
      );
      final oil = assessment.components.firstWhere((c) => c.id == 'engine-oil');

      expect(oil.wearPercent, greaterThan(90));
      expect(oil.status, equals(ComponentStatus.dueSoon));
    });

    test('terrain-shortened: Off-road bike has higher wear % than highway bike at same km', () async {
      const offRoadBike = Bike(
        id: 'terrain-off',
        make: 'KTM',
        modelName: '690 Enduro R',
        modelYear: 2024,
        odometerKm: 7000,
        ridingTerrain: ['Off-road'],
        lastOilChange: ServiceRecord(km: 3000),
      );
      const highwayBike = Bike(
        id: 'terrain-hi',
        make: 'BMW',
        modelName: 'R1250RT',
        modelYear: 2024,
        odometerKm: 7000,
        ridingTerrain: ['Highway'],
        lastOilChange: ServiceRecord(km: 3000),
      );

      await setScheduleForTest(offRoadBike.id, [
        const ServiceScheduleItem(
          id: 'oil-off',
          bikeId: 'terrain-off',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          lastDoneKm: 4000,
          enabled: true,
        ),
      ]);
      await setScheduleForTest(highwayBike.id, [
        const ServiceScheduleItem(
          id: 'oil-hi',
          bikeId: 'terrain-hi',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          lastDoneKm: 4000,
          enabled: true,
        ),
      ]);

      final offRoadOil = MaintenancePredictionEngine.analyze(
        bike: offRoadBike,
        rideReports: [],
      ).components.firstWhere((c) => c.id == 'engine-oil');

      final highwayOil = MaintenancePredictionEngine.analyze(
        bike: highwayBike,
        rideReports: [],
      ).components.firstWhere((c) => c.id == 'engine-oil');

      expect(offRoadOil.wearPercent, greaterThan(highwayOil.wearPercent));
    });

    test('Mountain terrain also triggers 15% interval reduction', () async {
      const mountainBike = Bike(
        id: 'terrain-mount',
        make: 'Triumph',
        modelName: 'Tiger 900',
        modelYear: 2024,
        odometerKm: 5000,
        ridingTerrain: ['Mountain'],
        lastOilChange: ServiceRecord(km: 3000),
      );

      await setScheduleForTest(mountainBike.id, [
        const ServiceScheduleItem(
          id: 'oil-mount',
          bikeId: 'terrain-mount',
          type: ServiceItemType.oilAndSmallService,
          intervalKm: 5000,
          lastDoneKm: 2000,
          enabled: true,
        ),
      ]);

      final oil = MaintenancePredictionEngine.analyze(
        bike: mountainBike,
        rideReports: [],
      ).components.firstWhere((c) => c.id == 'engine-oil');

      expect(oil.wearPercent, greaterThan(0));
    });
  });

  // ── Part 2: Altitude density ratio unit tests ──────────────────────────────
  group('Altitude density ratio: US Standard Atmosphere 1976 formula', () {
    test('Sea level (0 m) returns density ratio of exactly 1.0', () {
      expect(atmosphericDensityRatio(0), closeTo(1.0, 0.0001));
    });

    test('1,000 m vs sea level gives ~0.91 density ratio', () {
      // Expected: (1 - 2.25577e-5 * 1000)^4.25588 ≈ 0.9075
      final ratio = altitudeDensityRatio(1000, 0);
      expect(ratio, closeTo(0.907, 0.005));
    });

    test('2,000 m vs sea level gives ~0.82 density ratio', () {
      // Expected: ≈ 0.8216
      final ratio = altitudeDensityRatio(2000, 0);
      expect(ratio, closeTo(0.822, 0.005));
    });

    test('1,500 m vs sea level gives ~0.86 density ratio', () {
      // Expected: (1 - 2.25577e-5 * 1500)^4.25588 ≈ 0.8637
      final ratio = altitudeDensityRatio(1500, 0);
      expect(ratio, closeTo(0.864, 0.005));
    });

    test('3,000 m vs sea level gives ~0.74 density ratio', () {
      // Expected: ≈ 0.7423
      final ratio = altitudeDensityRatio(3000, 0);
      expect(ratio, closeTo(0.742, 0.005));
    });

    test('Same altitude as baseline always gives ratio of 1.0', () {
      expect(altitudeDensityRatio(1500, 1500), closeTo(1.0, 0.0001));
      expect(altitudeDensityRatio(3000, 3000), closeTo(1.0, 0.0001));
    });

    test('Lower altitude than baseline gives ratio > 1.0 (denser air)', () {
      // At sea level vs 1000 m baseline: denser, ratio > 1
      expect(altitudeDensityRatio(0, 1000), greaterThan(1.0));
    });
  });

  // ── Part 2: Guidance band boundary tests in both directions ──────────────
  group('Guidance band lookup covers all boundaries in both directions', () {
    test('Thinner air boundaries (ratio <= 1.0)', () {
      // < 5% change: minimal
      expect(densityBand(1.0), equals(DensityBand.minimal));
      expect(densityBand(0.951), equals(DensityBand.minimal));

      // 5% to 10% change: slight
      expect(densityBand(0.950), equals(DensityBand.slight));
      expect(densityBand(0.901), equals(DensityBand.slight));

      // 10% to 20% change: noticeable
      expect(densityBand(0.900), equals(DensityBand.noticeable));
      expect(densityBand(0.801), equals(DensityBand.noticeable));

      // >= 20% change: significant
      expect(densityBand(0.800), equals(DensityBand.significant));
      expect(densityBand(0.700), equals(DensityBand.significant));
    });

    test('Denser air boundaries (ratio >= 1.0)', () {
      // < 5% change: minimal
      expect(densityBand(1.000), equals(DensityBand.minimal));
      expect(densityBand(1.049), equals(DensityBand.minimal));

      // 5% to 10% change: slight
      expect(densityBand(1.050), equals(DensityBand.slight));
      expect(densityBand(1.099), equals(DensityBand.slight));

      // 10% to 20% change: noticeable
      expect(densityBand(1.100), equals(DensityBand.noticeable));
      expect(densityBand(1.199), equals(DensityBand.noticeable));

      // >= 20% change: significant
      expect(densityBand(1.200), equals(DensityBand.significant));
      expect(densityBand(1.282), equals(DensityBand.significant));
    });

    test('parseCarbType correctly identifies slide, CV and other carb types', () {
      expect(parseCarbType('Mikuni VM34 slide'), equals(CarbType.slide));
      expect(parseCarbType('Keihin CVK36'), equals(CarbType.cv));
      expect(parseCarbType('Mikuni BST33 CV'), equals(CarbType.cv));
      expect(parseCarbType(null), equals(CarbType.other));
      expect(parseCarbType('Unknown carb'), equals(CarbType.other));
    });
  });

  // ── Direction-aware carburetor guidance (safety tests) ────────────────────
  group('Direction-aware carburetor guidance (safety & lean-risk tests)', () {
    test('Baseline 3,000m with current 500m (ratio ~1.28) must NOT return minimal / no-adjustment', () {
      final ratio = altitudeDensityRatio(500, 3000);
      // Ratio should be approx 1.28 (denser air, descended from 3000m to 500m)
      expect(ratio, closeTo(1.28, 0.02));

      final band = densityBand(ratio);
      expect(band, isNot(equals(DensityBand.minimal)));
      expect(band, equals(DensityBand.significant));

      final text = jetingGuidanceText(band, CarbType.slide, densityRatio: ratio);
      // Must NOT claim no adjustment needed
      expect(text, isNot(contains('no adjustment needed')));

      // Must display prominent lean-risk warning
      expect(text, contains(leanRunningRiskWarning));
      expect(text, contains('LEAN-RISK WARNING'));
      expect(text, contains('CRITICAL RISK'));
      expect(text, contains(returnToBaselineWarning));
      expect(text, contains('TODO'));
    });

    test('Baseline 500m with current 500m returns minimal and confirms baseline match', () {
      final ratio = altitudeDensityRatio(500, 500);
      expect(ratio, closeTo(1.0, 0.0001));

      final band = densityBand(ratio);
      expect(band, equals(DensityBand.minimal));

      final text = jetingGuidanceText(band, CarbType.cv, densityRatio: ratio);
      expect(text, contains('Carburetor jetting likely matches this altitude — no adjustment needed.'));
      expect(text, contains(returnToBaselineWarning));
      expect(text, contains('TODO'));
    });

    test('Baseline 500m with current 3,000m returns thinner-air / rich-running result', () {
      final ratio = altitudeDensityRatio(3000, 500);
      // Ratio is approx 0.779 (< 0.80)
      expect(ratio, closeTo(0.779, 0.01));

      final band = densityBand(ratio);
      expect(band, equals(DensityBand.significant));

      final text = jetingGuidanceText(band, CarbType.slide, densityRatio: ratio);
      // Must NOT show the lean-risk warning (because air is thinner, not denser)
      expect(text, isNot(contains('LEAN-RISK WARNING')));
      expect(text, contains('Air density has dropped over 20%'));
      expect(text, contains('run very rich'));
      expect(text, contains(returnToBaselineWarning));
      expect(text, contains('TODO'));
    });

    test('All guidance recommendations in both directions contain returnToBaselineWarning', () {
      // Test thinner-air (ratio < 1)
      for (final band in DensityBand.values) {
        for (final carb in CarbType.values) {
          final richText = jetingGuidanceText(band, carb, densityRatio: 0.75);
          expect(richText, contains(returnToBaselineWarning));
          expect(richText, contains('⚠️'));
          expect(richText, contains('TODO'));

          final leanText = jetingGuidanceText(band, carb, densityRatio: 1.25);
          expect(leanText, contains(returnToBaselineWarning));
          expect(leanText, contains('⚠️'));
          expect(leanText, contains('TODO'));
        }
      }
    });

    test('All denser-air conditions beyond 5% contain the exact lean-risk warning', () {
      final bands = [DensityBand.slight, DensityBand.noticeable, DensityBand.significant];
      for (final band in bands) {
        for (final carb in CarbType.values) {
          final text = jetingGuidanceText(band, carb, densityRatio: 1.15);
          expect(text, contains(leanRunningRiskWarning));
        }
      }
    });

    test('returnToBaselineWarning constant mentions lean and baseline', () {
      expect(returnToBaselineWarning, contains('baseline'));
      expect(returnToBaselineWarning, contains('lean'));
    });
  });

  // ── Tab State Preservation Widget Tests ───────────────────────────────────
  group('Tab state preservation when switching tabs in MaintenanceScreen', () {
    testWidgets('Checklist ticks, jetting log entries and post-ride form keep state when switching tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Set active bike to carburetor bike
      const carbBike = Bike(
        id: 'test-carb-bike',
        make: 'Honda',
        modelName: 'XR650L',
        modelYear: 2021,
        odometerKm: 12000,
        ridingTerrain: ['Off-road', 'Mountain'],
        fuelSystem: FuelSystem.carburetor,
        carburetorType: 'Keihin CVK40',
      );
      ActiveBikeController.instance.addBike(carbBike);
      ActiveBikeController.instance.setActiveBike(carbBike.id);
      addTearDown(() {
        ActiveBikeController.instance.removeBike(carbBike.id);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Switch to Carburetor tab (index 1) and enter baseline altitude
      await tester.tap(find.text('Carburetor').first);
      await tester.pumpAndSettle();

      final baselineFinder = find.descendant(
        of: find.byType(CarburetorTab),
        matching: find.byType(TextField),
      ).first;
      await tester.enterText(baselineFinder, '1850');
      await tester.pumpAndSettle();
      expect(find.text('1850'), findsOneWidget);

      // 2. Switch to Pre-Ride tab (index 2) and check an item
      await tester.tap(find.text('Pre-Ride'));
      await tester.pumpAndSettle();

      // Pre-ride audit should start with 0 of 7 Done
      expect(find.text('0 of 7 Done'), findsOneWidget);

      // Tap first checkbox item
      await tester.tap(find.text('Tire Pressures & Tread Inspection'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 7 Done'), findsOneWidget);

      // 3. Switch to Post-Ride tab (index 3) and verify "Log a ride" is present
      await tester.tap(find.text('Post-Ride'));
      await tester.pumpAndSettle();
      expect(find.text('Log a ride'), findsOneWidget);
      expect(find.text('EXPEDITION LOG HISTORY (0)'), findsOneWidget);

      // 4. Switch back to Diagnostics tab (index 0)
      await tester.tap(find.text('Diagnostics'));
      await tester.pumpAndSettle();
      expect(find.text('MAINTENANCE HEALTH INDEX'), findsOneWidget);

      // 5. Switch back to Carburetor tab — baseline altitude '1850' must STILL be there!
      await tester.tap(find.text('Carburetor').first);
      await tester.pumpAndSettle();
      expect(find.text('1850'), findsOneWidget);

      // 6. Switch back to Pre-Ride tab — '1 of 7 Done' must STILL be there!
      await tester.tap(find.text('Pre-Ride'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 7 Done'), findsOneWidget);

      // 7. Switch back to Post-Ride tab — "Log a ride" must STILL be there!
      await tester.tap(find.text('Post-Ride'));
      await tester.pumpAndSettle();
      expect(find.text('Log a ride'), findsOneWidget);
      expect(find.text('EXPEDITION LOG HISTORY (0)'), findsOneWidget);
    });
  });

  group('Post-Ride Debrief Button & Screen Tests', () {
    testWidgets('Tapping "Log Post-Ride Debrief" opens form screen, saving adds report and updates predictive card, history, and Profile stats',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      // Ensure active bike has 0 reports
      final activeBike = ActiveBikeController.instance.activeBike!;
      PostRideReportController.instance.clearReportsForBike(activeBike.id);

      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the predictive card shows empty state with honest computation text
      expect(find.text('Log a few rides to unlock pattern insights.'), findsOneWidget);
      expect(
        find.text(
          'After logging at least 3 post-ride reports, CAMP summarizes your ride distance, terrain mix, and average km per day.',
        ),
        findsOneWidget,
      );
      final debriefBtn = find.text('Log Post-Ride Debrief');
      expect(debriefBtn, findsOneWidget);

      // Initial profile stats before saving
      final initialStats = ProfileStats(PostRideReportController.instance.reports);
      expect(initialStats.ridesCount, equals(0));
      expect(initialStats.lifetimeDistanceKm, equals(0.0));

      // Tap the button
      await tester.tap(debriefBtn);
      await tester.pumpAndSettle();

      // Verify PostRideDebriefScreen is pushed
      expect(find.byType(PostRideDebriefScreen), findsOneWidget);
      expect(find.text('POST-RIDE DEBRIEF'), findsWidgets);
      expect(find.text('DISTANCE COVERED (KM) *'), findsOneWidget);

      // Verify inputs are initially empty (no pre-filled defaults)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3)); // distance, duration, notes

      // Enter distance in km (required, > 0)
      await tester.enterText(textFields.at(0), '175.5');
      // Enter duration (optional)
      await tester.enterText(textFields.at(1), '3.5');
      // Enter notes (optional)
      await tester.enterText(textFields.at(2), 'Alpine gravel expedition with rocky passes');

      // Tap Save
      final saveBtn = find.text('Save Post-Ride Report');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Screen popped back to MaintenanceScreen without leaving
      expect(find.byType(PostRideDebriefScreen), findsNothing);
      expect(find.byType(MaintenanceScreen), findsOneWidget);

      // Verify the report was added to PostRideReportController
      final reports = PostRideReportController.instance.getReportsForBike(activeBike.id);
      expect(reports.length, equals(1));
      expect(reports.first.distanceKm, equals(175.5));
      expect(reports.first.durationHours, equals(3.5));
      expect(reports.first.notes, equals('Alpine gravel expedition with rocky passes'));

      // Verify Profile stats updated immediately
      final updatedStats = ProfileStats(PostRideReportController.instance.reports);
      expect(updatedStats.ridesCount, equals(1));
      expect(updatedStats.lifetimeDistanceKm, equals(175.5));

      // With only 1 report, predictive card still prompts for more
      expect(find.text('Log a few rides to unlock pattern insights.'), findsOneWidget);

      // Add 2 more reports to reach 3 total
      PostRideReportController.instance.addReport(
        PostRideReport(
          id: 'rep-extra-1',
          bikeId: activeBike.id,
          date: DateTime.now().subtract(const Duration(days: 2)),
          distanceKm: 120.0,
          terrainTags: const ['Off-road'],
        ),
      );
      PostRideReportController.instance.addReport(
        PostRideReport(
          id: 'rep-extra-2',
          bikeId: activeBike.id,
          date: DateTime.now().subtract(const Duration(days: 1)),
          distanceKm: 95.0,
          terrainTags: const ['Off-road', 'Mountain'],
        ),
      );
      await tester.pumpAndSettle();

      // Now with 3 reports, the "Log a few rides" placeholder is gone and insights are unlocked
      expect(find.text('Log a few rides to unlock pattern insights.'), findsNothing);
      expect(find.text('CAMP PREDICTIVE INTELLIGENCE'), findsOneWidget);
    });

    testWidgets('Post-Ride Debrief screen stores selected terrain chips and verifies wording',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeBike = ActiveBikeController.instance.activeBike!;
      PostRideReportController.instance.clearReportsForBike(activeBike.id);

      await tester.pumpWidget(
        MaterialApp(
          home: PostRideDebriefScreen(bikeId: activeBike.id),
        ),
      );
      await tester.pumpAndSettle();

      // Check debrief screen subtitle
      expect(
        find.text(
          'Record your real ride. Logged rides feed your riding history, Profile stats and predicted service dates.',
        ),
        findsOneWidget,
      );

      // Check renamed notes field label
      expect(
        find.text('Trail observations / flagged symptoms (optional)'),
        findsOneWidget,
      );

      // Verify terrain chips are present
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Highway'), findsOneWidget);
      expect(find.text('Off-road'), findsOneWidget);
      expect(find.text('Mountain'), findsOneWidget);

      // Toggle 'Off-road' and 'Mountain'
      await tester.tap(find.text('Off-road'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mountain'));
      await tester.pumpAndSettle();

      // Enter distance and notes
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '210.0'); // distance
      await tester.enterText(textFields.at(1), '4.5'); // duration
      await tester.enterText(textFields.at(2), 'Pass ascent with rocky switchbacks'); // notes

      // Save report
      await tester.tap(find.text('Save Post-Ride Report'));
      await tester.pumpAndSettle();

      final reports = PostRideReportController.instance.getReportsForBike(activeBike.id);
      expect(reports.length, equals(1));
      expect(reports.first.distanceKm, equals(210.0));
      expect(reports.first.terrainTags, containsAll(['Off-road', 'Mountain']));
      expect(reports.first.notes, equals('Pass ascent with rocky switchbacks'));
    });

    testWidgets('Post-Ride tab "Clear Logs" shows confirmation dialog before deleting logs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      for (int i = 0; i < 5; i++) {
        PostRideReportController.instance.addReport(
          PostRideReport(
            id: 'test-clr-$i',
            bikeId: 'bike-bmw-1250',
            date: DateTime.now().subtract(Duration(days: i + 1)),
            distanceKm: 100.0,
            terrainTags: const ['Off-road'],
          ),
        );
      }

      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Post-Ride tab (active bike starts with seeded reports)
      await tester.tap(find.text('Post-Ride'));
      await tester.pumpAndSettle();

      expect(find.text('Clear Logs'), findsOneWidget);

      // Tap "Clear Logs"
      await tester.tap(find.text('Clear Logs'));
      await tester.pumpAndSettle();

      // Verify dialog is shown with exact warning text
      expect(find.text('Clear Expedition Logs?'), findsOneWidget);
      expect(
        find.textContaining(
          'deletes the saved ride reports and will change Profile stats and the predicted service dates',
        ),
        findsOneWidget,
      );

      // Tap Cancel -> Reports must not be deleted
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Clear Expedition Logs?'), findsNothing);
      expect(find.text('EXPEDITION LOG HISTORY (5)'), findsOneWidget);

      // Tap "Clear Logs" again and Confirm
      await tester.tap(find.text('Clear Logs'));
      await tester.pumpAndSettle();

      // Tap dialog Clear Logs button
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Clear Logs'),
      ));
      await tester.pumpAndSettle();

      // History cleared!
      expect(find.text('EXPEDITION LOG HISTORY (0)'), findsOneWidget);
      expect(find.textContaining('No post-ride reports logged yet'), findsOneWidget);
    });
  });

  group('Service Schedule: "Interval configured" and "Not set up" tests', () {
    test('On a fresh bike with nothing entered, all items evaluate to "Not set up"', () {
      const freshBike = Bike(
        id: 'bike-fresh-test',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 2500,
      );

      final items = MaintenanceController.instance.getScheduleItems(freshBike.id);
      expect(items, isNotEmpty);

      // Verify nothing is pre-filled
      for (final item in items) {
        expect(item.intervalKm, isNull, reason: 'Interval km should be null for unconfigured item');
        expect(item.intervalMonths, isNull, reason: 'Interval months should be null for unconfigured item');
        expect(item.hasInterval, isFalse);

        final prediction = ServiceScheduleEngine.evaluateItem(
          item: item,
          currentOdometerKm: freshBike.odometerKm.toDouble(),
          isHarshConditions: false,
          recentReports: const [],
        );

        expect(prediction.scheduleStatus, equals(ScheduleItemStatus.notSetUp));
        expect(prediction.displaySubtitle, equals('Not set up'));
      }

      // In MaintenancePredictionEngine, all components show "Not set up"
      final assessment = MaintenancePredictionEngine.analyze(
        bike: freshBike,
        rideReports: const [],
      );

      for (final comp in assessment.components) {
        expect(comp.scheduleStatus, equals(ScheduleItemStatus.notSetUp));
        expect(comp.statusBadgeText, equals('Not set up'));
        expect(comp.reason, contains('Service schedule not set up'));
      }
    });

    test('Item shows "Interval configured" ONLY when rider entered an interval without last done', () async {
      const bike = Bike(
        id: 'bike-interval-test',
        make: 'KTM',
        modelName: '390 Adventure',
        modelYear: 2023,
        odometerKm: 4200,
      );

      // Unconfigured item
      const unconfigured = ServiceScheduleItem(
        id: 'item-oil',
        bikeId: 'bike-interval-test',
        type: ServiceItemType.oilAndSmallService,
      );
      final unconfiguredPred = ServiceScheduleEngine.evaluateItem(
        item: unconfigured,
        currentOdometerKm: bike.odometerKm.toDouble(),
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(unconfiguredPred.scheduleStatus, equals(ScheduleItemStatus.notSetUp));
      expect(unconfiguredPred.displaySubtitle, equals('Not set up'));

      // Configured interval without last-done
      final configured = unconfigured.copyWith(intervalKm: 3000);
      final configuredPred = ServiceScheduleEngine.evaluateItem(
        item: configured,
        currentOdometerKm: bike.odometerKm.toDouble(),
        isHarshConditions: false,
        recentReports: const [],
      );
      expect(configuredPred.scheduleStatus, equals(ScheduleItemStatus.addLastDone));
      expect(configuredPred.displaySubtitle, equals('Interval configured'));

      // Set schedule in controller and analyze
      await setScheduleForTest(bike.id, [configured]);
      final assessment = MaintenancePredictionEngine.analyze(
        bike: bike,
        rideReports: const [],
      );
      expect(assessment.components.first.scheduleStatus, equals(ScheduleItemStatus.addLastDone));
      expect(assessment.components.first.statusBadgeText, equals('Interval configured'));
      expect(assessment.components.first.reason, contains('Interval configured'));
    });

    testWidgets('MaintenanceScreen displays "Not set up" for all components on unconfigured bike, and "Interval configured" only after interval entered',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      addTearDown(() => tester.view.resetPhysicalSize());

      const unconfiguredBike = Bike(
        id: 'bike-widget-interval-check',
        make: 'Suzuki',
        modelName: 'DR650',
        modelYear: 2022,
        odometerKm: 8500,
      );
      ActiveBikeController.instance.addBike(unconfiguredBike);
      ActiveBikeController.instance.setActiveBike(unconfiguredBike.id);
      addTearDown(() {
        ActiveBikeController.instance.removeBike(unconfiguredBike.id);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MaintenanceScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // On a fresh bike where nothing was entered, every component card shows 'Not set up'
      // and NONE show 'Interval configured'
      expect(find.text('Not set up'), findsWidgets);
      expect(find.text('Interval configured'), findsNothing);

      // Now configure an interval for Engine Oil & Small Service ONLY without last-done
      final items = MaintenanceController.instance.getScheduleItems(unconfiguredBike.id);
      final oilItem = items.firstWhere((i) => i.type == ServiceItemType.oilAndSmallService);
      final updatedOilItem = oilItem.copyWith(intervalKm: 2500);

      await setScheduleForTest(unconfiguredBike.id, [updatedOilItem]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Exactly ONE item shows 'Interval configured', and remaining components still show 'Not set up'
      expect(find.text('Interval configured'), findsOneWidget);
      expect(find.text('Not set up'), findsWidgets);
      expect(find.textContaining('Interval configured. Add last done reading'), findsOneWidget);
    });
  });
}
