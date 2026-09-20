import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lawn_estimator/features/estimates/estimates_screen.dart';
import 'package:lawn_estimator/features/measure/measure_screen.dart';
import 'package:lawn_estimator/features/settings/tutorial_screen.dart';
import 'package:lawn_estimator/models/models.dart';

/// V11: "Edit area" flows and the locked tutorial wording.
///
/// The edit-area flows (long-press the address card on the summary screen,
/// or "Edit area" in the saved-estimates long-press menu) must carry the
/// whole saved estimate back into the draft — prices, quantities, labor,
/// notes, materials, photo, address, and zones — and record
/// [editingEstimateId] so saving replaces the original instead of
/// duplicating it.
EstimateFull _sampleFull() {
  final now = DateTime(2026, 9, 20);
  return EstimateFull(
    estimate: Estimate(
      id: 'est-1',
      name: '123 Main St',
      addressLabel: '123 Main St',
      placeId: 'place-1',
      centerLat: 38.5,
      centerLng: -121.7,
      areaFt2: 5000,
      confirmationStatus: ConfirmationStatus.confirmed,
      photoPath: '/photos/lawn.jpg',
      note: 'gate code 1234',
      internalNote: 'owner-only note',
      displayNote: 'customer note',
      createdAt: now,
      updatedAt: now,
    ),
    zones: const [
      LawnZone(
        id: 'z1',
        estimateId: 'est-1',
        label: 'Zone 1',
        sequence: 0,
        areaM2: 464.5,
      ),
    ],
    verticesByZone: const {
      'z1': [
        Vertex(
          id: 'v1',
          zoneId: 'z1',
          sequence: 0,
          latitude: 38.5,
          longitude: -121.7,
        ),
        Vertex(
          id: 'v2',
          zoneId: 'z1',
          sequence: 1,
          latitude: 38.5001,
          longitude: -121.7,
        ),
        Vertex(
          id: 'v3',
          zoneId: 'z1',
          sequence: 2,
          latitude: 38.5001,
          longitude: -121.7001,
        ),
      ],
    },
    materials: [
      MaterialEstimate(
        id: 'm1',
        estimateId: 'est-1',
        materialType: 'fertilizer',
        ratePer1000: 3.0,
        exactQuantity: 15,
        purchaseUnits: 1,
        updatedAt: now,
      ),
    ],
    lineItems: [
      LineItem(
        id: 'l1',
        estimateId: 'est-1',
        service: 'mowing',
        quantity: 5,
        unit: '1k ft2',
        unitPrice: '45.00',
        rateSource: 'owner',
        extendedAmount: 225,
        updatedAt: now,
      ),
      LineItem(
        id: 'l2',
        estimateId: 'est-1',
        service: 'labor',
        quantity: 6,
        unit: 'man-hr',
        unitPrice: '35',
        rateSource: 'owner',
        extendedAmount: 210,
        note: '2 workers x 3 hrs',
        updatedAt: now,
      ),
    ],
  );
}

void main() {
  group('buildEditDraft (Edit + Edit area flows)', () {
    test('records editingEstimateId so saving replaces the original', () {
      final draft = buildEditDraft(_sampleFull(), 'est-1');
      expect(draft.editingEstimateId, 'est-1');
    });

    test('preserves address, center, photo, and notes', () {
      final draft = buildEditDraft(_sampleFull(), 'est-1');
      expect(draft.addressLabel, '123 Main St');
      expect(draft.placeId, 'place-1');
      expect(draft.centerLat, 38.5);
      expect(draft.centerLng, -121.7);
      expect(draft.photoPath, '/photos/lawn.jpg');
      expect(draft.note, 'gate code 1234');
      expect(draft.internalNote, 'owner-only note');
      expect(draft.displayNote, 'customer note');
      expect(draft.confirmed, isTrue);
    });

    test('preserves the drawn zones as map-ready vertex rings', () {
      final draft = buildEditDraft(_sampleFull(), 'est-1');
      expect(draft.zones.length, 1);
      expect(draft.zones[0].length, 3);
      expect(draft.zones[0][0], const LatLng(38.5, -121.7));
      // The outline is real geometry: it measures a non-zero area.
      expect(draft.totalAreaFt2, greaterThan(0));
    });

    test('preserves materials, prices, quantities, and labor lines', () {
      final draft = buildEditDraft(_sampleFull(), 'est-1');
      expect(draft.materials.length, 1);
      expect(draft.materials[0].materialType, 'fertilizer');
      expect(draft.materials[0].exactQuantity, 15);

      expect(draft.lineItems.length, 2);
      final mowing = draft.lineItems[0];
      expect(mowing.service, 'mowing');
      expect(mowing.quantity, 5);
      expect(mowing.unitPrice, '45.00');
      expect(mowing.rateSource, 'owner');
      final labor = draft.lineItems[1];
      expect(labor.service, 'labor');
      expect(labor.quantity, 6);
      expect(labor.note, '2 workers x 3 hrs');
    });

    test('falls back to one empty zone when the estimate has none', () {
      final full = _sampleFull();
      final empty = EstimateFull(
        estimate: full.estimate,
        zones: const [],
        verticesByZone: const {},
        materials: const [],
        lineItems: const [],
      );
      final draft = buildEditDraft(empty, 'est-1');
      expect(draft.zones, hasLength(1));
      expect(draft.zones[0], isEmpty);
    });
  });

  group('areaEditExit ("Use this area" routing)', () {
    test('normal flow continues to the confirm screen', () {
      expect(areaEditExit(null), AreaEditExit.toConfirm);
    });

    test('edit-area from the summary pops back to the caller', () {
      expect(areaEditExit(const EditAreaArgs()), AreaEditExit.popToCaller);
    });

    test('edit-area from the saved list replaces with the summary', () {
      expect(
        areaEditExit(const EditAreaArgs(returnToSummary: true)),
        AreaEditExit.replaceWithSummary,
      );
    });
  });

  group('tutorial wording (locked)', () {
    test('uses "Hold pins to move" verbatim', () {
      final bodies = tutorialPages.map((p) => p.body).join('\n');
      expect(bodies, contains('Hold pins to move'));
    });
  });
}
