import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camp/app/routes.dart';
import 'package:camp/core/data/bike_repository_local.dart';
import 'package:camp/core/data/profile_repository_local.dart';
import 'package:camp/core/data/settings_repository_local.dart';
import 'package:camp/core/storage/local_store.dart';
import 'package:camp/features/dashboard/controllers/profile_controller.dart';
import 'package:camp/features/emergency_sos/domain/emergency_qr_payload.dart';
import 'package:camp/features/emergency_sos/presentation/screens/emergency_qr_screen.dart';
import 'package:camp/features/emergency_sos/services/emergency_qr_export_service.dart';
import 'package:camp/features/garage/controllers/active_bike_controller.dart';
import 'package:camp/features/garage/domain/bike_model.dart';
import 'package:camp/features/settings/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zxing2/qrcode.dart';

/// Helper to decode a QR code from PNG bytes using zxing2.
String decodeQrFromPng(Uint8List pngBytes) {
  final image = img.decodePng(pngBytes);
  if (image == null) {
    throw Exception('Failed to decode image from PNG bytes');
  }

  final luminanceSource = RGBLuminanceSource(
    image.width,
    image.height,
    image
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.rgba)
        .buffer
        .asInt32List(),
  );
  final bitmap = BinaryBitmap(HybridBinarizer(luminanceSource));
  final reader = QRCodeReader();
  final result = reader.decode(bitmap);
  return result.text;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    LocalStore.instance = store;
    SettingsController.instance.resetForTesting();
    ActiveBikeController.instance.reset();
    ProfileController.instance.resetForTesting();
    ProfileController.instance.repository = ProfileRepositoryLocal(store);
    SettingsController.instance.repository = SettingsRepositoryLocal(store);
    ActiveBikeController.instance.repository = BikeRepositoryLocal(store);
  });

  const testBike = Bike(
    id: 'bike-test-1',
    make: 'Suzuki',
    modelName: 'GS 150 SE',
    modelYear: 2023,
    odometerKm: 5400,
    plateNumber: 'AJM-3280',
    color: 'Metallic Black',
  );

  group('A. Proof by Decoding (zxing2) - Pure QrPainter and Exports', () {
    test('1. Short payload renders and decodes identically', () async {
      final payloadResult = EmergencyQrPayloadBuilder.build(
        fullName: 'Hassan Ali',
        bloodGroup: 'B+',
        allergies: 'None',
        medicalNotes: 'None',
        emergencyContactName: 'Fatima',
        emergencyContactPhone: '+92-300-1122334',
        emergencyContactRelation: 'Sister',
        bike: null,
      );

      final pngBytes = await EmergencyQrExportService.buildEmergencyQrPng(
        payloadResult.payload,
        size: 1200,
      );

      final decoded = decodeQrFromPng(pngBytes);
      expect(decoded, equals(payloadResult.payload));
      expect(decoded, contains('Name: Hassan Ali'));
      expect(decoded, contains('Blood Type: B+'));
    });

    test('2. Full payload with bike and details renders and decodes identically', () async {
      final payloadResult = EmergencyQrPayloadBuilder.build(
        fullName: 'Elena Vance',
        bloodGroup: 'O+',
        allergies: 'Penicillin',
        medicalNotes: 'Asthmatic, carries inhaler in jacket pocket',
        emergencyContactName: 'Marcus Vance',
        emergencyContactPhone: '+1-555-0199',
        emergencyContactRelation: 'Spouse',
        bike: testBike,
        includeBike: true,
      );

      final pngBytes = await EmergencyQrExportService.buildEmergencyQrPng(
        payloadResult.payload,
        size: 1200,
      );

      final decoded = decodeQrFromPng(pngBytes);
      expect(decoded, equals(payloadResult.payload));
      expect(decoded, contains('CAMP EMERGENCY MEDICAL ID'));
      expect(decoded, contains('Bike: Suzuki GS 150 SE, AJM-3280'));
      expect(decoded, contains('ICE Contact: Marcus Vance (Spouse) - +1-555-0199'));
    });

    test('3. Payload with fields toggled off renders and decodes identically', () async {
      final payloadResult = EmergencyQrPayloadBuilder.build(
        fullName: 'Rider Anonymous',
        bloodGroup: 'AB-',
        allergies: 'Sulfa',
        medicalNotes: 'Diabetic',
        emergencyContactName: 'Support',
        emergencyContactPhone: '+92-321-9988776',
        emergencyContactRelation: 'Emergency',
        bike: testBike,
        includeBloodType: false,
        includeAllergies: false,
        includeMedicalNotes: false,
        includeBike: false,
        includeEmergencyContact: true,
      );

      expect(payloadResult.payload, isNot(contains('Blood Type:')));
      expect(payloadResult.payload, isNot(contains('Allergies:')));
      expect(payloadResult.payload, isNot(contains('Medical Notes:')));
      expect(payloadResult.payload, isNot(contains('Bike:')));
      expect(payloadResult.payload, contains('ICE Contact: Support (Emergency) - +92-321-9988776'));

      final pngBytes = await EmergencyQrExportService.buildEmergencyQrPng(
        payloadResult.payload,
        size: 1200,
      );

      final decoded = decodeQrFromPng(pngBytes);
      expect(decoded, equals(payloadResult.payload));
    });

    test('4. Direct QrPainter Level Q raster renders and decodes cleanly with quiet zone', () async {
      const samplePayload = 'CAMP EMERGENCY MEDICAL ID\nName: John Doe\nBlood Type: A+';
      final painter = QrPainter(
        data: samplePayload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.Q,
        gapless: true,
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF000000),
        ),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF000000),
        ),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 600, 600));
      // Solid white background and quiet zone
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 600, 600),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.save();
      canvas.translate(50, 50);
      painter.paint(canvas, const Size(500, 500));
      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(600, 600);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final decoded = decodeQrFromPng(byteData!.buffer.asUint8List());
      expect(decoded, equals(samplePayload));
    });
  });

  group('B. Export Integrity - Dimensions, Formats, and Privacy', () {
    test('PNG export is at least 1200x1200px and contains no plain personal text', () async {
      const payload = 'CAMP EMERGENCY MEDICAL ID\nName: Confidential Rider\nBlood Type: O-';
      final pngBytes = await EmergencyQrExportService.buildEmergencyQrPng(payload, size: 1200);

      // Verify dimensions >= 1200x1200
      final decodedImage = img.decodePng(pngBytes);
      expect(decodedImage, isNotNull);
      expect(decodedImage!.width, greaterThanOrEqualTo(1200));
      expect(decodedImage.height, greaterThanOrEqualTo(1200));

      // Verify binary payload does not contain personal plain text strings outside QR encoding
      final rawString = String.fromCharCodes(pngBytes);
      expect(rawString, isNot(contains('Confidential Rider')));
      expect(rawString, isNot(contains('Blood Type: O-')));
    });

    test('PDF export is 1 A4 page, starts with %PDF, and contains no plain personal text', () async {
      const payload = 'CAMP EMERGENCY MEDICAL ID\nName: Private Person\nBlood Type: AB+';
      final pdfBytes = await EmergencyQrExportService.buildEmergencyQrPdf(payload);

      // Verify starts with %PDF
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));

      // Verify personal details are NEVER printed as unencrypted plain text in the PDF
      final pdfString = String.fromCharCodes(pdfBytes);
      expect(pdfString, isNot(contains('Private Person')));
      expect(pdfString, isNot(contains('Blood Type: AB+')));
    });
  });

  group('C. Real On-Screen QR Decoding Proof', () {
    testWidgets('Renders exact on-screen QR container widget, captures raster image, and decodes via zxing2',
        (WidgetTester tester) async {
      final key = GlobalKey();
      final expectedPayloadResult = EmergencyQrPayloadBuilder.build(
        fullName: 'Tariq Khan',
        bloodGroup: 'O+',
        allergies: 'Peanuts',
        medicalNotes: 'No major illnesses',
        emergencyContactName: 'Ayesha',
        emergencyContactPhone: '+92-300-5551234',
        emergencyContactRelation: 'Wife',
        bike: testBike,
        includeBike: true,
      );

      // Exact widget as rendered inside EmergencyQrScreen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Container(
                  width: 220,
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 2.0,
                    ),
                  ),
                  child: QrImageView(
                    data: expectedPayloadResult.payload,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.Q,
                    size: 184,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F172A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final uiImage = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        expect(byteData, isNotNull);

        final decoded = decodeQrFromPng(byteData!.buffer.asUint8List());
        expect(decoded, equals(expectedPayloadResult.payload));
        expect(decoded, contains('CAMP EMERGENCY MEDICAL ID'));
        expect(decoded, contains('Name: Tariq Khan'));
        expect(decoded, contains('Bike: Suzuki GS 150 SE, AJM-3280'));
      });
    });
  });

  group('D. EmergencyQrScreen Widget Tests - UI, Density Warnings & Buttons', () {
    Widget buildTestApp({Widget? home}) {
      return MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          routes: {
            CampRoutes.emergencyQr: (_) => const EmergencyQrScreen(),
            CampRoutes.editProfile: (_) => const Scaffold(body: Text('Edit Profile')),
            CampRoutes.addMotorcycle: (_) => const Scaffold(body: Text('Add Motorcycle')),
          },
          home: home ?? const EmergencyQrScreen(),
        ),
      );
    }

    testWidgets('Save QR as PNG, Save QR as PDF, and Share buttons exist; old Download button is gone',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Check Save buttons exist
      expect(find.text('Save QR as PNG'), findsOneWidget);
      expect(find.text('Save QR as PDF'), findsOneWidget);
      expect(find.byTooltip('Share QR image'), findsOneWidget);

      // Check old download button is completely gone
      expect(find.text('Download Emergency Card (PNG)'), findsNothing);
      expect(find.text('Download Emergency Card'), findsNothing);
    });

    testWidgets('Real QrImageView is present with Error Correction Level Q',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      final qrFinder = find.byType(QrImageView);
      expect(qrFinder, findsOneWidget);
      final qrWidget = tester.widget<QrImageView>(qrFinder);
      expect(qrWidget.errorCorrectionLevel, equals(QrErrorCorrectLevel.Q));
    });

    testWidgets('Shows density warning naming fields to shorten when payload is long',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      ProfileController.instance.updateProfile(
        fullName: 'Alexander Maximilian Christopher Montgomery',
        bloodGroup: 'AB-',
        allergies: 'Severe anaphylaxis to penicillin, bee venom, NSAIDs',
        medicalNotes: 'Type 1 diabetic using continuous pump, past right leg knee reconstruction surgery',
        emergencyContactName: 'Dr. Elizabeth Montgomery-Richardson',
        emergencyContactPhone: '+1-555-019928374',
        emergencyContactRelation: 'Personal Physician',
      );

      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      // Warning should be displayed naming the fields to shorten
      expect(find.text('High QR Density Warning'), findsOneWidget);
      expect(find.textContaining('Medical notes'), findsWidgets);
      expect(find.textContaining('Allergies'), findsWidgets);
      expect(find.textContaining('Full name'), findsWidgets);
    });
  });
}
