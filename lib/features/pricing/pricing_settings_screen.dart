/// Pricing settings screen: the owner sets their own prices and the
/// area-default reference rates used when they haven't.
///
/// Also hosts the Beginner / Expert experience mode. Wherever the owner
/// hasn't set a price, the built-in reference price fills in, so estimates
/// never come out $0. The owner's own price always wins.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:lawn_estimator/features/pricing/pricing_provider.dart';
import 'package:lawn_estimator/features/settings/app_settings_provider.dart';
import 'package:lawn_estimator/features/shared/service_info_button.dart';
import 'package:lawn_estimator/models/models.dart';

/// Lets the owner manage per-service pricing.
///
/// Each service row shows two numeric fields: "Your price" (always wins
/// when set) and "Area default" (a reference rate used as a fallback).
class PricingSettingsScreen extends ConsumerWidget {
  const PricingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricing = ref.watch(pricingProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final expert = appSettings.isExpert;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Experience mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expert
                        ? 'Expert mode: reference rates fill in wherever you '
                            'haven\'t set a price — enter your own price for '
                            'any service below.'
                        : 'Beginner mode: starter prices fill in wherever you '
                            'haven\'t set one, so estimates never come out '
                            '\$0. Enter your company info, then adjust any '
                            'price below.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'beginner', label: Text('Beginner')),
                        ButtonSegment(
                            value: 'expert', label: Text('Expert')),
                      ],
                      selected: {appSettings.mode},
                      onSelectionChanged: (selected) async {
                        final mode = selected.first;
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setMode(mode);
                        if (mode == AppSettings.modeExpert &&
                            context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Expert mode on — your prices always win; '
                                'reference rates fill the gaps.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Company profile'),
              subtitle: const Text(
                'Your business name and contact info for estimate letterheads.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/company'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Your prices always win. When you haven't set a price, the "
                "area default fills in — it's a reference rate, not a market quote. "
                "The built-in reference price fills in last wherever nothing "
                "else is set.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final service in kPricingServices)
            _ServicePriceRow(
              service: service,
              settings: pricing[service.id],
              expert: expert,
            ),
        ],
      ),
    );
  }
}

/// One service row with "Your price" and "Area default" fields.
///
/// Stateless on purpose: each field uses [TextFormField.initialValue]
/// with a stable key so typing is never clobbered by provider rebuilds.
class _ServicePriceRow extends ConsumerWidget {
  final PricingService service;
  final PricingSettings? settings;
  final bool expert;

  const _ServicePriceRow({
    required this.service,
    required this.settings,
    required this.expert,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pricingProvider.notifier);
    final starter = kStarterPrices[service.id];
    final hasPrice = (settings?.ownerPrice != null) ||
        (settings?.areaDefaultPrice != null);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ServiceInfoButton(serviceId: service.id),
                Chip(
                  label: Text('per ${service.unit}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (!expert && !hasPrice && starter != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Starter price: \$${_trim(starter)} per ${service.unit}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.blue.shade800),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PriceField(
                    key: ValueKey('owner_${service.id}'),
                    label: 'Your price',
                    initialValue: settings?.ownerPrice,
                    onSubmitted: (price) =>
                        notifier.setOwnerPrice(service.id, price),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PriceField(
                    key: ValueKey('area_${service.id}'),
                    label: 'Area default',
                    initialValue: settings?.areaDefaultPrice,
                    onSubmitted: (price) =>
                        notifier.setAreaDefault(service.id, price),
                  ),
                ),
              ],
            ),
            // Granular materials are bought by the bag: offer the
            // bag-price math instead of making the owner divide it out.
            if (service.unit == 'lb') _BagPriceHelper(service: service),
          ],
        ),
      ),
    );
  }

  static String _trim(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

/// Bag-price helper for per-lb materials (seed, fertilizer, weed & feed).
///
/// The owner buys by the bag, not by the pound: they type the bag price
/// (e.g. $26) and the bag weight (e.g. 40 lb), the app does the division,
/// and one tap writes the per-lb result into "Your price".
class _BagPriceHelper extends ConsumerStatefulWidget {
  final PricingService service;

  const _BagPriceHelper({required this.service});

  @override
  ConsumerState<_BagPriceHelper> createState() => _BagPriceHelperState();
}

class _BagPriceHelperState extends ConsumerState<_BagPriceHelper> {
  final _bagPriceCtrl = TextEditingController();
  final _bagWeightCtrl = TextEditingController();

  @override
  void dispose() {
    _bagPriceCtrl.dispose();
    _bagWeightCtrl.dispose();
    super.dispose();
  }

  /// Per-lb price once both fields hold a valid number, else null.
  double? get _perLb {
    final price = double.tryParse(_bagPriceCtrl.text.trim());
    final weight = double.tryParse(_bagWeightCtrl.text.trim());
    if (price == null || weight == null || weight <= 0) return null;
    return price / weight;
  }

  @override
  Widget build(BuildContext context) {
    final perLb = _perLb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Buy it by the bag? Enter the bag price and weight — '
          'the per-lb math is done for you.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _bagPriceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Bag price',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _bagWeightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Bag weight (lb)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        if (perLb != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '= \$${perLb.toStringAsFixed(2)} per lb',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton.tonal(
                onPressed: () {
                  final rounded =
                      double.parse(perLb.toStringAsFixed(2));
                  ref
                      .read(pricingProvider.notifier)
                      .setOwnerPrice(widget.service.id, rounded);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Your price set to '
                        '\$${rounded.toStringAsFixed(2)} per lb.',
                      ),
                    ),
                  );
                },
                child: const Text('Use this price'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Numeric price field that reports a parsed value on submit.
///
/// An empty field submits null (clears the price); unparseable input is
/// ignored so a typo can never wipe a saved price.
class _PriceField extends StatelessWidget {
  final String label;
  final double? initialValue;
  final void Function(double? price) onSubmitted;

  const _PriceField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue?.toString() ?? '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '\$',
        border: const OutlineInputBorder(),
      ),
      onFieldSubmitted: (value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          onSubmitted(null);
          return;
        }
        final parsed = double.tryParse(trimmed);
        if (parsed != null) onSubmitted(parsed);
      },
    );
  }
}
