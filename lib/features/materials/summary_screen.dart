/// Estimate summary screen: review line items, tweak quantities and
/// prices, add labor, and save the estimate.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lawn_estimator/core/pricing_catalog.dart';
import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
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

  /// Set once the estimate is saved. The draft reset zeroes the area, which
  /// must not trip the no-area guard below while we navigate home — that
  /// race popped the freshly pushed home route and left a black screen.
  bool _saved = false;

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

  /// Opens the labor dialog: workers × hours at the owner's man-hour rate
  /// (prefilled from the company profile). The line bills man-hours.
  Future<void> _addLabor() async {
    final profile = await EstimateRepository().loadCompanyProfile();
    if (!mounted) return;
    final result = await showDialog<_LaborInput>(
      context: context,
      builder: (_) => _LaborDialog(initialRate: profile.laborRate),
    );
    if (result == null || !mounted) return;
    // The line bills man-hours; the note keeps the original
    // workers × hours breakdown (plus any user notation) so the detail
    // survives on the estimate, the detail screen, and the printed PDF.
    final breakdown =
        '${_trimNumber(result.workers)} workers × ${_trimNumber(result.hours)} hrs';
    final note = result.note.trim().isEmpty
        ? breakdown
        : '$breakdown — ${result.note.trim()}';
    setState(() {
      // LineItem.create derives extendedAmount from quantity × unitPrice.
      // Repeated labor lines are intentional (multiple crews/phases), and
      // a $0 rate is valid for freebies, notations, or unset pricing.
      _items.add(LineItem.create(
        estimateId: '',
        service: 'labor',
        quantity: result.workers * result.hours,
        unit: 'man-hr',
        unitPrice: _trimNumber(result.rate),
        rateSource: 'owner',
        note: note,
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
      // Flag BEFORE reset: the reset zeroes the draft area and would
      // otherwise trip the no-area guard's post-frame pop after navigation.
      if (mounted) setState(() => _saved = true);
      notifier.reset();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate saved.')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      debugPrint('Save estimate failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not save the estimate. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(estimateDraftProvider);

    // Guard: nothing to summarize without a measured area.
    // Skipped after a successful save — the draft reset zeroes the area
    // while we navigate home.
    if (!_saved && draft.totalAreaFt2 <= 0) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceLabel(item.service),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (item.note != null && item.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.note!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
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

/// Workers × hours × rate, collected by [_LaborDialog].
class _LaborInput {
  final double workers;
  final double hours;
  final double rate;
  final String note;

  const _LaborInput({
    required this.workers,
    required this.hours,
    required this.rate,
    required this.note,
  });
}

/// Dialog for adding a labor line: number of workers, hours on the job,
/// and the man-hour rate (prefilled from the company profile).
class _LaborDialog extends StatefulWidget {
  final double initialRate;

  const _LaborDialog({required this.initialRate});

  @override
  State<_LaborDialog> createState() => _LaborDialogState();
}

class _LaborDialogState extends State<_LaborDialog> {
  late final TextEditingController _workers = TextEditingController(text: '2');
  late final TextEditingController _hours = TextEditingController();
  late final TextEditingController _rate = TextEditingController(
    text: widget.initialRate > 0 ? _trim(widget.initialRate) : '',
  );
  final TextEditingController _note = TextEditingController();

  static String _trim(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _workers.dispose();
    _hours.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _workersVal => double.tryParse(_workers.text.trim()) ?? 0;
  double get _hoursVal => double.tryParse(_hours.text.trim()) ?? 0;

  /// Null until the user types something; a $0 rate is valid (freebies,
  /// notations, unset pricing), so only the empty field is invalid.
  double? get _rateVal {
    final text = _rate.text.trim();
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    return (parsed == null || parsed < 0) ? null : parsed;
  }

  double get _total => _workersVal * _hoursVal * (_rateVal ?? 0);
  bool get _valid => _workersVal > 0 && _hoursVal > 0 && _rateVal != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add labor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _workers,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Workers',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hours,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hours',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rate,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Rate (USD per man-hour, 0 allowed)',
              prefixText: '\$',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. freebie, spring cleanup',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _valid
                ? '${_trim(_workersVal)} workers × ${_trim(_hoursVal)} hrs × '
                    '\$${_trim(_rateVal!)}/hr = \$${_total.toStringAsFixed(2)}'
                : 'Enter workers, hours, and rate (0 allowed).',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(_LaborInput(
                    workers: _workersVal,
                    hours: _hoursVal,
                    rate: _rateVal!,
                    note: _note.text,
                  ))
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
