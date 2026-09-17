/// Estimate detail screen: everything about one saved estimate.
///
/// Shows the site photo (with an "Unconfirmed" badge when the measurement
/// hasn't been confirmed), the measurement summary, priced line items,
/// calculated materials, and any note. Actions: print/share via
/// [EstimatePrintButton], or delete the estimate after confirmation.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/features/print/estimate_print_button.dart';
import 'package:lawn_estimator/models/models.dart';

/// US-dollar currency formatter shared by the detail cards.
final _currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

/// Compact quantity formatter: "3", "2.5" — no trailing zeros.
final _qtyFormat = NumberFormat('#,##0.##', 'en_US');

class EstimateDetailScreen extends ConsumerStatefulWidget {
  final String estimateId;

  const EstimateDetailScreen({super.key, required this.estimateId});

  @override
  ConsumerState<EstimateDetailScreen> createState() =>
      _EstimateDetailScreenState();
}

class _EstimateDetailScreenState extends ConsumerState<EstimateDetailScreen> {
  late Future<EstimateFull?> _estimateFuture;

  @override
  void initState() {
    super.initState();
    _estimateFuture = EstimateRepository().getEstimateFull(widget.estimateId);
  }

  /// Asks for confirmation, then deletes the estimate and returns home.
  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this estimate?'),
        content: const Text(
          'This cannot be undone. The estimate, its measurements, '
          'materials, and line items will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await EstimateRepository().deleteEstimate(widget.estimateId);
    if (!mounted) return;
    Navigator.of(context).popUntil(ModalRoute.withName('/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estimate')),
      body: FutureBuilder<EstimateFull?>(
        future: _estimateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load this estimate.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final full = snapshot.data;
          if (full == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This estimate no longer exists.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return _EstimateBody(full: full, onDelete: _confirmAndDelete);
        },
      ),
    );
  }
}

/// Scrollable detail content for a loaded estimate.
class _EstimateBody extends StatelessWidget {
  final EstimateFull full;
  final VoidCallback onDelete;

  const _EstimateBody({required this.full, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final estimate = full.estimate;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhotoHeader(estimate: estimate),
          const SizedBox(height: 16),
          Text(
            estimate.addressLabel,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Measured ${formatDate(estimate.createdAt)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          _MeasurementCard(full: full),
          const SizedBox(height: 12),
          _LineItemsCard(full: full),
          const SizedBox(height: 12),
          _MaterialsCard(full: full),
          if (estimate.note != null && estimate.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NoteCard(note: estimate.note!),
          ],
          const SizedBox(height: 24),
          EstimatePrintButton(estimate: full),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete estimate'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Site photo banner with an "Unconfirmed" badge overlay when applicable.
class _PhotoHeader extends StatelessWidget {
  final Estimate estimate;

  const _PhotoHeader({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final path = estimate.photoPath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();
    final unconfirmed =
        estimate.confirmationStatus == ConfirmationStatus.unconfirmed;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // `path` is non-null whenever `hasPhoto` is true.
            if (hasPhoto)
              Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _NoPhotoPlaceholder(),
              )
            else
              const _NoPhotoPlaceholder(),
            if (unconfirmed)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Unconfirmed',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shown when the estimate has no site photo.
class _NoPhotoPlaceholder extends StatelessWidget {
  const _NoPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No photo',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Total area in ft² / yd² / acres plus the zone count.
class _MeasurementCard extends StatelessWidget {
  final EstimateFull full;

  const _MeasurementCard({required this.full});

  @override
  Widget build(BuildContext context) {
    final ft2 = full.estimate.areaFt2;
    final zoneWord = full.zones.length == 1 ? 'zone' : 'zones';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Measurement',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(
                  label: 'Square feet',
                  value: formatFt2(ft2),
                ),
                _Stat(
                  label: 'Square yards',
                  value: '${_qtyFormat.format(sqftToSqyd(ft2))} yd²',
                ),
                _Stat(
                  label: 'Acres',
                  value: '${_qtyFormat.format(sqftToAcres(ft2))} ac',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${full.zones.length} $zoneWord measured',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One labeled measurement value inside the measurement card.
class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Priced service lines with a total row.
class _LineItemsCard extends StatelessWidget {
  final EstimateFull full;

  const _LineItemsCard({required this.full});

  /// Human-friendly label for the stored rate-source code.
  String _rateSourceLabel(String rateSource) {
    switch (rateSource) {
      case 'owner':
        return 'Owner price';
      case 'area_default':
        return 'Area default';
      default:
        return rateSource;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Line items',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (full.lineItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No line items.'),
              )
            else ...[
              for (final item in full.lineItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.service,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_qtyFormat.format(item.quantity)} '
                              '${item.unit} @ ${_currency.format(_parsePrice(item.unitPrice))} · '
                              '${_rateSourceLabel(item.rateSource)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _currency.format(item.extendedAmount),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _currency.format(full.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// LineItem stores unitPrice as a String; parse defensively for display.
  double _parsePrice(String unitPrice) => double.tryParse(unitPrice) ?? 0;
}

/// Calculated material quantities (exact need + purchase units).
class _MaterialsCard extends StatelessWidget {
  final EstimateFull full;

  const _MaterialsCard({required this.full});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Materials',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (full.materials.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No materials calculated.'),
              )
            else
              for (final material in full.materials)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              material.materialType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Exact need: ${_qtyFormat.format(material.exactQuantity)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_qtyFormat.format(material.purchaseUnits)} to buy',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// The estimator's free-text note, when one was saved.
class _NoteCard extends StatelessWidget {
  final String note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(note),
          ],
        ),
      ),
    );
  }
}
