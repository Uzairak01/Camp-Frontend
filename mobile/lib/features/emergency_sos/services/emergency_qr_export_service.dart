import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

/// Pure export service for rendering and formatting standalone Emergency QR codes.
/// Ensures the exported file contains strictly the QR code, quiet zone, header,
/// and caption, with zero personal medical or contact details printed as plain text.
class EmergencyQrExportService {
  EmergencyQrExportService._();

  static const String headerText = 'IN CASE OF EMERGENCY, SCAN';
  static const String captionText = 'Scan with your phone camera';

  /// Builds a high-resolution PNG (minimum 1200x1200px) containing only the QR code,
  /// solid white background, quiet zone >= 4 modules, header, and caption.
  static Future<Uint8List> buildEmergencyQrPng(
    String payload, {
    double size = 1200.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // 1. Solid white background
    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), bgPaint);

    // 2. Header text: "IN CASE OF EMERGENCY, SCAN"
    final headerPainter = TextPainter(
      text: const TextSpan(
        text: headerText,
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 42,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    headerPainter.layout(maxWidth: size - 80);
    headerPainter.paint(
      canvas,
      Offset((size - headerPainter.width) / 2, 80),
    );

    // 3. QR code with Error Correction Level Q and ample quiet zone (> 4 modules)
    const qrSize = 820.0;
    final qrX = (size - qrSize) / 2;
    const qrY = 180.0;

    final qrPainter = QrPainter(
      data: payload,
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

    canvas.save();
    canvas.translate(qrX, qrY);
    qrPainter.paint(canvas, const Size(qrSize, qrSize));
    canvas.restore();

    // 4. Caption text: "Scan with your phone camera"
    final captionPainter = TextPainter(
      text: const TextSpan(
        text: captionText,
        style: TextStyle(
          color: Color(0xFF475569),
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    captionPainter.layout(maxWidth: size - 80);
    captionPainter.paint(
      canvas,
      Offset((size - captionPainter.width) / 2, 1060),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to generate Emergency QR PNG byte data');
    }
    return byteData.buffer.asUint8List();
  }

  /// Builds a clean 1-page A4 PDF containing the same QR code centered and large
  /// (about 10 cm square) with the header and caption, and zero personal details.
  static Future<Uint8List> buildEmergencyQrPdf(String payload) async {
    // Generate pure QR raster bytes for embedding into PDF
    final qrPainter = QrPainter(
      data: payload,
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

    final qrByteData = await qrPainter.toImageData(
      600.0,
      format: ui.ImageByteFormat.png,
    );
    if (qrByteData == null) {
      throw Exception('Failed to generate QR image bytes for PDF');
    }
    final qrImage = pw.MemoryImage(qrByteData.buffer.asUint8List());

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  headerText,
                  style: const pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 28),
                pw.Container(
                  width: 10 * PdfPageFormat.cm,
                  height: 10 * PdfPageFormat.cm,
                  child: pw.Image(qrImage, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 24),
                pw.Text(
                  captionText,
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
