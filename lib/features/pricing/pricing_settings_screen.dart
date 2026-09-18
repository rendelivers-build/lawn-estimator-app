/// Pricing settings screen: the owner sets their own prices and the
/// area-default reference rates used when they haven't.
///
/// Also hosts the Beginner / Expert experience mode. In Beginner mode the
/// built-in starter prices fill in wherever the owner hasn't set a price,
/// so estimates never come out $0. Expert mode disables the starter
/// fallback and expects the owner to enter every price.
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
                        ? 'Expert mode: no starter prices — enter your own '
                            'price for every service below.'
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
                                'Expert mode on — set your own price for '
                                'each service below.',
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
                "area default fills in — it's a reference rate, not a market quote."
                "${expert ? '' : ' In Beginner mode the starter price fills in last.'}",
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
          ],
        ),
      ),
    );
  }

  static String _trim(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
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
