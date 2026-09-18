import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
import 'package:lawn_estimator/models/models.dart';

void main() {
  group('draft auto-save round-trip (v7)', () {
    EstimateDraft sampleDraft() {
      return EstimateDraft(
        addressLabel: '123 Main St',
        placeId: 'place-1',
        centerLat: 38.5,
        centerLng: -121.7,
        zones: const [
          [
            LatLng(38.5, -121.7),
            LatLng(38.5001, -121.7),
            LatLng(38.5001, -121.7001),
          ],
        ],
        activeZone: 0,
        photoPath: '/tmp/photo.jpg',
        note: 'gate code 1234',
        internalNote: 'internal',
        displayNote: 'display',
        confirmed: true,
        materials: [
          MaterialEstimate(
            id: 'm1',
            estimateId: 'e1',
            materialType: 'mowing',
            ratePer1000: 10,
            exactQuantity: 12,
            purchaseUnits: 12,
            updatedAt: DateTime(2026, 9, 18),
          ),
        ],
        lineItems: [
          LineItem(
            id: 'l1',
            estimateId: 'e1',
            service: 'Mowing',
            quantity: 12,
            unit: '1k ft2',
            unitPrice: '10.00',
            rateSource: 'owner',
            extendedAmount: 120,
            note: 'Mow height 3.5" - 12,000 ft2 @ \$10/1k ft2',
            updatedAt: DateTime(2026, 9, 18),
          ),
        ],
      );
    }

    test('toMap/fromMap preserves every field', () {
      final draft = sampleDraft();
      final restored = EstimateDraft.fromMap(draft.toMap());
      expect(restored, isNotNull);
      expect(restored!.addressLabel, '123 Main St');
      expect(restored.placeId, 'place-1');
      expect(restored.centerLat, 38.5);
      expect(restored.centerLng, -121.7);
      expect(restored.zones.length, 1);
      expect(restored.zones.first.length, 3);
      expect(restored.zones.first.first.latitude, 38.5);
      expect(restored.zones.first.first.longitude, -121.7);
      expect(restored.activeZone, 0);
      expect(restored.photoPath, '/tmp/photo.jpg');
      expect(restored.note, 'gate code 1234');
      expect(restored.internalNote, 'internal');
      expect(restored.displayNote, 'display');
      expect(restored.confirmed, isTrue);
      expect(restored.materials.length, 1);
      expect(restored.materials.first.materialType, 'mowing');
      expect(restored.lineItems.length, 1);
      expect(restored.lineItems.first.note, contains('Mow height 3.5"'));
    });

    test('resumeRoute survives the toMap/fromMap round-trip', () {
      final draft = sampleDraft().copyWith(resumeRoute: '/summary');
      final restored = EstimateDraft.fromMap(draft.toMap());
      expect(restored, isNotNull);
      expect(restored!.resumeRoute, '/summary');
      // Old payloads without the key still restore fine.
      final legacy = Map<String, dynamic>.from(draft.toMap())
        ..remove('resumeRoute');
      expect(EstimateDraft.fromMap(legacy)!.resumeRoute, isNull);
    });

    test('corrupt payload returns null instead of throwing', () {
      expect(EstimateDraft.fromMap(const {'zones': 'not-a-list'}), isNull);
      expect(EstimateDraft.fromMap(const {}), isNotNull);
    });

    test('hasContent is false for a fresh draft', () {
      expect(const EstimateDraft().hasContent, isFalse);
    });

    test('hasContent is true for address, vertices, photo, or items', () {
      expect(
        const EstimateDraft(addressLabel: '123 Main St').hasContent,
        isTrue,
      );
      expect(
        const EstimateDraft(
          zones: [
            [LatLng(1, 2)]
          ],
        ).hasContent,
        isTrue,
      );
      expect(
        const EstimateDraft(photoPath: '/tmp/x.jpg').hasContent,
        isTrue,
      );
      expect(
        EstimateDraft(
          lineItems: [
            LineItem(
              id: 'l1',
              estimateId: 'e1',
              service: 'Mowing',
              quantity: 12,
              unit: '1k ft2',
              unitPrice: '10.00',
              rateSource: 'owner',
              extendedAmount: 35,
              updatedAt: DateTime(2026, 9, 18),
            ),
          ],
        ).hasContent,
        isTrue,
      );
    });
  });

  group('mowing line item note (v6)', () {
    test('cut height is documented in the line item note', () {
      final item = LineItem(
        id: 'l1',
        estimateId: 'e1',
        service: 'Mowing',
        quantity: 12,
        unit: '1k ft2',
        unitPrice: '10.00',
        rateSource: 'owner',
        extendedAmount: 120,
        note: 'Mow height 3.5" - 12,000 ft2 @ \$10/1k ft2',
        updatedAt: DateTime(2026, 9, 18),
      );
      expect(item.note, contains('3.5"'));
      final restored = LineItem.fromMap(item.toMap());
      expect(restored.note, contains('3.5"'));
    });
  });
}
