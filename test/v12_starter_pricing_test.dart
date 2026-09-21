import 'package:flutter_test/flutter_test.dart';
import 'package:lawn_estimator/core/calculator.dart';
import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:lawn_estimator/features/pricing/pricing_provider.dart';

/// V12: granular starter prices are PER LB (the pricing screen labels them
/// "per lb" and materialUnitPrice scales them by the bag weight into a
/// per-bag line item). A regression shipped per-BAG values ($42, $28, $32)
/// in the per-lb field, billing seed at $1,050/bag. These tests pin the
/// starter values to sane per-lb prices.
void main() {
  group('granular starter prices are per-lb, not per-bag', () {
    const granular = {
      'seed_new': seedNewBag,
      'seed_overseed': overseedBag,
      'fertilizer': fertilizerBag,
      'weed_feed': weedFeedBag,
    };

    for (final entry in granular.entries) {
      test('${entry.key}: starter is a sane per-lb price', () {
        final perLb = kStarterPrices[entry.key]!;
        // No granular lawn product retails above $10/lb.
        expect(perLb, lessThan(10.0), reason: entry.key);
        expect(perLb, greaterThan(0), reason: entry.key);
      });

      test('${entry.key}: starter scales to a sane per-bag price', () {
        final perBag = materialUnitPrice(
          resolvedPrice: kStarterPrices[entry.key]!,
          isGranular: true,
          bagLb: entry.value,
          markupPercent: 0,
        );
        // A single bag of seed/fertilizer/weed & feed retails well under $200.
        expect(perBag, lessThan(200.0), reason: entry.key);
      });
    }

    test('seed starter matches a ~\$42 / 25 lb bag', () {
      final perBag = materialUnitPrice(
        resolvedPrice: kStarterPrices['seed_new']!,
        isGranular: true,
        bagLb: seedNewBag,
        markupPercent: 0,
      );
      expect(perBag, closeTo(42.0, 1.0));
    });
  });
}
