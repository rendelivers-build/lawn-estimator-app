import 'package:flutter_test/flutter_test.dart';
import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:lawn_estimator/features/pricing/pricing_provider.dart';
import 'package:lawn_estimator/models/models.dart';

void main() {
  group('pricing catalog (v5)', () {
    test('every service has a blurb and frequency', () {
      for (final s in kPricingServices) {
        expect(s.blurb.isNotEmpty, isTrue, reason: s.id);
        expect(s.frequency.isNotEmpty, isTrue, reason: s.id);
      }
    });

    test('no service label contains PDF-unsafe dashes', () {
      for (final s in kPricingServices) {
        expect(s.label.contains('–'), isFalse, reason: s.id);
        expect(s.label.contains('—'), isFalse, reason: s.id);
      }
    });

    test('starter prices cover every catalog service', () {
      for (final s in kPricingServices) {
        expect(kStarterPrices[s.id], isNotNull, reason: s.id);
        expect(kStarterPrices[s.id]! > 0, isTrue, reason: s.id);
      }
    });

    test('serviceLabel resolves new services', () {
      expect(serviceLabel('mowing'), 'Mowing');
      expect(serviceLabel('aerate'), 'Aeration');
      expect(serviceLabel('top_dress'), 'Top dress');
      expect(serviceLabel('moss_mold_spray'),
          'Moss / mold control - spray');
      expect(serviceLabel('labor'), 'Labor');
    });
  });

  group('resolve() modes (v5)', () {
    PricingNotifier notifier() {
      final n = PricingNotifier();
      // ignore: invalid_use_of_protected_member
      n.state = {
        for (final s in kPricingServices)
          s.id: PricingSettings(
            service: s.id,
            unit: s.unit,
            updatedAt: DateTime.now(),
          ),
      };
      return n;
    }

    test('beginner falls back to starter price, never bare zero', () {
      final n = notifier();
      for (final s in kPricingServices) {
        final r = n.resolve(s.id, mode: 'beginner');
        expect(r.source, 'starter', reason: s.id);
        expect(r.price > 0, isTrue, reason: s.id);
      }
    });

    test('expert falls back to the generic reference rate too', () {
      final n = notifier();
      final r = n.resolve('mowing', mode: 'expert');
      expect(r.source, 'starter');
      expect(r.price > 0, isTrue);
    });

    test('owner price still wins in both modes', () {
      final n = notifier();
      // ignore: invalid_use_of_protected_member
      final current = n.state['mowing']!;
      // ignore: invalid_use_of_protected_member
      n.state = {
        ...n.state,
        'mowing': PricingSettings(
          service: 'mowing',
          unit: current.unit,
          ownerPrice: 99,
          updatedAt: DateTime.now(),
        ),
      };
      expect(n.resolve('mowing', mode: 'beginner').source, 'owner');
      expect(n.resolve('mowing', mode: 'expert').source, 'owner');
    });
  });

  group('Estimate notes (v5)', () {
    test('internal/display notes round-trip through toMap/fromMap', () {
      final now = DateTime.now();
      final e = Estimate(
        id: 'x',
        name: 'n',
        addressLabel: 'a',
        centerLat: 1,
        centerLng: 2,
        areaFt2: 3,
        internalNote: 'crew: gate code 1234',
        displayNote: 'Spring cleanup included',
        createdAt: now,
        updatedAt: now,
      );
      final back = Estimate.fromMap(e.toMap());
      expect(back.internalNote, 'crew: gate code 1234');
      expect(back.displayNote, 'Spring cleanup included');
    });
  });
}
