/// Riverpod state for the owner's pricing.
///
/// Holds one [PricingSettings] per service id from
/// [kPricingServices]. The owner's own price always wins; when it is
/// unset, the area default fills in as a reference rate. Every change is
/// persisted through [EstimateRepository.savePricing].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/models/models.dart';

/// A resolved price for a service plus where it came from.
///
/// [source] is one of:
/// - `'owner'` — the owner set their own price;
/// - `'area_default'` — the area default reference rate;
/// - `'starter'` — the built-in beginner-mode starter price (used only
///   when [mode] is Beginner and no owner or area-default price exists);
/// - `'none'` — nothing set (expert mode with no owner price).
class ResolvedRate {
  final double price;
  final String source;

  const ResolvedRate(this.price, this.source);
}

/// Holds the pricing settings map keyed by service id.
class PricingNotifier extends StateNotifier<Map<String, PricingSettings>> {
  PricingNotifier() : super({});

  /// Loads saved pricing, then makes sure every service in
  /// [kPricingServices] has an entry (creating one with the catalog unit
  /// when the repository has never seen it).
  Future<void> load() async {
    final saved = await EstimateRepository().loadPricing();
    final map = <String, PricingSettings>{
      for (final settings in saved) settings.service: settings,
    };
    for (final service in kPricingServices) {
      map.putIfAbsent(
        service.id,
        () => PricingSettings(
          service: service.id,
          unit: service.unit,
          updatedAt: DateTime.now(),
        ),
      );
    }
    state = map;
  }

  /// Resolves the effective price for [service].
  ///
  /// Owner price wins. Failing that, the area default. Failing that, the
  /// built-in starter price when [mode] is Beginner — so a beginner never
  /// faces a `$0` default. In Expert mode there is no starter fallback:
  /// the owner is expected to enter every price themselves, so unset
  /// pricing reports source `'none'` (and price 0.0).
  ResolvedRate resolve(String service, {String mode = 'beginner'}) {
    final settings = state[service];
    final owner = settings?.ownerPrice;
    if (owner != null) return ResolvedRate(owner, 'owner');
    final areaDefault = settings?.areaDefaultPrice;
    if (areaDefault != null) return ResolvedRate(areaDefault, 'area_default');
    if (mode == 'expert') return const ResolvedRate(0.0, 'none');
    final starter = kStarterPrices[service];
    if (starter != null) return ResolvedRate(starter, 'starter');
    return const ResolvedRate(0.0, 'area_default');
  }

  /// Sets (or clears, with null) the owner's own price for [service].
  ///
  /// Built with the constructor rather than [PricingSettings.copyWith]
  /// because the generated copyWith cannot clear a field back to null
  /// (null means "keep the old value" there).
  Future<void> setOwnerPrice(String service, double? price) async {
    final current = state[service];
    if (current == null) return;
    state = {
      ...state,
      service: PricingSettings(
        service: current.service,
        unit: current.unit,
        ownerPrice: price,
        areaDefaultPrice: current.areaDefaultPrice,
        updatedAt: DateTime.now(),
      ),
    };
    await _persist();
  }

  /// Sets (or clears, with null) the area-default reference price.
  Future<void> setAreaDefault(String service, double? price) async {
    final current = state[service];
    if (current == null) return;
    state = {
      ...state,
      service: PricingSettings(
        service: current.service,
        unit: current.unit,
        ownerPrice: current.ownerPrice,
        areaDefaultPrice: price,
        updatedAt: DateTime.now(),
      ),
    };
    await _persist();
  }

  Future<void> _persist() =>
      EstimateRepository().savePricing(state.values.toList());
}

/// Pricing settings for every service, keyed by service id.
final pricingProvider =
    StateNotifierProvider<PricingNotifier, Map<String, PricingSettings>>(
  (ref) => PricingNotifier()..load(),
);
