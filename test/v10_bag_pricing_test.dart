import 'package:flutter_test/flutter_test.dart';
import 'package:lawn_estimator/features/pricing/pricing_provider.dart';
import 'package:lawn_estimator/models/models.dart';

/// V10: granular materials are priced per lb in settings but billed by the
/// bag. The per-lb price must scale by the bag weight into a per-bag unit
/// price — billing bags × $/lb was the v9 defect.
void main() {
  group('materialUnitPrice', () {
    test('granular: per-lb price scales by bag weight into per-bag price',
        () {
      // $26 bag / 40 lb = $0.65/lb on the settings screen.
      expect(
        materialUnitPrice(
          resolvedPrice: 0.65,
          isGranular: true,
          bagLb: 40,
          markupPercent: 0,
        ),
        closeTo(26.0, 0.001),
      );
    });

    test('granular: markup applies on top of the per-bag price', () {
      // A $26 bag with 20% markup bills at $31.20.
      expect(
        materialUnitPrice(
          resolvedPrice: 0.65,
          isGranular: true,
          bagLb: 40,
          markupPercent: 20,
        ),
        closeTo(31.20, 0.001),
      );
    });

    test('sod passes the per-unit price through, markup on top', () {
      expect(
        materialUnitPrice(
          resolvedPrice: 45.0,
          isGranular: false,
          bagLb: 0,
          markupPercent: 10,
        ),
        closeTo(49.5, 0.001),
      );
    });
  });

  group('granular line item totals', () {
    test('one bag bills the full bag price', () {
      final item = LineItem.create(
        estimateId: '',
        service: 'seed_new',
        quantity: 1,
        unit: 'bags',
        unitPrice: '26.00',
        rateSource: 'owner',
      );
      expect(item.extendedAmount, closeTo(26.0, 0.001));
    });

    test('multiple bags bill bag count x per-bag price', () {
      final item = LineItem.create(
        estimateId: '',
        service: 'fertilizer',
        quantity: 3,
        unit: 'bags',
        unitPrice: '26.00',
        rateSource: 'owner',
      );
      expect(item.extendedAmount, closeTo(78.0, 0.001));
    });

    test('marked-up bag price extends correctly', () {
      final item = LineItem.create(
        estimateId: '',
        service: 'weed_feed',
        quantity: 5,
        unit: 'bags',
        unitPrice: '31.20',
        rateSource: 'owner',
      );
      expect(item.extendedAmount, closeTo(156.0, 0.001));
    });
  });
}
