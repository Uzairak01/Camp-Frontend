import 'package:camp/core/storage/local_store.dart';
import 'package:camp/core/utils/currency_formatter.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/dashboard/domain/user_profile_model.dart';
import 'package:camp/features/emergency_sos/domain/emergency_sos_helpers.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/emergency_contact_card.dart';
import 'package:camp/features/emergency_sos/presentation/widgets/offline_medical_id_card.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/garage/presentation/widgets/update_fuel_sheet.dart';
import 'package:camp/features/maintenance/controllers/trip_budget_controller.dart';
import 'package:camp/features/maintenance/domain/expense_model.dart';
import 'package:camp/features/maintenance/domain/maintenance_prediction_engine.dart';
import 'package:camp/features/maintenance/domain/trip_budget_model.dart';
import 'package:camp/features/maintenance/presentation/widgets/trip_budget_card_widget.dart';
import 'package:camp/features/mechanics/domain/mechanic_model.dart';
import 'package:camp/features/mechanics/presentation/widgets/mechanic_card.dart';
import 'package:camp/features/navigation/domain/location_service.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:camp/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeLocationService implements LocationService {
  const FakeLocationService({this.position});
  final PositionData? position;

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<bool> checkPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<PositionData?> getCurrentPosition() async => position;
  @override
  Future<PositionData?> getLastKnownPosition() async => position;
  @override
  Stream<PositionData> getPositionStream({
    bool highAccuracy = false,
    bool enableForegroundNotification = false,
    bool? forceLocationManager,
  }) async* {
    if (position != null) yield position!;
  }
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LocalStore(prefs);
    LocalStore.instance = store;
    SettingsController.instance.reset();
    ProfileController.instance.resetForTesting();
  });

  group('Safety & Honesty: Emergency Number & Settings Persistence', () {
    test('Default emergency number is 1122 in AppSettings and SettingsController', () {
      final defaultSettings = AppSettings();
      expect(defaultSettings.emergencyNumber, '1122');

      final controller = SettingsController.instance;
      expect(controller.emergencyNumber, '1122');
    });

    test('SettingsController persists emergency number updates across reloads', () async {
      final controller = SettingsController.instance;
      bool notified = false;
      controller.addListener(() => notified = true);

      // Change to 15 (Police)
      controller.setEmergencyNumber('15');
      expect(controller.emergencyNumber, '15');
      expect(notified, isTrue);

      // Verify persistence by loading raw JSON from store
      final loadedSettings = await SettingsController.instance.repository.loadSettings();
      expect(loadedSettings.emergencyNumber, '15');

      // Change to custom phone number
      controller.setEmergencyNumber('+923001234567');
      expect(controller.emergencyNumber, '+923001234567');
      final customLoaded = await SettingsController.instance.repository.loadSettings();
      expect(customLoaded.emergencyNumber, '+923001234567');

      // Reset restores default 1122
      controller.reset();
      expect(controller.emergencyNumber, '1122');
    });

    test('AppSettings JSON serialization round-trips emergencyNumber correctly', () {
      final original = AppSettings().copyWith(
        emergencyNumber: '115',
      );
      final json = original.toJson();
      expect(json['emergencyNumber'], '115');

      final reconstructed = AppSettings.fromJson(json);
      expect(reconstructed.emergencyNumber, '115');

      // Tolerant fallback to 1122 when key is missing or empty
      final withoutKey = <String, dynamic>{};
      final fallback = AppSettings.fromJson(withoutKey);
      expect(fallback.emergencyNumber, '1122');
    });
  });

  group('Safety & Honesty: SOS SMS Body Generation (GPS link vs not available)', () {
    test('SMS body contains Google Maps link and accuracy when PositionData is present', () {
      final pos = PositionData(
        latitude: 35.123456,
        longitude: 74.654321,
        accuracy: 8.5,
        timestamp: DateTime(2026, 10, 18, 12, 0),
      );

      final body = buildEmergencySmsBody(pos);

      expect(body, 'I need help. My location: https://www.google.com/maps?q=35.123456,74.654321');
      expect(body, contains('https://www.google.com/maps?q=35.123456,74.654321'));
      // Must NOT contain claims of satellite/iridium hardware
      expect(body.toLowerCase(), isNot(contains('satellite')));
      expect(body.toLowerCase(), isNot(contains('iridium')));
    });

    test('SMS body states location not available yet when PositionData is null', () {
      final body = buildEmergencySmsBody(null);

      expect(body, 'I need help. My location: location not available yet');
      // Must NOT contain a fake or broken maps link
      expect(body, isNot(contains('https://www.google.com/maps')));
    });
  });

  group('Safety & Honesty: Emergency Contact Card Empty State & Actions', () {
    testWidgets('Renders empty state with "Add contact" when contact phone is not saved', (tester) async {
      // Clear profile contact phone
      ProfileController.instance.updateProfile(
        emergencyContactName: '',
        emergencyContactPhone: '',
        emergencyContactRelation: '',
      );

      bool editPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EmergencyContactCard(
                onEditPressed: () => editPressed = true,
                locationService: const FakeLocationService(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state visible
      expect(find.text('No emergency contact saved'), findsOneWidget);
      expect(find.text('Save a trusted emergency contact in your profile to alert them during a crisis.'), findsOneWidget);
      expect(find.text('Add contact'), findsOneWidget);

      // Contact action buttons should NOT be rendered
      expect(find.text('Call my contact'), findsNothing);
      expect(find.text('Alert my contacts'), findsNothing);

      // Tapping "Add contact" triggers navigation/callback
      await tester.tap(find.text('Add contact'));
      await tester.pumpAndSettle();
      expect(editPressed, isTrue);
    });

    testWidgets('Renders contact details, Call and Alert buttons when contact exists', (tester) async {
      ProfileController.instance.updateProfile(
        emergencyContactName: 'Fatima Khan',
        emergencyContactPhone: '+92 300 9876543',
        emergencyContactRelation: 'Spouse',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EmergencyContactCard(
                locationService: FakeLocationService(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fatima Khan'), findsOneWidget);
      expect(find.text('Spouse'), findsOneWidget);
      expect(find.text('+92 300 9876543'), findsOneWidget);
      expect(find.text('Call my contact'), findsOneWidget);
      expect(find.text('Alert my contacts'), findsOneWidget);
      expect(find.text('Opens your messages app, tap Send'), findsOneWidget);
    });
  });

  group('Safety & Honesty: Mechanic Phone & Call Now Visibility', () {
    testWidgets('MechanicCard HIDES Call Now button when mechanic has no phone', (tester) async {
      const mechanicWithoutPhone = Mechanic(
        id: 'mech-no-phone',
        name: 'Remote Pass Tool Shed',
        distance: '4.5 km away',
        durationOrLocation: 'Pass Summit',
        badgeType: BadgeType.verified,
        badgeLabel: 'Added by you',
        beaconStatus: 'Offline',
        beaconColor: Colors.grey,
        categoryTitle1: 'SERVICES',
        tags1: ['Hand Tools', 'Air Pump'],
        categoryTitle2: 'NOTES',
        tags2: ['Unattended'],
        rating: 4.5,
        reviewCount: 3,
        openStatus: 'SELF SERVICE',
        phoneNumber: null,
      );

      expect(mechanicWithoutPhone.hasPhone, isFalse);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MechanicCard(
              mechanic: mechanicWithoutPhone,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card is rendered
      expect(find.text('Remote Pass Tool Shed'), findsOneWidget);
      // "Call Now" button must NOT be present
      expect(find.text('Call Now'), findsNothing);
      // Route GPS button should still be present
      expect(find.text('Route GPS'), findsOneWidget);
    });

    testWidgets('MechanicCard SHOWS Call Now button when mechanic has phone number', (tester) async {
      const mechanicWithPhone = Mechanic(
        id: 'mech-with-phone',
        name: 'Gilgit Express Moto Works',
        distance: '1.0 km away',
        durationOrLocation: 'Airport Road',
        badgeType: BadgeType.verified,
        badgeLabel: 'Added by you',
        beaconStatus: 'Active',
        beaconColor: Colors.green,
        categoryTitle1: 'SERVICES',
        tags1: ['Tire Repair', 'Oil Change'],
        categoryTitle2: 'LOCATION',
        tags2: ['Gilgit'],
        rating: 4.8,
        reviewCount: 15,
        openStatus: 'OPEN NOW',
        phoneNumber: '+92 300 5551234',
      );

      expect(mechanicWithPhone.hasPhone, isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MechanicCard(
              mechanic: mechanicWithPhone,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gilgit Express Moto Works'), findsOneWidget);
      expect(find.text('Call Now'), findsOneWidget);
      expect(find.text('Route GPS'), findsOneWidget);
    });
  });

  group('Safety & Honesty: Mechanic JSON Tolerant Round-Trip', () {
    test('Round-trips with phoneNumber populated', () {
      const original = Mechanic(
        id: 'mech-1',
        name: 'Karakoram Moto Hub',
        distance: '2.0 km away',
        durationOrLocation: 'Main Bazaar',
        badgeType: BadgeType.verified,
        badgeLabel: 'Added by you',
        beaconStatus: 'Active',
        beaconColor: Colors.green,
        categoryTitle1: 'SPECIALTIES',
        tags1: ['Brakes', 'Suspension'],
        categoryTitle2: 'LOCATION',
        tags2: ['Skardu'],
        rating: 4.9,
        reviewCount: 30,
        openStatus: 'OPEN NOW',
        phoneNumber: '+92 300 1122334',
      );

      final json = original.toJson();
      expect(json['phoneNumber'], '+92 300 1122334');
      expect(json['phone'], '+92 300 1122334');

      final parsed = Mechanic.fromJson(json);
      expect(parsed.id, original.id);
      expect(parsed.name, original.name);
      expect(parsed.phoneNumber, '+92 300 1122334');
      expect(parsed.phone, '+92 300 1122334');
      expect(parsed.hasPhone, isTrue);
    });

    test('Round-trips with no phone (null / empty)', () {
      const original = Mechanic(
        id: 'mech-no-phone',
        name: 'Pass Shelter Kit',
        distance: '10 km',
        durationOrLocation: 'Mile 40',
        badgeType: BadgeType.verified,
        badgeLabel: 'Added by you',
        beaconStatus: 'Active',
        beaconColor: Colors.grey,
        categoryTitle1: 'TOOLS',
        tags1: ['Tire Levers'],
        categoryTitle2: 'LOCATION',
        tags2: ['High Camp'],
        rating: 4.0,
        reviewCount: 1,
        openStatus: 'OPEN',
        phoneNumber: null,
      );

      final json = original.toJson();
      expect(json['phone'], '');
      expect(json['phoneNumber'], isNull);

      final parsed = Mechanic.fromJson(json);
      expect(parsed.hasPhone, isFalse);
      expect(parsed.phone, '');
      expect(parsed.phoneNumber, isNull);
    });

    test('Deserializes legacy JSON containing only "phone" field gracefully', () {
      final legacyJson = <String, dynamic>{
        'id': 'legacy-mech',
        'name': 'Legacy Repair Shop',
        'distance': '3 km',
        'durationOrLocation': 'Downtown',
        'badgeType': 'community',
        'badgeLabel': 'Community Added',
        'beaconStatus': 'Active',
        'beaconColor': 0xFF4CAF50,
        'categoryTitle1': 'SERVICES',
        'tags1': ['Welding'],
        'categoryTitle2': 'LOCATION',
        'tags2': ['City Center'],
        'rating': 4.5,
        'reviewCount': 10,
        'openStatus': 'OPEN NOW',
        'phone': '+92 345 9988776',
        // 'phoneNumber' intentionally omitted as in legacy records
      };

      final parsed = Mechanic.fromJson(legacyJson);
      expect(parsed.phone, '+92 345 9988776');
      expect(parsed.phoneNumber, '+92 345 9988776');
      expect(parsed.badgeLabel, 'Added by you');
      expect(parsed.hasPhone, isTrue);
    });

    test('Deserializes new JSON containing only "phoneNumber" field gracefully', () {
      final newJson = <String, dynamic>{
        'id': 'new-mech',
        'name': 'Modern Moto Station',
        'distance': '1 km',
        'durationOrLocation': 'Ring Road',
        'badgeType': 'community',
        'badgeLabel': 'Community Added',
        'beaconStatus': 'Active',
        'beaconColor': 0xFF4CAF50,
        'categoryTitle1': 'SERVICES',
        'tags1': ['Diagnostics'],
        'categoryTitle2': 'LOCATION',
        'tags2': ['Highway'],
        'rating': 4.7,
        'reviewCount': 8,
        'openStatus': 'OPEN NOW',
        'phoneNumber': '+92 321 4455667',
        // 'phone' intentionally omitted
      };

      final parsed = Mechanic.fromJson(newJson);
      expect(parsed.phone, '+92 321 4455667');
      expect(parsed.phoneNumber, '+92 321 4455667');
      expect(parsed.badgeLabel, 'Added by you');
      expect(parsed.hasPhone, isTrue);
    });
  });

  group('Safety & Honesty: Blood Type Normalization & Profile Model Extensions', () {
    test('normalizeBloodType handles all canonical blood types and legacy descriptions', () {
      expect(UserProfile.normalizeBloodType('A+'), 'A+');
      expect(UserProfile.normalizeBloodType('A-'), 'A-');
      expect(UserProfile.normalizeBloodType('B+'), 'B+');
      expect(UserProfile.normalizeBloodType('B-'), 'B-');
      expect(UserProfile.normalizeBloodType('AB+'), 'AB+');
      expect(UserProfile.normalizeBloodType('AB-'), 'AB-');
      expect(UserProfile.normalizeBloodType('O+'), 'O+');
      expect(UserProfile.normalizeBloodType('O-'), 'O-');
      expect(UserProfile.normalizeBloodType('Unknown'), 'Unknown');

      // Legacy verbose strings
      expect(UserProfile.normalizeBloodType('O+ (Universal Donor)'), 'O+');
      expect(UserProfile.normalizeBloodType('A+ (Type A Positive)'), 'A+');
      expect(UserProfile.normalizeBloodType('B- (Type B Negative)'), 'B-');
      expect(UserProfile.normalizeBloodType('Unknown / Not Tested'), 'Unknown');

      // Empty and null inputs
      expect(UserProfile.normalizeBloodType(null), '');
      expect(UserProfile.normalizeBloodType(''), '');
      expect(UserProfile.normalizeBloodType('   '), '');
    });

    test('UserProfile round-trips allergies and medicalNotes in toJson/fromJson', () {
      final profile = UserProfile(
        bloodGroup: 'B+',
        allergies: 'Penicillin, Sulfa drugs',
        medicalNotes: 'Type 1 Diabetic, wears insulin pump',
      );

      final json = profile.toJson();
      expect(json['bloodGroup'], 'B+');
      expect(json['allergies'], 'Penicillin, Sulfa drugs');
      expect(json['medicalNotes'], 'Type 1 Diabetic, wears insulin pump');

      final reconstructed = UserProfile.fromJson(json);
      expect(reconstructed.bloodGroup, 'B+');
      expect(reconstructed.allergies, 'Penicillin, Sulfa drugs');
      expect(reconstructed.medicalNotes, 'Type 1 Diabetic, wears insulin pump');

      // Tolerant of legacy JSON without medical fields
      final legacyJson = <String, dynamic>{
        'bloodGroup': 'O+ (Universal Donor)',
      };
      final legacyReconstructed = UserProfile.fromJson(legacyJson);
      expect(legacyReconstructed.bloodGroup, 'O+');
      expect(legacyReconstructed.allergies, isNull);
      expect(legacyReconstructed.medicalNotes, isNull);
    });
  });

  group('Safety & Honesty: Offline Medical ID Card (SOS Screen)', () {
    testWidgets('Shows empty state with "Add medical info" when nothing is saved', (tester) async {
      // Clear profile
      ProfileController.instance.updateProfile(
        bloodGroup: '',
        allergies: '',
        medicalNotes: '',
      );

      bool addPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfflineMedicalIdCard(
                onAddMedicalInfoPressed: () => addPressed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state visible
      expect(find.text('No medical info saved'), findsOneWidget);
      expect(find.text('Add your blood type, allergies, and medical notes to assist first responders in an emergency.'), findsOneWidget);
      expect(find.text('Add medical info'), findsOneWidget);

      // Verify NEVER contains old demo strings
      expect(find.text('O+ POS'), findsNothing);
      expect(find.text('Penicillin / Amoxicillin'), findsNothing);
      expect(find.textContaining('Titanium Rod'), findsNothing);
      expect(find.textContaining('Organ Donor'), findsNothing);
      expect(find.textContaining('without unlocking device'), findsNothing);

      // Tapping "Add medical info" triggers callback
      await tester.tap(find.text('Add medical info'));
      await tester.pumpAndSettle();
      expect(addPressed, isTrue);
    });

    testWidgets('Shows saved blood type and "Not set" for empty allergies/notes', (tester) async {
      ProfileController.instance.updateProfile(
        bloodGroup: 'B+',
        allergies: '',
        medicalNotes: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfflineMedicalIdCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card rendered
      expect(find.text('Medical ID'), findsOneWidget);
      expect(find.text('Emergency QR'), findsOneWidget);
      expect(find.text('Lock Screen QR'), findsNothing);

      // Blood type populated
      expect(find.text('B+'), findsOneWidget);

      // Empty fields show "Not set" in muted text
      expect(find.text('Not set'), findsNWidgets(2)); // Known Allergies and Medical Notes

      // No demo text
      expect(find.text('O+ POS'), findsNothing);
      expect(find.text('Penicillin / Amoxicillin'), findsNothing);
      expect(find.textContaining('Titanium Rod'), findsNothing);
      expect(find.textContaining('Organ Donor'), findsNothing);
      expect(find.textContaining('without unlocking device'), findsNothing);
    });

    testWidgets('Shows all saved rider values when populated', (tester) async {
      ProfileController.instance.updateProfile(
        bloodGroup: 'AB-',
        allergies: 'Latex, Bee stings',
        medicalNotes: 'Asthmatic, carries albuterol inhaler',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OfflineMedicalIdCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Medical ID'), findsOneWidget);
      expect(find.text('Emergency QR'), findsOneWidget);
      expect(find.text('AB-'), findsOneWidget);
      expect(find.text('Latex, Bee stings'), findsOneWidget);
      expect(find.text('Asthmatic, carries albuterol inhaler'), findsOneWidget);

      // No "Not set" text
      expect(find.text('Not set'), findsNothing);

      // No demo text
      expect(find.text('O+ POS'), findsNothing);
      expect(find.text('Penicillin / Amoxicillin'), findsNothing);
      expect(find.textContaining('Titanium Rod'), findsNothing);
      expect(find.textContaining('without unlocking device'), findsNothing);
    });
  });

  group('PKR Currency & Honest User-Entered Costs', () {
    test('formatPkr formats properly across various values', () {
      expect(formatPkr(0), 'Rs 0');
      expect(formatPkr(999), 'Rs 999');
      expect(formatPkr(1000), 'Rs 1,000');
      expect(formatPkr(125000), 'Rs 125,000');
      expect(formatPkr(1234567), 'Rs 1,234,567');
      expect(formatPkr(12.50), 'Rs 12.50');
      expect(formatPkr(12.5), 'Rs 12.50');
      expect(formatPkr(12.00), 'Rs 12');
      expect(formatPkr(-5), 'Rs 0'); // negative never shown
      expect(formatPkr(null), 'Rs 0');
    });

    test('parsePkr parses valid PKR inputs and rejects invalid/negatives', () {
      expect(parsePkr('12,500'), 12500.0);
      expect(parsePkr('12500'), 12500.0);
      expect(parsePkr('abc'), isNull);
      expect(parsePkr('-5'), isNull);
      expect(parsePkr(''), isNull);
      expect(parsePkr(null), isNull);
      expect(parsePkr('999999999999'), isNull); // exceeds kMaxPkrAmount
    });

    test('The maintenance rule engine returns no cost', () {
      const bike = Bike(
        id: 'test-bike',
        make: 'Honda',
        modelName: 'CRF300L',
        modelYear: 2023,
        odometerKm: 5000,
      );
      final assessment = MaintenancePredictionEngine.analyze(
        bike: bike,
        rideReports: const [],
      );

      // Verify rule engine calculates health and distance, never cost
      expect(assessment.healthIndex, inInclusiveRange(0, 100));
      expect(assessment.nextServiceKm, isNonNegative);
      for (final comp in assessment.components) {
        expect(comp.wearPercent, inInclusiveRange(0, 100));
        expect(comp.healthScore, inInclusiveRange(0, 100));
      }
    });

    test('Finances totals equal the sum of saved entries and empty state at zero', () {
      final controller = TripBudgetController.instance;
      controller.resetForTesting();
      expect(controller.expenses.isEmpty, isTrue);
      expect(controller.budget.allocatedSoFar, 0.0);

      controller.addExpense(
        const Expense(
          id: 'test-exp-1',
          category: ExpenseCategory.fuel,
          title: 'Fuel Test',
          amount: 2500.0,
          trackingMode: ExpenseTrackingMode.manualEntry,
        ),
      );
      controller.addExpense(
        const Expense(
          id: 'test-exp-2',
          category: ExpenseCategory.parts,
          title: 'Parts Test',
          amount: 7500.0,
          trackingMode: ExpenseTrackingMode.manualEntry,
        ),
      );

      expect(controller.budget.allocatedSoFar, 10000.0);
      expect(
        controller.budget.allocatedSoFar,
        controller.expenses.fold<double>(0.0, (s, e) => s + e.amount),
      );
    });

    testWidgets('TripBudgetCardWidget renders empty state and never contains dollar signs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TripBudgetCardWidget(
                tripBudget: const TripBudget(
                  tripName: 'Test Trip',
                  capAmount: 50000.0,
                  allocatedSoFar: 0.0,
                ),
                expenses: const [],
                onEditTrip: () {},
                onDeleteTrip: () {},
                onAddExpense: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state prompt
      expect(find.text('Add your first expense'), findsOneWidget);
      // Formatted in PKR
      expect(find.text('Rs 0'), findsOneWidget);
      expect(find.text('/ Rs 50,000 Budget Cap'), findsOneWidget);

      // Absolutely no "$" in any rendered text
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('Fuel cost shows only when fuel price is set', (tester) async {
      const testBike = Bike(
        id: 'fuel-test-bike',
        make: 'Yamaha',
        modelName: 'Tenere 700',
        modelYear: 2023,
        odometerKm: 2500,
        fuelTankCapacityLiters: 16.0,
        fuelRemainingLiters: 6.0,
      );

      // 1. Without fuel price set
      SettingsController.instance.setFuelPricePerLiter(null);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(
              key: ValueKey('no-price'),
              bike: testBike,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Refill mode
      await tester.tap(find.text('I Refilled'));
      await tester.pumpAndSettle();

      final textFieldsEmpty = find.byType(TextField);
      final priceFieldEmpty = tester.widget<TextField>(textFieldsEmpty.at(1));
      expect(priceFieldEmpty.controller!.text, isEmpty);
      expect(find.textContaining(r'$'), findsNothing);

      // 2. With fuel price set
      SettingsController.instance.setFuelPricePerLiter(280.0);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UpdateFuelSheet(
              key: ValueKey('with-price'),
              bike: testBike,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Refill mode
      await tester.tap(find.text('I Refilled'));
      await tester.pumpAndSettle();

      // Now price per litre is prefilled with 280
      final textFieldsSet = find.byType(TextField);
      final priceFieldSet = tester.widget<TextField>(textFieldsSet.at(1));
      expect(priceFieldSet.controller!.text, '280');
      expect(find.textContaining('Rs '), findsWidgets);
      expect(find.textContaining(r'$'), findsNothing);
    });
  });
}
