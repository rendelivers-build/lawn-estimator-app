/// Customer-ready PDF estimate generation.
///
/// Builds a clean, printable estimate document from an [EstimateFull] using
/// the `pdf` package. The button widget in [estimate_print_button.dart] is the
/// cross-module entry point; this file is the pure document builder.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:lawn_estimator/models/models.dart';
import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds the customer-facing estimate PDF.
///
/// Returns the PDF bytes, ready for [Printing.sharePdf] / [Printing.layoutPdf].
/// A missing or unreadable photo never fails generation — the thumbnail is
/// simply omitted.
Future<Uint8List> buildEstimatePdf(
  EstimateFull full, {
  CompanyProfile? company,
}) async {
  final estimate = full.estimate;
  final photo = _loadPhotoImage(estimate.photoPath);

  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => _buildHeader(company, estimate, photo),
      footer: (context) => _buildFooter(context),
      build: (_) => [
        _buildJobSection(estimate, full.zones.length),
        pw.SizedBox(height: 16),
        _buildLineItemsTable(full.lineItems, full.total),
        pw.SizedBox(height: 16),
        _buildMaterialsBox(full.materials),
      ],
    ),
  );

  return doc.save();
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

/// "\$1,234.50" style money. Accepts num so int/double both work.
String _formatMoney(num value) => '\$${value.toDouble().toStringAsFixed(2)}';

/// Quantity without pointless trailing zeros: 2.0 -> "2", 2.50 -> "2.5".
String _formatQty(num value) {
  final text = value.toDouble().toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// "Sep 15, 2026".
String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';

const List<String> _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Rounds to whole ft² with thousands separators: 12345.6 -> "12,346".
String _formatWhole(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// "5,000 ft² (556 yd² / 0.11 acres)".
String _formatArea(num ft2) {
  final yd2 = _formatWhole(ft2 / 9);
  final acres = (ft2 / 43560).toStringAsFixed(2);
  return '${_formatWhole(ft2)} ft² ($yd2 yd² / $acres acres)';
}

// ---------------------------------------------------------------------------
// Photo
// ---------------------------------------------------------------------------

/// Reads the job photo into a [pw.MemoryImage], or null when there is no
/// path, the file is missing/empty, or it cannot be decoded. Never throws.
pw.MemoryImage? _loadPhotoImage(String? path) {
  if (path == null || path.isEmpty) return null;
  try {
    final bytes = File(path).readAsBytesSync();
    if (bytes.isEmpty) return null;
    return pw.MemoryImage(bytes);
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

pw.Widget _buildHeader(
  CompanyProfile? company,
  Estimate estimate,
  pw.MemoryImage? photo,
) {
  // Letterhead lines under the business name; empty fields are skipped.
  final contactLines = <String>[];
  final profile = company;
  if (profile != null) {
    if (profile.street.isNotEmpty) contactLines.add(profile.street);
    if (profile.cityStateZip.isNotEmpty) {
      contactLines.add(profile.cityStateZip);
    }
    if (profile.phone.isNotEmpty) contactLines.add(profile.phone);
    if (profile.email.isNotEmpty) contactLines.add(profile.email);
  }
  final businessName = (profile?.businessName.isNotEmpty ?? false)
      ? profile!.businessName
      : 'Your Lawn Care Co.';

  return pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Business identity, left.
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                for (final line in contactLines) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    line,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                pw.SizedBox(height: 4),
                pw.Text(
                  'Lawn Care Estimate',
                  style: const pw.TextStyle(
                    fontSize: 13,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          // Date + optional job photo thumbnail, right-aligned.
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _formatDate(estimate.createdAt),
                style: const pw.TextStyle(fontSize: 11),
              ),
              if (photo != null) ...[
                pw.SizedBox(height: 8),
                pw.Image(photo, width: 120),
              ],
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 1.5),
    ],
  );
}

pw.Widget _buildJobSection(Estimate estimate, int zoneCount) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Job details',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      _jobRow('Address', estimate.addressLabel),
      _jobRow('Measured area', _formatArea(estimate.areaFt2)),
      _jobRow('Zones', '$zoneCount'),
    ],
  );
}

pw.Widget _jobRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}

pw.Widget _buildLineItemsTable(List<LineItem> items, num total) {
  const headerStyle = pw.TextStyle(
    fontSize: 11,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.white,
  );
  const cellStyle = pw.TextStyle(fontSize: 11);

  pw.Widget headerCell(String text, {bool right = false}) => pw.Container(
        color: PdfColors.grey800,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(text, style: headerStyle),
      );

  pw.Widget bodyCell(String text, {bool right = false, bool bold = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: cellStyle.copyWith(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  final rows = <pw.TableRow>[
    pw.TableRow(children: [
      headerCell('Service'),
      headerCell('Qty', right: true),
      headerCell('Unit'),
      headerCell('Unit price', right: true),
      headerCell('Amount', right: true),
    ]),
  ];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final striped = i.isOdd;
    final bg = striped ? PdfColors.grey100 : null;
    // unitPrice is stored as a String; parse defensively for display.
    final unitPriceValue = double.tryParse(item.unitPrice) ?? 0;
    final unitPrice = _formatMoney(unitPriceValue);
    // The note carries the labor workers × hours breakdown (and any user
    // notation); zero-dollar lines print in full, never hidden.
    final serviceText = (item.note == null || item.note!.isEmpty)
        ? serviceLabel(item.service)
        : '${serviceLabel(item.service)}\n${item.note!}';
    rows.add(
      pw.TableRow(
        decoration: bg == null ? null : pw.BoxDecoration(color: bg),
        children: [
          bodyCell(serviceText),
          bodyCell(_formatQty(item.quantity), right: true),
          bodyCell(item.unit),
          bodyCell(unitPrice, right: true),
          bodyCell(_formatMoney(item.extendedAmount), right: true),
        ],
      ),
    );
  }

  final subtotal =
      items.fold<double>(0, (sum, item) => sum + item.extendedAmount.toDouble());

  rows.addAll([
    pw.TableRow(children: [
      bodyCell(''),
      bodyCell(''),
      bodyCell(''),
      bodyCell('Subtotal', right: true, bold: true),
      bodyCell(_formatMoney(subtotal), right: true, bold: true),
    ]),
    pw.TableRow(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 1.5)),
      ),
      children: [
        bodyCell(''),
        bodyCell(''),
        bodyCell(''),
        bodyCell('Total', right: true, bold: true),
        bodyCell(_formatMoney(total), right: true, bold: true),
      ],
    ),
  ]);

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FlexColumnWidth(1.2),
      2: pw.FlexColumnWidth(1.4),
      3: pw.FlexColumnWidth(2),
      4: pw.FlexColumnWidth(2),
    },
    children: rows,
  );
}

// ---------------------------------------------------------------------------
// Materials reference box
// ---------------------------------------------------------------------------

/// Local label/unit mapping for material types. [unit] is the unit of the
/// exact calculated quantity; [purchaseUnit], when set, is the unit of the
/// buy quantity (e.g. weed & feed is calculated in lb but bought in bags).
/// Unknown types fall back to a title-cased version of the raw type with
/// no unit.
const Map<String, ({String label, String unit, String? purchaseUnit})>
    _materialLabels = {
  'seed_new': (label: 'Seed – new lawn', unit: 'lb', purchaseUnit: null),
  'seed_overseed': (label: 'Seed – overseed', unit: 'lb', purchaseUnit: null),
  'fertilizer': (label: 'Fertilizer', unit: 'lb', purchaseUnit: null),
  'lime': (label: 'Lime', unit: 'lb', purchaseUnit: null),
  'mulch': (label: 'Mulch', unit: 'cu yd', purchaseUnit: null),
  'sod': (label: 'Sod', unit: 'sq ft', purchaseUnit: null),
  'topsoil': (label: 'Topsoil', unit: 'cu yd', purchaseUnit: null),
  'herbicide': (label: 'Herbicide', unit: 'gal', purchaseUnit: null),
  'weed_control': (label: 'Weed control', unit: 'lb', purchaseUnit: null),
  'weed_feed': (label: 'Weed & feed', unit: 'lb', purchaseUnit: 'bags'),
};

String _materialLine(MaterialEstimate material) {
  final known = _materialLabels[material.materialType];
  final label = known?.label ?? _fallbackLabel(material.materialType);
  final unit = known?.unit ?? '';
  final purchaseUnit = known?.purchaseUnit;
  final qty = unit.isEmpty
      ? _formatQty(material.exactQuantity)
      : '${_formatQty(material.exactQuantity)} $unit';
  final buy = purchaseUnit == null || purchaseUnit.isEmpty
      ? _formatQty(material.purchaseUnits)
      : '${_formatQty(material.purchaseUnits)} $purchaseUnit';
  return '$label: $qty exact, buy $buy';
}

String _fallbackLabel(String raw) {
  final words = raw.replaceAll('_', ' ').split(' ');
  return words
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

pw.Widget _buildMaterialsBox(List<MaterialEstimate> materials) {
  if (materials.isEmpty) return pw.SizedBox.shrink();
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      color: PdfColors.grey50,
    ),
    padding: const pw.EdgeInsets.all(10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Materials (reference)',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        for (final material in materials)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('-  ', style: const pw.TextStyle(fontSize: 11)),
                pw.Expanded(
                  child: pw.Text(
                    _materialLine(material),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

pw.Widget _buildFooter(pw.Context context) {
  const small = pw.TextStyle(fontSize: 9, color: PdfColors.grey600);
  return pw.Column(
    children: [
      pw.Divider(thickness: 0.5),
      pw.Text(
        'Satellite outlines are estimates. Check the site and the product '
        'label before purchasing or applying material.',
        style: small,
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Thank you for your business!', style: small),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: small,
          ),
        ],
      ),
    ],
  );
}
