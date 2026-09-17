/// Estimate summary screen: review line items, tweak quantities and
/// prices, add labor, and save the estimate.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
import 'package:lawn_estimator/features/pricing/pricing_provider.dart';
import 'package:lawn_estimator/models/models.dart';

/// Shows the draft's line items with editable quantities and unit prices.
///
/// Each row carries a badge showing where its price came from:
/// 'Your price' (green) when the owner set it, 'Area default' (amber)
/// when the reference rate filled in. Extended amounts and the grand
/// total recalculate live as values change.
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  /// Working copy of the draft's line items; synced back on save.
  late List<LineItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List<LineItem>.from(ref.read(estimateDraftProvider).lineItems);
  }

  /// Rebuilds a line item with a new quantity and/or unit price string,
  /// keeping extendedAmount in sync (quantity × parsed unit price).
  LineItem _copyItem(LineItem item, {double? quantity, String? unitPrice}) {
    final q = quantity ?? item.quantity;
    final p = unitPrice ?? item.unitPrice;
    return item.copyWith(
      quantity: q,
      unitPrice: p,
      extendedAmount: q * (double.tryParse(p) ?? 0.0),
    );
  }

  double get _grandTotal =>
      _items.fold(0.0, (sum, item) => sum + item.extendedAmount);

  /// Adds a single labor line priced from the resolved labor rate.
  void _addLabor() {
    final resolved = ref.read(pricingProvider.notifier).resolve('labor');
    setState(() {
      // LineItem.create derives extendedAmount from quantity × unitPrice.
      _items.add(LineItem.create(
        estimateId: '',
        service: 'labor',
        quantity: 1,
        unit: 'job',
        unitPrice: _trimNumber(resolved.price),
        rateSource: resolved.source,
      ));
    });
  }

  /// Saves the draft (with any edited items), resets the draft, and
  /// returns to the home screen.
  Future<void> _saveEstimate() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(estimateDraftProvider.notifier);
      final current = ref.read(estimateDraftProvider);
      // Sync edited items back into the draft before saving.
      // setMaterials is synchronous, so the draft sees the items immediately.
      notifier.setMaterials(current.materials, _items);

      await EstimateRepository().saveDraft(ref.read(estimateDraftProvider));
      notifier.reset();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate saved.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the estimate: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(estimateDraftProvider);

    // Guard: nothing to summarize without a measured area.
    if (draft.totalAreaFt2 <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No measured area yet — measure the lawn first.'),
          ),
        );
        Navigator.of(context).pop();
      });
      return const Scaffold(
        body: Center(child: Text('No area to estimate yet.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Estimate Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (draft.addressLabel != null &&
                      draft.addressLabel!.isNotEmpty) ...[
                    Text(
                      draft.addressLabel!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text('Total area: ${formatFt2(draft.totalAreaFt2)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No line items yet. Add materials or labor.'),
              ),
            )
          else
            for (var i = 0; i < _items.length; i++) _itemRow(i),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addLabor,
            icon: const Icon(Icons.add),
            label: const Text('Add labor'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('\$${_grandTotal.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saving ? null : _saveEstimate,
            child: Text(_saving ? 'Saving…' : 'Save estimate'),
          ),
        ),
      ),
    );
  }

  /// One editable line-item row.
  Widget _itemRow(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    serviceLabel(item.service),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _sourceBadge(item.rateSource),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('qty_$index'),
                    initialValue: _trimNumber(item.quantity),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value.trim());
                      if (parsed == null || parsed < 0) return;
                      setState(() {
                        _items[index] =
                            _copyItem(item, quantity: parsed);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('price_$index'),
                    initialValue: item.unitPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price (${item.unit})',
                      prefixText: '\$',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final trimmed = value.trim();
                      final parsed = double.tryParse(trimmed);
                      if (parsed == null || parsed < 0) return;
                      setState(() {
                        _items[index] =
                            _copyItem(item, unitPrice: trimmed);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '\$${item.extendedAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'per ${item.unit}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Green for the owner's own price, amber for the area default.
  Widget _sourceBadge(String source) {
    final isOwner = source == 'owner';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOwner ? Colors.green.shade100 : Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isOwner ? 'Your price' : 'Area default',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOwner ? Colors.green.shade900 : Colors.amber.shade900,
        ),
      ),
    );
  }

  static String _trimNumber(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}
