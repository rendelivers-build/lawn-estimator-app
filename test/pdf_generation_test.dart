import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lawn_estimator/features/print/estimate_pdf.dart';
import 'package:lawn_estimator/models/models.dart';

EstimateFull _sampleFull() {
  final now = DateTime(2026, 9, 22);
  return EstimateFull(
    estimate: Estimate(
      id: 'pdf-check-1',
      name: '123 no name nowhere',
      addressLabel: '123 no name nowhere',
      centerLat: 47.6,
      centerLng: -122.3,
      areaFt2: 5000,
      createdAt: now,
      updatedAt: now,
    ),
    zones: const [],
    verticesByZone: const {},
    materials: [
      MaterialEstimate(
        id: 'mat-1',
        estimateId: 'pdf-check-1',
        materialType: 'sod',
        exactQuantity: 2800.7,
        purchaseUnits: 7,
        updatedAt: now,
      ),
    ],
    lineItems: [
      LineItem(
        id: 'li-1',
        estimateId: 'pdf-check-1',
        service: 'Labor',
        quantity: 4.5,
        unit: 'man-hr',
        unitPrice: '125.00',
        rateSource: 'owner',
        extendedAmount: 562.50,
        note: '6 workers x 0.75 hrs',
        updatedAt: now,
      ),
    ],
  );
}

void main() {
  test('generated estimate PDF is structurally valid', () async {
    final Uint8List bytes = await buildEstimatePdf(
      _sampleFull(),
      company: const CompanyProfile(businessName: 'Nowhere Lawn Care'),
    );

    // Must be a non-trivial PDF: header, body, cross-reference, trailer.
    expect(bytes.length, greaterThan(2000));
    final String head = ascii.decode(bytes.sublist(0, 8));
    expect(head.startsWith('%PDF-'), isTrue, reason: 'missing PDF header');

    // Trailer must end with %%EOF (allow trailing whitespace/newline).
    final String tail = ascii
        .decode(bytes.sublist(bytes.length - 32))
        .trimRight();
    expect(tail.endsWith('%%EOF'), isTrue, reason: 'missing EOF marker');

    final String text = ascii.decode(bytes, allowInvalid: true);
    expect(text.contains('/Type /Page'), isTrue, reason: 'no pages');
    // dart_pdf writes cross-reference streams (/XRef), not classic xref tables.
    expect(
      text.contains('xref') || text.contains('/XRef'),
      isTrue,
      reason: 'no cross-references',
    );

    // Dump a copy for manual inspection when needed.
    // ignore: avoid_print
    print('PDF OK: ${bytes.length} bytes, header=$head');
  });
}
