/// Pricing settings screen: the owner sets their own prices and the
/// area-default reference rates used when they haven't.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:lawn_estimator/features/pricing/pricing_provider.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Pricing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Your prices always win. When you haven't set a price, the "
                "area default fills in — it's a reference rate, not a market quote.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final service in kPricingServices)
            _ServicePriceRow(
              service: service,
              settings: pricing[service.id],
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

  const _ServicePriceRow({required this.service, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(pricingProvider.notifier);

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
                Chip(
                  label: Text('per ${service.unit}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
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
          ],
        ),
      ),
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
        isDense: true,
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
