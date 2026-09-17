/// Catalog of every billable service the estimator can price.
///
/// This is the single source of truth for service identifiers. Pricing
/// settings, the materials screen, and the estimate summary all key off
/// these stable IDs.
///
/// [unit] is the pricing unit shown next to prices (per ft², per lb,
/// per job). Line items for materials are sold in different purchase
/// units ('bags', 'units') — those are decided where the line item is
/// built, not here.
library;

/// One billable service: a material or labor.
class PricingService {
  /// Stable key stored in pricing settings and line items.
  final String id;

  /// Human-readable name shown in the UI.
  final String label;

  /// Pricing unit, e.g. 'ft²', 'lb', 'job'.
  final String unit;

  const PricingService({
    required this.id,
    required this.label,
    required this.unit,
  });
}

/// Every service the estimator can price.
///
/// The five material services line up with the materials screen. `labor`
/// is added from the summary screen as a single job line.
const List<PricingService> kPricingServices = [
  PricingService(id: 'sod', label: 'Sod / turf', unit: 'ft²'),
  PricingService(id: 'seed_new', label: 'Seed – new lawn', unit: 'lb'),
  PricingService(id: 'seed_overseed', label: 'Seed – overseed', unit: 'lb'),
  PricingService(id: 'fertilizer', label: 'Fertilizer', unit: 'lb'),
  PricingService(id: 'weed_feed', label: 'Weed & feed', unit: 'lb'),
  PricingService(id: 'labor', label: 'Labor', unit: 'job'),
];

/// Human-readable label for a service [id].
///
/// Falls back to the id itself for unknown ids so the UI never renders
/// a blank label.
String serviceLabel(String id) {
  for (final service in kPricingServices) {
    if (service.id == id) return service.label;
  }
  return id;
}
