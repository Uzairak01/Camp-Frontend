import 'package:camp/core/data/app_repositories.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/presentation/screens/home_screen.dart';
import 'package:camp/features/dashboard/presentation/widgets/maintenance_alert_card_widget.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/maintenance/controllers/maintenance_controller.dart';
import 'package:camp/features/maintenance/controllers/post_ride_report_controller.dart';
import 'package:camp/features/maintenance/domain/post_ride_report.dart';
import 'package:camp/features/maintenance/domain/service_schedule_item.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:camp/features/settings/domain/units_system.dart';
import 'package:camp/features/settings/presentation/screens/settings_screen.dart';
import 'package:camp/features/settings/presentation/widgets/settings_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_cache_service.dart';
import 'helpers/fake_maintenance_repository.dart';
import 'helpers/fake_ride_report_repository.dart';
import 'helpers/fake_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSettingsRepository fakeSettingsRepo;
  late FakeCacheService fakeCacheService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'CAMP',
      packageName: 'com.camp.mobile',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    );

    fakeSettingsRepo = FakeSettingsRepository();
    fakeCacheService = FakeCacheService(sizeBytes: 1024 * 20);
    AppRepositories.resetWith(settingsRepository: fakeSettingsRepo);

    SettingsController.instance = SettingsController(
      repository: fakeSettingsRepo,
      cacheService: fakeCacheService,
    );
    ActiveBikeController.instance.reset();
    ProfileController.instance.resetForTesting();
    PostRideReportController.instance =
        PostRideReportController(repository: FakeRideReportRepository());
  });

  tearDown(() async {
    AppRepositories.resetToDefault();
  });

  group('SettingsController Honesty Pass Unit Tests', () {
    test('Default configuration is metric-only and honesty-first', () {
      final controller = SettingsController.instance;
      expect(controller.units, UnitsSystem.metric);
      expect(controller.isMetric, isTrue);
      expect(controller.isImperial, isFalse);
      expect(controller.notificationsEnabled, isTrue);
      expect(controller.language, 'English');
      expect(controller.dismissedAlertItemId, isNull);
      expect(controller.dismissedAlertStatus, isNull);
    });

    test('Notification preference updates and persists through SettingsRepository',
        () async {
      final controller = SettingsController.instance;
      expect(controller.notificationsEnabled, isTrue);

      controller.setNotificationsEnabled(false);
      await controller.save();
      expect(controller.notificationsEnabled, isFalse);

      // Verify persisted directly to repository
      final saved = await fakeSettingsRepo.loadSettings();
      expect(saved.notificationsEnabled, isFalse);

      // Reload into a fresh controller
      final fresh = SettingsController(repository: fakeSettingsRepo);
      await fresh.load();
      expect(fresh.notificationsEnabled, isFalse);
    });

    test('Language preference saves English through SettingsRepository',
        () async {
      final controller = SettingsController.instance;
      controller.setLanguage('English');
      await controller.save();
      expect(controller.language, 'English');

      final saved = await fakeSettingsRepo.loadSettings();
      expect(saved.language, 'English');
    });

    test('Home alert dismissal persists and reappears when status changes',
        () async {
      final controller = SettingsController.instance;

      expect(controller.isAlertDismissed('item-oil', 'dueSoon'), isFalse);

      // Dismiss the alert for item-oil at dueSoon
      controller.dismissAlert('item-oil', 'dueSoon');
      await controller.save();
      expect(controller.isAlertDismissed('item-oil', 'dueSoon'), isTrue);

      // Different item is NOT dismissed
      expect(controller.isAlertDismissed('item-chain', 'dueSoon'), isFalse);

      // Same item at different status is NOT dismissed
      expect(controller.isAlertDismissed('item-oil', 'overdue'), isFalse);

      // Survives a controller reload/restart
      final reloadedController =
          SettingsController(repository: fakeSettingsRepo);
      await reloadedController.load();

      expect(
          reloadedController.isAlertDismissed('item-oil', 'dueSoon'), isTrue);
      expect(
          reloadedController.isAlertDismissed('item-oil', 'overdue'), isFalse);

      // Mark done or clear dismissal
      reloadedController.clearDismissedAlert();
      await reloadedController.save();
      expect(
          reloadedController.isAlertDismissed('item-oil', 'dueSoon'), isFalse);
    });

    test('clearTemporaryCache clears only files in temporary cache directory',
        () async {
      final controller = SettingsController.instance;
      fakeCacheService.sizeBytes = 1024 * 50;

      final clearedBytes = await controller.clearTemporaryCache();
      expect(clearedBytes, 1024 * 50);
      expect(fakeCacheService.cleared, isTrue);
      expect(controller.localCacheDisplay, '0 B');
    });
  });

  group('SettingsScreen Widget Honesty Pass Tests', () {
    testWidgets('Header has no ADV PRO badge and no green online dot',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No ADV PRO badge
      expect(find.text('ADV PRO'), findsNothing);
      expect(find.text('ADV PROMOTER'), findsNothing);

      // No tier chip when there are no rides
      expect(PostRideReportController.instance.reports, isEmpty);
      expect(find.text('ROOKIE'), findsNothing);
      expect(find.text('EXPLORER'), findsNothing);
      expect(find.text('VETERAN'), findsNothing);
      expect(find.text('LEGEND'), findsNothing);
    });

    testWidgets('Header shows tier chip only if computed from real rides',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Add real ride report (150 km) -> Rookie tier
      PostRideReportController.instance.addReport(
        PostRideReport(
          id: 'real-ride-1',
          bikeId: 'bike-1',
          date: DateTime.now(),
          distanceKm: 150.0,
          durationHours: 2.5,
          terrainTags: const ['Gravel'],
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show real tier chip
      expect(find.text('Rookie'), findsOneWidget);
    });

    testWidgets(
        'Language list shows only English and Urdu; Urdu shows Coming soon and cannot be selected',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Language preference row
      await tester.tap(find.text('Language'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Exactly English and Urdu present
      expect(find.text('English'), findsWidgets);
      expect(find.text('اردو (Urdu)'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Coming soon'),
        ),
        findsOneWidget,
      );

      // Removed languages must NOT be present
      expect(find.text('German'), findsNothing);
      expect(find.text('French'), findsNothing);
      expect(find.text('Spanish'), findsNothing);
      expect(find.text('Italian'), findsNothing);

      // Tapping Urdu does NOT change the language
      await tester.tap(find.text('اردو (Urdu)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(SettingsController.instance.language, 'English');

      // Tapping English selects and closes
      await tester.tap(find.text('English').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(SettingsController.instance.language, 'English');
    });

    testWidgets(
        'Settings has no Units, Linked Accounts, Change Password, or telemetry text',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Units removed
      expect(find.text('Units'), findsNothing);
      expect(find.text('Metric (km, °C)'), findsNothing);
      expect(find.text('Imperial (mi, °F)'), findsNothing);

      // 2. Linked accounts removed
      expect(find.text('Linked Accounts'), findsNothing);
      expect(find.text('CAMP Cloud Backup'), findsNothing);
      expect(find.text('Google Drive'), findsNothing);
      expect(find.text('Apple Health'), findsNothing);
      expect(find.text('uzair@camp.io'), findsNothing);

      // 3. Change password removed
      expect(find.text('Change Password'), findsNothing);

      // 4. Telemetry removed and replaced with privacy info row
      expect(
          find.textContaining(RegExp(r'telemetry', caseSensitive: false)),
          findsNothing);
      expect(find.text('Your data stays on this phone.'), findsOneWidget);

      // 5. Offline maps shows Coming soon with no size
      expect(find.text('Offline Maps'), findsOneWidget);
      expect(find.text('Coming soon'), findsWidgets);
      expect(find.text('Cascades & Alps'), findsNothing);
      expect(find.text('14.2 GB used'), findsNothing);

      // 6. Notifications describes real low fuel alerts
      expect(find.text('Low fuel alerts'), findsOneWidget);

      // 7. Edit personal info is kept
      expect(find.text('Edit Personal Info'), findsOneWidget);
    });

    testWidgets('Notification switch toggles and persists', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(SettingsController.instance.notificationsEnabled, isTrue);

      // Toggle switch
      final switchFinder = find.byType(TacticalSwitch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(SettingsController.instance.notificationsEnabled, isFalse);

      final saved = await fakeSettingsRepo.loadSettings();
      expect(saved.notificationsEnabled, isFalse);
    });

    testWidgets('Clear Local Cache confirms and shows snackbar with cleared size',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeCacheService.sizeBytes = 1024 * 20;

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Clear Local Cache
      await tester.tap(find.text('Clear Local Cache'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog confirms
      expect(find.text('Clear Local Cache?'), findsOneWidget);
      expect(find.text('Clear Cache'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Clear Cache'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Snackbar shows size cleared
      expect(find.textContaining('Local cache cleared'), findsOneWidget);
      expect(fakeCacheService.cleared, isTrue);

      // Advance past SnackBar duration
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('About CAMP shows real version from package info',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('v1.2.3 (42)'), findsOneWidget);
      expect(find.text('CAMP v1.2.3 (42) • Built for adventure riders'),
          findsOneWidget);
    });

    testWidgets(
        'Home alert dismissal survives controller restart and returns when status changes',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const bike = Bike(
        id: 'bike-dismiss-test',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2024,
        odometerKm: 4950,
      );
      ActiveBikeController.instance.addBike(bike, setActive: true);

      final fakeMaint = FakeMaintenanceRepository();
      final item = ServiceScheduleItem(
        id: 'item-engine-oil',
        bikeId: 'bike-dismiss-test',
        type: ServiceItemType.oilAndSmallService,
        intervalKm: 5000,
        lastDoneKm: 0,
        intervalMonths: 6,
        lastDoneDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      await fakeMaint.saveServiceSchedule(bike.id, [item]);
      MaintenanceController.instance =
          MaintenanceController(repository: fakeMaint);
      await MaintenanceController.instance.loadSchedule(bike.id);

      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Alert card is shown
      expect(find.byType(MaintenanceAlertCardWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MaintenanceAlertCardWidget),
          matching: find.text('DUE SOON'),
        ),
        findsOneWidget,
      );
      expect(find.text('Dismiss'), findsOneWidget);

      // Tap Dismiss
      await tester.tap(find.text('Dismiss'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Alert is now gone
      expect(find.byType(MaintenanceAlertCardWidget), findsNothing);

      // Simulate app restart / controller restart
      final reloadedSettings = SettingsController(repository: fakeSettingsRepo);
      await reloadedSettings.load();
      SettingsController.instance = reloadedSettings;

      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Alert stays dismissed
      expect(find.byType(MaintenanceAlertCardWidget), findsNothing);

      // Status changes: odometer advances past interval (4950 -> 5100) -> Overdue
      ActiveBikeController.instance.updateBike(
        bike.copyWith(odometerKm: 5100),
      );

      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Alert reappears because status is now OVERDUE
      expect(find.byType(MaintenanceAlertCardWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MaintenanceAlertCardWidget),
          matching: find.text('OVERDUE'),
        ),
        findsOneWidget,
      );

      // Mark done
      await MaintenanceController.instance.markItemDone(
        bike.id,
        item.id,
        odometerKm: 5100,
        date: DateTime.now(),
      );
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Alert (OVERDUE/DUE SOON/Dismiss) is gone
      expect(find.text('OVERDUE'), findsNothing);
      expect(find.text('DUE SOON'), findsNothing);
      expect(find.text('Dismiss'), findsNothing);

      // Neutral "No maintenance due" card is displayed
      expect(find.text('No maintenance due'), findsOneWidget);
      expect(find.text('UP TO DATE'), findsOneWidget);
      expect(SettingsController.instance.dismissedAlertItemId, isNull);
    });
  });
}
