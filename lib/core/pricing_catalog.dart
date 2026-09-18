/// Catalog of every billable service the estimator can price.
///
/// This is the single source of truth for service identifiers. Pricing
/// settings, the materials screen, and the estimate summary all key off
/// these stable IDs.
///
/// [unit] is the pricing unit shown next to prices (per ft², per lb,
/// per job). Line items for materials are sold in different purchase
/// units ('bags', 'units/pallets') — those are decided where the line
/// item is built, not here.
///
/// [blurb] is a plain-language explanation of the service and [frequency]
/// says how often it should be done; both feed the info bubbles in the UI.
library;

/// One billable service: a material or a job-site service.
class PricingService {
  /// Stable key stored in pricing settings and line items.
  final String id;

  /// Human-readable name shown in the UI.
  final String label;

  /// Pricing unit, e.g. 'ft²', 'lb', '1k ft²'.
  final String unit;

  /// Plain-language explanation shown in the info bubble.
  final String blurb;

  /// How often the service should be done, shown in the info bubble.
  final String frequency;

  const PricingService({
    required this.id,
    required this.label,
    required this.unit,
    required this.blurb,
    required this.frequency,
  });
}

/// Every service the estimator can price.
///
/// The five material services line up with the materials screen. Mowing
/// and the expert services (aeration, dethatch, top dress, moss/mold)
/// are added from the summary screen's "Add service" sheet. Labor is
/// added from the summary screen via the labor dialog, whose man-hour rate
/// comes from the company profile — labor intentionally has no pricing
/// row here so there is exactly one labor-rate source.
const List<PricingService> kPricingServices = [
  PricingService(
    id: 'sod',
    label: 'Sod / turf',
    unit: 'ft²',
    blurb: 'Fresh, living grass laid down in sections for an instant lawn.',
    frequency: 'Best installed in spring or early fall. '
        'Water daily for the first 2 weeks.',
  ),
  PricingService(
    id: 'seed_new',
    label: 'Seed - new lawn',
    unit: 'lb',
    blurb: 'Bare-dirt seeding for a brand-new lawn grown from scratch.',
    frequency: 'Seed in early fall or spring; keep it watered until established.',
  ),
  PricingService(
    id: 'seed_overseed',
    label: 'Seed - overseed',
    unit: 'lb',
    blurb: 'Fresh seed spread over existing grass to thicken thin or patchy areas.',
    frequency: 'Once a year, usually in the fall.',
  ),
  PricingService(
    id: 'fertilizer',
    label: 'Fertilizer',
    unit: 'lb',
    blurb: 'Food for the grass — greens it up and thickens growth.',
    frequency: '3–4 applications a year: spring, early summer, and fall.',
  ),
  PricingService(
    id: 'weed_feed',
    label: 'Weed & feed',
    unit: 'lb',
    blurb: 'Fertilizer plus weed killer in a single pass.',
    frequency: 'Spring, when weeds are young; a second pass in fall if needed.',
  ),
  PricingService(
    id: 'mowing',
    label: 'Mowing',
    unit: '1k ft²',
    blurb: 'Cutting the grass to a healthy, even height.',
    frequency: 'Every 1–2 weeks during the growing season.',
  ),
  PricingService(
    id: 'aerate',
    label: 'Aeration',
    unit: '1k ft²',
    blurb: 'Pulls small plugs of soil so air, water, and nutrients reach the roots.',
    frequency: 'Once a year, usually in the fall.',
  ),
  PricingService(
    id: 'dethatch',
    label: 'Dethatch',
    unit: '1k ft²',
    blurb: 'Tears out the matted dead layer (thatch) that chokes out healthy grass.',
    frequency: 'Once a year or every other year, in spring or fall.',
  ),
  PricingService(
    id: 'top_dress',
    label: 'Top dress',
    unit: '1k ft²',
    blurb: 'A thin layer of compost or soil spread over the lawn to level low spots and feed the soil.',
    frequency: 'Once or twice a year, usually in the spring.',
  ),
  PricingService(
    id: 'moss_mold_spray',
    label: 'Moss / mold control - spray',
    unit: '1k ft²',
    blurb: 'Liquid treatment sprayed on moss and mold patches.',
    frequency: 'Apply when you see it; shade and damp soil are the usual causes.',
  ),
  PricingService(
    id: 'moss_mold_granular',
    label: 'Moss / mold control - granular',
    unit: '1k ft²',
    blurb: 'Granular (peat-style) treatment spread over moss and mold patches.',
    frequency: 'Apply when you see it; re-check shady, damp areas.',
  ),
];

/// Starter prices used in Beginner mode when the owner hasn't set their own
/// price and no area default exists. Keyed by service id; the value is in
/// the service's purchase unit (per bag, per unit/pallet, per 1k ft²).
///
/// Generic starting points only, NOT market quotes — the UI labels them
/// as starter prices and the owner can override every one.
const Map<String, double> kStarterPrices = {
  'sod': 150.0,
  'seed_new': 42.0,
  'seed_overseed': 42.0,
  'fertilizer': 28.0,
  'weed_feed': 32.0,
  'mowing': 10.0,
  'aerate': 18.0,
  'dethatch': 22.0,
  'top_dress': 32.0,
  'moss_mold_spray': 14.0,
  'moss_mold_granular': 16.0,
};

/// Human-readable label for a service [id].
///
/// Unknown ids are title-cased (underscores become spaces) so the UI never
/// renders a raw code like `labor`.
String serviceLabel(String id) {
  for (final service in kPricingServices) {
    if (service.id == id) return service.label;
  }
  return id
      .split('_')
      .map((w) =>
          w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// The catalog entry for [id], or null when the id isn't a known service.
PricingService? serviceInfo(String id) {
  for (final service in kPricingServices) {
    if (service.id == id) return service;
  }
  return null;
}
