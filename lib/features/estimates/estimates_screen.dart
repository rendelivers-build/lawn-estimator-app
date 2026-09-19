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
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/data/estimate_repository.dart';
import 'package:lawn_estimator/features/measure/draft_autosave.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
import 'package:lawn_estimator/features/settings/app_settings_provider.dart';
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
    // First-run tutorial: show once, after settings finish loading so the
    // "Don't show this again" choice is respected.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(appSettingsProvider.notifier).ensureLoaded();
      if (!mounted) return;
      // Resume an interrupted estimate before anything else: a phone call
      // or backing out mid-flow must not lose the user's work.
      final saved = await loadDraft();
      if (mounted &&
          saved != null &&
          !ref.read(estimateDraftProvider).hasContent) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Resume estimate?'),
            content: Text(
              'You have an unfinished estimate'
              '${saved.addressLabel != null ? ' for ${saved.addressLabel}' : ''}. '
              'Pick up where you left off?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Discard'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Resume'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (resume == true) {
          ref.read(estimateDraftProvider.notifier).restore(saved);
          // Drop the user back on the exact screen they were on when
          // interrupted; fall back to /measure for anything unexpected.
          const flowRoutes = {'/measure', '/confirm', '/materials', '/summary'};
          final route = saved.resumeRoute;
          Navigator.of(context)
              .pushNamed(flowRoutes.contains(route) ? route! : '/measure');
          return;
        }
        await clearDraft();
      }
      if (!mounted) return;
      if (!ref.read(appSettingsProvider).tutorialSeen) {
        Navigator.of(context).pushNamed('/tutorial');
      }
    });
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

  /// Long-press menu on an estimate card: edit it or delete it.
  Future<void> _showEstimateActions(EstimateListItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              subtitle: const Text('Change prices, quantities, or notes'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Removes the estimate for good'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editEstimate(item.estimate.id);
    } else {
      await _deleteEstimate(item);
    }
  }

  /// Loads a saved estimate back into the draft so it can be changed,
  /// then opens the summary where quantities, prices, and notes are
  /// editable. Saving replaces the original — no duplicate.
  Future<void> _editEstimate(String id) async {
    final full = await EstimateRepository().getEstimateFull(id);
    if (!mounted) return;
    if (full == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that estimate.')),
      );
      return;
    }
    final estimate = full.estimate;
    final zones = <List<LatLng>>[
      for (final zone in full.zones)
        [
          for (final v in full.verticesByZone[zone.id] ?? const <Vertex>[])
            LatLng(v.latitude, v.longitude),
        ],
    ];
    final draft = EstimateDraft(
      addressLabel: estimate.addressLabel,
      placeId: estimate.placeId,
      centerLat: estimate.centerLat,
      centerLng: estimate.centerLng,
      zones: zones.isEmpty ? const [[]] : zones,
      photoPath: estimate.photoPath,
      note: estimate.note,
      internalNote: estimate.internalNote,
      displayNote: estimate.displayNote,
      confirmed:
          estimate.confirmationStatus == ConfirmationStatus.confirmed,
      materials: full.materials,
      lineItems: full.lineItems,
      resumeRoute: '/summary',
      editingEstimateId: id,
    );
    ref.read(estimateDraftProvider.notifier).restore(draft);
    // Persist so an interruption mid-edit still resumes as an edit of the
    // same estimate rather than a brand-new one.
    await saveDraft(draft);
    if (!mounted) return;
    Navigator.of(context).pushNamed('/summary').then((_) => _refresh());
  }

  /// Confirms, then deletes the estimate and everything saved with it.
  Future<void> _deleteEstimate(EstimateListItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete estimate?'),
        content: Text(
          'Delete the estimate for ${item.estimate.addressLabel}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await EstimateRepository().deleteEstimate(item.estimate.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estimate deleted.')),
    );
    _refresh();
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
      body: Stack(
        children: [
          // Faint home-screen background: subtle green dotted lines plus
          // a grass watermark. Purely decorative — sits behind the list.
          const Positioned.fill(child: _LawnBackground()),
          FutureBuilder<List<EstimateListItem>>(
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
                  'Could not load estimates. Try again.',
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
                onLongPress: () => _showEstimateActions(item),
              );
            },
          );
            },
          ),
          ],
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
/// total price, and a chevron. Tap opens it; long-press offers edit/delete.
class _EstimateCard extends StatelessWidget {
  final EstimateListItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _EstimateCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

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
        onLongPress: onLongPress,
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

/// Faint decorative home-screen background: subtle green dotted lines plus
/// a grass watermark in the corner.
class _LawnBackground extends StatelessWidget {
  const _LawnBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _DottedLinesPainter()),
        ),
        Positioned(
          right: -40,
          bottom: -40,
          child: Icon(
            Icons.grass,
            size: 220,
            color: const Color(0x0D2E7D32),
          ),
        ),
      ],
    );
  }
}

/// Paints faint diagonal dotted lines across the whole area.
class _DottedLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1A2E7D32);
    const step = 30.0;
    const dotSpacing = 11.0;
    // Diagonal lines (slope ~0.5), dotted so they stay whisper-light.
    for (var startY = -size.height; startY < size.height; startY += step) {
      var x = 0.0;
      while (x < size.width) {
        canvas.drawCircle(Offset(x, startY + x * 0.5), 1.4, paint);
        x += dotSpacing;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
