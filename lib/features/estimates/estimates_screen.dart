/// Home screen: the list of saved estimates.
///
/// Entry point of the app (`/`). Each saved estimate appears as a card with
/// its photo thumbnail, address, date, measured area, and total price.
/// A floating action button starts a fresh estimate by resetting the
/// measure-flow draft and opening the address search screen.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
import 'package:lawn_estimator/models/models.dart';

/// US-dollar currency formatter shared by the list cards.
final _currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

class EstimatesScreen extends ConsumerStatefulWidget {
  const EstimatesScreen({super.key});

  @override
  ConsumerState<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends ConsumerState<EstimatesScreen> {
  late Future<List<EstimateListItem>> _estimatesFuture;

  @override
  void initState() {
    super.initState();
    _estimatesFuture = EstimateRepository().listEstimates();
  }

  /// Re-queries the database (used when returning from other screens).
  void _refresh() {
    setState(() {
      _estimatesFuture = EstimateRepository().listEstimates();
    });
  }

  /// Starts a brand-new estimate: clears any in-progress draft, then opens
  /// the address search screen.
  void _startNewEstimate() {
    ref.read(estimateDraftProvider.notifier).reset();
    Navigator.of(context).pushNamed('/address').then((_) => _refresh());
  }

  void _openEstimate(String id) {
    Navigator.of(context)
        .pushNamed('/estimate', arguments: id)
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lawn Estimator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pricing settings',
            onPressed: () => Navigator.of(context).pushNamed('/pricing'),
          ),
        ],
      ),
      body: FutureBuilder<List<EstimateListItem>>(
        future: _estimatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load estimates.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final estimates = snapshot.data ?? const <EstimateListItem>[];
          if (estimates.isEmpty) {
            return _EmptyState(onNewEstimate: _startNewEstimate);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: estimates.length,
            itemBuilder: (context, index) {
              final item = estimates[index];
              return _EstimateCard(
                item: item,
                onTap: () => _openEstimate(item.estimate.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewEstimate,
        icon: const Icon(Icons.add),
        label: const Text('New estimate'),
      ),
    );
  }
}

/// Shown when no estimates have been saved yet.
class _EmptyState extends StatelessWidget {
  final VoidCallback onNewEstimate;

  const _EmptyState({required this.onNewEstimate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grass,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No estimates yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Measure a lawn to create your first estimate.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onNewEstimate,
              icon: const Icon(Icons.add),
              label: const Text('New estimate'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One saved estimate in the list: photo thumbnail, address/date/area,
/// total price, and a chevron.
class _EstimateCard extends StatelessWidget {
  final EstimateListItem item;
  final VoidCallback onTap;

  const _EstimateCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estimate = item.estimate;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: _Thumbnail(photoPath: estimate.photoPath),
        title: Text(
          estimate.addressLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatDate(estimate.createdAt)} • ${formatFt2(estimate.areaFt2)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currency.format(item.total),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// 56×56 rounded thumbnail: the estimate photo when one exists on disk,
/// otherwise a grass placeholder icon.
class _Thumbnail extends StatelessWidget {
  final String? photoPath;

  const _Thumbnail({required this.photoPath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = photoPath;

    Widget child;
    // `path` is promoted to non-null inside this condition.
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      child = Image.file(
        File(path),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholderIcon(theme),
      );
    } else {
      child = _placeholderIcon(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 56, height: 56, child: child),
    );
  }

  Widget _placeholderIcon(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.grass,
        size: 32,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
