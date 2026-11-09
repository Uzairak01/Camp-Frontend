import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../garage/controllers/active_bike_controller.dart';
import '../domain/expense_model.dart';
import '../domain/maintenance_item_model.dart';
import '../domain/service_visit_model.dart';

/// Data payload for generating a Trip Budget PDF export.
class BudgetReportData {
  const BudgetReportData({
    required this.tripName,
    required this.capAmount,
    required this.allocatedSoFar,
    this.dateRange,
    this.expenses = const [],
    this.bikeName,
    this.costPerKmDisplay,
  });

  final String tripName;
  final double capAmount;
  final double allocatedSoFar;
  final String? dateRange;
  final List<Expense> expenses;
  final String? bikeName;
  final String? costPerKmDisplay;

  bool get isEmpty => expenses.isEmpty && capAmount <= 0;
}

/// Data payload for generating a Rig Health & Maintenance PDF export.
class MaintenanceReportData {
  const MaintenanceReportData({
    required this.bikeName,
    this.bikeId,
    this.odometerKm,
    this.items = const [],
    this.visits = const [],
    this.generatedDate,
  });

  final String bikeName;
  final String? bikeId;
  final num? odometerKm;
  final List<MaintenanceItem> items;
  final List<ServiceVisit> visits;
  final DateTime? generatedDate;

  bool get isEmpty => items.isEmpty && visits.isEmpty;
}

/// Pure PDF generator and export orchestrator for CAMP expedition reports.
class PdfReportService {
  /// Builds a PDF document for Trip Budget & Expense ledger purely in memory.
  static Future<Uint8List> buildBudgetPdf(BudgetReportData data) async {
    final pdf = pw.Document();

    final remaining = data.capAmount - data.allocatedSoFar;
    final isUnder = remaining >= 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CAMP EXPEDITION REPORT',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      data.tripName,
                      style: const pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (data.dateRange != null && data.dateRange!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Dates: ${data.dateRange!.replaceAll('–', '-').replaceAll('—', '-')}',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    if (data.bikeName != null && data.bikeName!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Vehicle: ${data.bikeName}',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'STATUS',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        isUnder ? 'HEALTHY MARGIN' : 'OVER BUDGET',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: isUnder ? PdfColors.green800 : PdfColors.red800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 14),

            // Financial Summary Cards
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildPdfMetricBox(
                    title: 'BUDGET CAP',
                    value: formatPkr(data.capAmount),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _buildPdfMetricBox(
                    title: 'ALLOCATED SO FAR',
                    value: formatPkr(data.allocatedSoFar),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _buildPdfMetricBox(
                    title: isUnder ? 'REMAINING' : 'OVER BUDGET',
                    value: formatPkr(isUnder ? remaining : -remaining),
                    valueColor: isUnder ? PdfColors.green800 : PdfColors.red800,
                  ),
                ),
                if (data.costPerKmDisplay != null) ...[
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: _buildPdfMetricBox(
                      title: 'COST / KM',
                      value: data.costPerKmDisplay!,
                    ),
                  ),
                ],
              ],
            ),
            pw.SizedBox(height: 24),

            // Expense Ledger Table
            pw.Text(
              'EXPENSE LEDGER',
              style: const pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 8),

            if (data.expenses.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                child: pw.Text(
                  'No expenses recorded for this trip.',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                headers: ['Category', 'Description', 'Bike', 'Tracking', 'Amount'],
                data: data.expenses.map((exp) {
                  String bikeLabel = 'No bike';
                  if (exp.bikeId != null && exp.bikeId!.isNotEmpty) {
                    final bike = ActiveBikeController.instance.getBikeById(exp.bikeId!);
                    bikeLabel = bike != null ? bike.name : 'Deleted bike';
                  }
                  return [
                    exp.category.displayName,
                    exp.displaySubtitle != null && exp.displaySubtitle!.isNotEmpty
                        ? '${exp.title} (${exp.displaySubtitle})'
                        : exp.title,
                    bikeLabel,
                    exp.trackingMode.label,
                    formatPkr(exp.amount),
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 24),
            pw.Text(
              'Generated by CAMP Motorcycle Expedition & Maintenance System.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Builds a PDF document for Rig Health & Maintenance Item checklist purely in memory.
  static Future<Uint8List> buildMaintenancePdf(
      MaintenanceReportData data) async {
    final pdf = pw.Document();

    final now = data.generatedDate ?? DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          final hasBikeId = data.bikeId != null && data.bikeId!.isNotEmpty;

          final assignedItems = hasBikeId
              ? data.items.where((i) => i.bikeId == data.bikeId).toList()
              : (data.bikeId == null
                  ? data.items
                      .where((i) => i.bikeId == null || i.bikeId!.isEmpty)
                      .toList()
                  : <MaintenanceItem>[]);

          final assignedVisits = hasBikeId
              ? data.visits.where((v) => v.bikeId == data.bikeId).toList()
              : (data.bikeId == null
                  ? data.visits
                      .where((v) => v.bikeId == null || v.bikeId!.isEmpty)
                      .toList()
                  : <ServiceVisit>[]);

          final unassignedItems = hasBikeId
              ? data.items
                  .where((i) => i.bikeId == null || i.bikeId!.isEmpty)
                  .toList()
              : <MaintenanceItem>[];

          final unassignedVisits = hasBikeId
              ? data.visits
                  .where((v) => v.bikeId == null || v.bikeId!.isEmpty)
                  .toList()
              : <ServiceVisit>[];

          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CAMP RIG HEALTH & MAINTENANCE REPORT',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      data.bikeName,
                      style: const pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (data.odometerKm != null && data.odometerKm! > 0) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Odometer: ${data.odometerKm} km',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'REPORT DATE',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        dateStr,
                        style: const pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 14),

            // Summary of items
            pw.Text(
              'INSPECTION & SERVICE ITEMS (${assignedItems.length})',
              style: const pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 8),

            if (assignedItems.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                child: pw.Text(
                  'No maintenance items recorded for this vehicle.',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey600,
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                headers: [
                  'Component',
                  'Category',
                  'Status',
                  'Due / Schedule',
                  'Cost',
                  'Serviced By'
                ],
                data: assignedItems.map((item) {
                  return [
                    item.name,
                    item.category,
                    item.status.name.toUpperCase(),
                    item.dueMileage ?? item.dueDate ?? '-',
                    item.cost != null && item.cost! > 0
                        ? formatPkr(item.cost!)
                        : '-',
                    item.mechanicName ?? '-',
                  ];
                }).toList(),
              ),

            if (assignedVisits.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'SERVICE VISITS (${assignedVisits.length})',
                style: const pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                headers: ['Workshop / Mechanic', 'Date', 'Cost', 'Notes'],
                data: assignedVisits.map((v) {
                  return [
                    v.shopName,
                    v.formattedDateTime,
                    v.cost != null && v.cost! > 0 ? formatPkr(v.cost!) : '-',
                    v.note ?? '-',
                  ];
                }).toList(),
              ),
            ],

            // Separate section for records not assigned to a bike
            if (unassignedItems.isNotEmpty || unassignedVisits.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Text(
                'NOT ASSIGNED TO A BIKE',
                style: const pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 8),
              if (unassignedItems.isNotEmpty)
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: const pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey600,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  headers: [
                    'Component',
                    'Category',
                    'Status',
                    'Due / Schedule',
                    'Cost',
                    'Serviced By'
                  ],
                  data: unassignedItems.map((item) {
                    return [
                      item.name,
                      item.category,
                      item.status.name.toUpperCase(),
                      item.dueMileage ?? item.dueDate ?? '-',
                      item.cost != null && item.cost! > 0
                          ? formatPkr(item.cost!)
                          : '-',
                      item.mechanicName ?? '-',
                    ];
                  }).toList(),
                ),
              if (unassignedVisits.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: const pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey600,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  headers: ['Workshop / Mechanic', 'Date', 'Cost', 'Notes'],
                  data: unassignedVisits.map((v) {
                    return [
                      v.shopName,
                      v.formattedDateTime,
                      v.cost != null && v.cost! > 0 ? formatPkr(v.cost!) : '-',
                      v.note ?? '-',
                    ];
                  }).toList(),
                ),
              ],
            ],

            pw.SizedBox(height: 24),
            pw.Text(
              'Generated by CAMP Motorcycle Expedition & Maintenance System.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfMetricBox({
    required String title,
    required String value,
    PdfColor? valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: valueColor ?? PdfColors.blueGrey900,
            ),
          ),
        ],
      ),
    );
  }

  /// Triggers PDF creation and opens system share dialog.
  /// Shows 'Nothing to export yet' SnackBar if data is empty.
  static Future<void> shareBudgetReport(
    BuildContext context,
    BudgetReportData data,
  ) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nothing to export yet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.darkCharcoal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final bytes = await buildBudgetPdf(data);
      final safeTripName =
          data.tripName.trim().replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'CAMP_Budget_Report_${safeTripName.isEmpty ? 'Trip' : safeTripName}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  /// Triggers PDF creation for maintenance checklist and opens system share dialog.
  /// Shows 'Nothing to export yet' SnackBar if data is empty.
  static Future<void> shareMaintenanceReport(
    BuildContext context,
    MaintenanceReportData data,
  ) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nothing to export yet',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.darkCharcoal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final bytes = await buildMaintenancePdf(data);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'CAMP_Maintenance_Report.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }
}
