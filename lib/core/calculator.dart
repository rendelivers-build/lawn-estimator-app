/// Pure material math for the lawn estimator.
///
/// No Flutter imports here — these functions are unit-testable in plain
/// Dart. All areas are in square feet (ft²), all weights in pounds (lb),
/// US customary units throughout.
///
/// The starter defaults below are generic starting points only, NOT
/// product recommendations. The UI labels them as such and tells the
/// user to check the product label.
library;

/// Validates that [v] is a positive, finite number.
///
/// Returns [v] unchanged when valid; throws [ArgumentError] otherwise.
/// Used to guard divisors (coverage, bag size, application rates) before
/// any division happens.
double requirePositive(double v, String name) {
  if (v.isNaN || v.isInfinite || v <= 0) {
    throw ArgumentError.value(v, name, 'must be a positive number');
  }
  return v;
}

/// Result of a sod order calculation.
class SodResult {
  /// Total ft² to order, including the waste allowance.
  final double orderAreaFt2;

  /// Whole sod units (rolls/pallets) to buy, rounded up.
  final int units;

  const SodResult({required this.orderAreaFt2, required this.units});
}

/// Calculates how much sod to order.
///
/// Formula: `orderArea = areaFt2 * (1 + wastePercent / 100)`, then
/// `units = ceil(orderArea / unitCoverageFt2)`.
///
/// Throws [ArgumentError] when [unitCoverageFt2] is not positive.
SodResult calcSod({
  required double areaFt2,
  required double wastePercent,
  required double unitCoverageFt2,
}) {
  requirePositive(unitCoverageFt2, 'unitCoverageFt2');
  final orderArea = areaFt2 * (1 + wastePercent / 100);
  final units = (orderArea / unitCoverageFt2).ceil();
  return SodResult(orderAreaFt2: orderArea, units: units);
}

/// Result of a granular (seed / fertilizer / weed & feed) calculation.
class GranularResult {
  /// Exact pounds needed for the area at the given rate.
  final double pounds;

  /// Whole bags to buy, rounded up.
  final int bags;

  const GranularResult({required this.pounds, required this.bags});
}

/// Calculates granular material (seed, fertilizer, weed & feed).
///
/// Formula: `pounds = areaFt2 / 1000 * ratePer1000`, then
/// `bags = ceil(pounds / bagLb)`.
///
/// Throws [ArgumentError] when [ratePer1000] or [bagLb] is not positive.
GranularResult calcGranular({
  required double areaFt2,
  required double ratePer1000,
  required double bagLb,
}) {
  requirePositive(ratePer1000, 'ratePer1000');
  requirePositive(bagLb, 'bagLb');
  final pounds = areaFt2 / 1000 * ratePer1000;
  final bags = (pounds / bagLb).ceil();
  return GranularResult(pounds: pounds, bags: bags);
}

// ---------------------------------------------------------------------------
// Starter defaults — generic starting points, NOT product recommendations.
// The UI must label them as such ("check the product label").
// ---------------------------------------------------------------------------

/// Waste allowance (%) added on top of the measured area for sod.
const double sodWastePercent = 10.0;

/// Generic coverage of one sod unit (roll/pallet), in ft².
/// Editable in the UI; kept here so the materials screen has a starting value.
const double sodUnitCoverageFt2 = 450.0;

/// Seed for a new lawn: lb per 1,000 ft².
const double seedNewRate = 5.0;

/// Seed for a new lawn: lb per bag.
const double seedNewBag = 25.0;

/// Overseed: lb per 1,000 ft².
const double overseedRate = 3.0;

/// Overseed: lb per bag.
const double overseedBag = 25.0;

/// Fertilizer: lb per 1,000 ft².
const double fertilizerRate = 3.0;

/// Fertilizer: lb per bag.
const double fertilizerBag = 15.0;

/// Weed & feed: lb per 1,000 ft².
const double weedFeedRate = 3.0;

/// Weed & feed: lb per bag.
const double weedFeedBag = 15.0;
