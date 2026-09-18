/// Materials screen: compute what to buy for each material and add the
/// chosen ones to the estimate draft as line items.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/core/calculator.dart';
import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
import 'package:lawn_estimator/features/pricing/pricing_provider.dart';
import 'package:lawn_estimator/features/settings/app_settings_provider.dart';
import 'package:lawn_estimator/features/shared/service_info_button.dart';
import 'package:lawn_estimator/models/models.dart';

/// Static config for one material card.
class _MaterialConfig {
  final String serviceId;
  final bool isSod;

  /// Starter default rate in lb per 1,000 ft² (granular materials only).
  final double defaultRate;

  /// Starter package size: lb per bag (granular) or ft² per sod unit.
  final double defaultPackage;

  /// Starter waste allowance % (sod only).
  final double defaultWaste;

  final String rateLabel;
  final String packageLabel;

  const _MaterialConfig({
    required this.serviceId,
    required this.isSod,
    required this.defaultRate,
    required this.defaultPackage,
    required this.defaultWaste,
    required this.rateLabel,
    required this.packageLabel,
  });
}

const List<_MaterialConfig> _materialConfigs = [
  _MaterialConfig(
    serviceId: 'sod',
    isSod: true,
    defaultRate: 0,
    defaultPackage: sodUnitCoverageFt2,
    defaultWaste: sodWastePercent,
    rateLabel: '',
    packageLabel: 'Coverage per unit (ft²)',
  ),
  _MaterialConfig(
    serviceId: 'seed_new',
    isSod: false,
    defaultRate: seedNewRate,
    defaultPackage: seedNewBag,
    defaultWaste: 0,
    rateLabel: 'Rate (lb per 1,000 ft²)',
    packageLabel: 'Bag size (lb)',
  ),
  _MaterialConfig(
    serviceId: 'seed_overseed',
    isSod: false,
    defaultRate: overseedRate,
    defaultPackage: overseedBag,
    defaultWaste: 0,
    rateLabel: 'Rate (lb per 1,000 ft²)',
    packageLabel: 'Bag size (lb)',
  ),
  _MaterialConfig(
    serviceId: 'fertilizer',
    isSod: false,
    defaultRate: fertilizerRate,
    defaultPackage: fertilizerBag,
    defaultWaste: 0,
    rateLabel: 'Rate (lb per 1,000 ft²)',
    packageLabel: 'Bag size (lb)',
  ),
  _MaterialConfig(
    serviceId: 'weed_feed',
    isSod: false,
    defaultRate: weedFeedRate,
    defaultPackage: weedFeedBag,
    defaultWaste: 0,
    rateLabel: 'Rate (lb per 1,000 ft²)',
    packageLabel: 'Bag size (lb)',
  ),
];

/// Live computation for one material card.
class _Calc {
  /// Exact amount needed (ft² with waste for sod, lb otherwise).
  final double exact;

  /// Whole purchase units to buy, rounded up (bags, or sod units).
  final int buy;

  final String exactText;
  final String buyText;
  final String? error;

  const _Calc({
    required this.exact,
    required this.buy,
    required this.exactText,
    required this.buyText,
    this.error,
  });
}

class MaterialsScreen extends ConsumerStatefulWidget {
  const MaterialsScreen({super.key});

  @override
  ConsumerState<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends ConsumerState<MaterialsScreen> {
  final Map<String, TextEditingController> _rateCtrls = {};
  final Map<String, TextEditingController> _packageCtrls = {};
  final Map<String, TextEditingController> _wasteCtrls = {};
  final Map<String, bool> _added = {};

  @override
  void initState() {
    super.initState();
    for (final cfg in _materialConfigs) {
      _rateCtrls[cfg.serviceId] =
          TextEditingController(text: _fmt(cfg.defaultRate));
      _packageCtrls[cfg.serviceId] =
          TextEditingController(text: _fmt(cfg.defaultPackage));
      _wasteCtrls[cfg.serviceId] =
          TextEditingController(text: _fmt(cfg.defaultWaste));
      _added[cfg.serviceId] = false;
    }
  }

  @override
  void dispose() {
    for (final c in [
      ..._rateCtrls.values,
      ..._packageCtrls.values,
      ..._wasteCtrls.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  /// Parses a field defensively, falling back to [fallback] on bad input.
  double _parse(TextEditingController ctrl, double fallback) {
    return double.tryParse(ctrl.text.trim()) ?? fallback;
  }

  _Calc _compute(_MaterialConfig cfg, double areaFt2) {
    if (cfg.isSod) {
      final coverage = _parse(_packageCtrls[cfg.serviceId]!, cfg.defaultPackage);
      final waste = _parse(_wasteCtrls[cfg.serviceId]!, 0.0);
      if (coverage <= 0) {
        return const _Calc(
          exact: 0,
          buy: 0,
          exactText: '—',
          buyText: '—',
          error: 'Enter a coverage greater than 0.',
        );
      }
      final result = calcSod(
        areaFt2: areaFt2,
        wastePercent: waste,
        unitCoverageFt2: coverage,
      );
      return _Calc(
        exact: result.orderAreaFt2,
        buy: result.units,
        exactText: '${result.orderAreaFt2.toStringAsFixed(0)} ft² (with waste)',
        buyText: '${result.units} units/pallets',
      );
    }
    final rate = _parse(_rateCtrls[cfg.serviceId]!, cfg.defaultRate);
    final bag = _parse(_packageCtrls[cfg.serviceId]!, cfg.defaultPackage);
    if (rate <= 0 || bag <= 0) {
      return const _Calc(
        exact: 0,
        buy: 0,
        exactText: '—',
        buyText: '—',
        error: 'Enter a rate and bag size greater than 0.',
      );
    }
    final result = calcGranular(
      areaFt2: areaFt2,
      ratePer1000: rate,
      bagLb: bag,
    );
    return _Calc(
      exact: result.pounds,
      buy: result.bags,
      exactText: '${result.pounds.toStringAsFixed(1)} lb',
      buyText: '${result.bags} bags',
    );
  }

  /// Builds the material estimates + line items for every toggled-on
  /// material, stores them on the draft, and moves to the summary.
  Future<void> _continue() async {
    final areaFt2 = ref.read(estimateDraftProvider).totalAreaFt2;
    final materials = <MaterialEstimate>[];
    final items = <LineItem>[];

    for (final cfg in _materialConfigs) {
      if (!(_added[cfg.serviceId] ?? false)) continue;
      final calc = _compute(cfg, areaFt2);
      if (calc.error != null) continue;

      // Purchase unit: sod is sold by the unit/pallet (roll/pallet),
      // granular materials by bag.
      final unitLabel = cfg.isSod ? 'units/pallets' : 'bags';
      final quantity = calc.buy.toDouble();
      final resolved = ref
          .read(pricingProvider.notifier)
          .resolve(cfg.serviceId, mode: ref.read(appSettingsProvider).mode);

      materials.add(MaterialEstimate.create(
        // The repository assigns the real estimate id on save; keep the
        // placeholder and let it overwrite this field.
        estimateId: '',
        materialType: cfg.serviceId,
        ratePer1000: cfg.isSod
            ? null
            : _parse(_rateCtrls[cfg.serviceId]!, cfg.defaultRate),
        packageSizeLb: cfg.isSod
            ? null
            : _parse(_packageCtrls[cfg.serviceId]!, cfg.defaultPackage),
        wastePercent:
            cfg.isSod ? _parse(_wasteCtrls[cfg.serviceId]!, 0.0) : null,
        unitCoverageFt2: cfg.isSod
            ? _parse(_packageCtrls[cfg.serviceId]!, cfg.defaultPackage)
            : null,
        exactQuantity: calc.exact,
        purchaseUnits: quantity,
      ));
      // LineItem.create derives extendedAmount from quantity × unitPrice.
      items.add(LineItem.create(
        estimateId: '',
        service: cfg.serviceId,
        quantity: quantity,
        unit: unitLabel,
        unitPrice: _fmt(resolved.price),
        rateSource: resolved.source,
      ));
    }

    // setMaterials is synchronous, so state is updated before navigating
    // and the summary sees fresh state.
    ref.read(estimateDraftProvider.notifier).setMaterials(materials, items);
    if (!mounted) return;
    Navigator.of(context).pushNamed('/summary');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(estimateDraftProvider);
    final areaFt2 = draft.totalAreaFt2;
    final anyAdded = _added.values.any((v) => v);

    return Scaffold(
      appBar: AppBar(title: const Text('Materials')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // Tap the lawn-area card to jump back to the map with the
              // same measurement.
              onTap: () => Navigator.of(context).popUntil(
                (route) => route.settings.name == '/measure',
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Lawn area: ${formatFt2(areaFt2)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const Icon(Icons.map_outlined),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Starter rates are generic — check the product label. '
                      'Tap to view on the map.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final cfg in _materialConfigs) _materialCard(cfg, areaFt2),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: anyAdded ? _continue : null,
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }

  Widget _materialCard(_MaterialConfig cfg, double areaFt2) {
    final id = cfg.serviceId;
    final calc = _compute(cfg, areaFt2);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(child: Text(serviceLabel(id))),
            ServiceInfoButton(serviceId: id),
          ],
        ),
        subtitle: Text(calc.error ?? 'Buy: ${calc.buyText}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cfg.isSod) ...[
                  _NumberField(
                    controller: _wasteCtrls[id]!,
                    label: 'Waste (%)',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Waste % is editable — raise it for irregular shapes or extra cutting loss.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  _NumberField(
                    controller: _rateCtrls[id]!,
                    label: cfg.rateLabel,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
                _NumberField(
                  controller: _packageCtrls[id]!,
                  label: cfg.packageLabel,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (calc.error != null)
                  Text(
                    calc.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                else ...[
                  _ResultRow(label: 'Exact need', value: calc.exactText),
                  const SizedBox(height: 4),
                  _ResultRow(label: 'Buy', value: calc.buyText),
                ],
                SwitchListTile(
                  title: const Text('Add to estimate'),
                  value: _added[id] ?? false,
                  onChanged: (v) => setState(() => _added[id] = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric field with decimal keyboard; reports changes for live recompute.
class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final void Function(String) onChanged;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

/// One computed-result line: label on the left, value on the right.
class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
