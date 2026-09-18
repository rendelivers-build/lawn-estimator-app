/// Persistence layer for saved estimates and pricing settings.
///
/// All writes that touch more than one table run inside a single SQLite
/// transaction so a saved estimate is always complete or not saved at all.
///
/// Contract assumptions (sibling modules not yet landed):
/// - `EstimateDraft` (from `draft_provider.dart`) exposes `addressLabel`,
///   `placeId`, `centerLat`, `centerLng`, `totalAreaFt2`, `confirmed`,
///   `note`, `photoPath`, `zones` (as `List<List<LatLng>>`), `materials`,
///   and `lineItems`.
/// - `package:lawn_estimator/core/geometry.dart` exposes
///   `double polygonAreaM2(List<LatLng> polygon)`.
library;

import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:lawn_estimator/core/geometry.dart';
import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/data/database.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';
import 'package:lawn_estimator/models/models.dart';

/// Reads and writes estimates, their child records, and pricing settings.
class EstimateRepository {
  /// Test seam: lets tests inject a different database handle.
  final Future<Database> Function() _db;

  EstimateRepository({Future<Database> Function()? database})
      : _db = database ?? (() => AppDatabase.database);

  static const _uuid = Uuid();

  /// Persists a finished [EstimateDraft] as a new estimate plus all of its
  /// zones, vertices, materials, and line items — atomically.
  ///
  /// Returns the new estimate's id.
  Future<String> saveDraft(EstimateDraft draft) async {
    final db = await _db();
    final now = DateTime.now();
    final estimateId = _uuid.v4();
    final addressLabel = draft.addressLabel;
    final name = (addressLabel != null && addressLabel.isNotEmpty)
        ? addressLabel
        : 'Estimate ${formatDate(now)}';

    final estimate = Estimate(
      id: estimateId,
      name: name,
      addressLabel: addressLabel ?? name,
      placeId: draft.placeId,
      // The flow guarantees an address is chosen before measuring, so the
      // center is always set by the time a draft can be saved.
      centerLat: draft.centerLat ?? 0.0,
      centerLng: draft.centerLng ?? 0.0,
      areaFt2: draft.totalAreaFt2,
      confirmationStatus: draft.confirmed
          ? ConfirmationStatus.confirmed
          : ConfirmationStatus.unconfirmed,
      photoPath: draft.photoPath,
      note: draft.note,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('estimates', estimate.toMap());

      for (var z = 0; z < draft.zones.length; z++) {
        // Each draft zone is an ordered ring of LatLng vertices.
        final vertices = draft.zones[z];
        final zoneId = _uuid.v4();
        final areaM2 = polygonAreaM2(vertices);

        final zone = LawnZone(
          id: zoneId,
          estimateId: estimateId,
          label: 'Zone ${z + 1}',
          sequence: z,
          areaM2: areaM2,
        );
        await txn.insert('zones', zone.toMap());

        for (var v = 0; v < vertices.length; v++) {
          final point = vertices[v];
          final vertex = Vertex(
            id: _uuid.v4(),
            zoneId: zoneId,
            sequence: v,
            latitude: point.latitude,
            longitude: point.longitude,
          );
          await txn.insert('vertices', vertex.toMap());
        }
      }

      for (final material in draft.materials) {
        final row = material.copyWith(
          id: _uuid.v4(),
          estimateId: estimateId,
          updatedAt: now,
        );
        await txn.insert('material_estimates', row.toMap());
      }

      for (final item in draft.lineItems) {
        final row = item.copyWith(
          id: _uuid.v4(),
          estimateId: estimateId,
          updatedAt: now,
        );
        await txn.insert('line_items', row.toMap());
      }
    });

    return estimateId;
  }

  /// Lists saved estimates newest-first, each with its summed line-item total.
  Future<List<EstimateListItem>> listEstimates() async {
    final db = await _db();
    final rows = await db.rawQuery('''
      SELECT e.*, COALESCE(SUM(li.extended_amount), 0.0) AS list_total
      FROM estimates AS e
      LEFT JOIN line_items AS li ON li.estimate_id = e.id
      GROUP BY e.id
      ORDER BY e.created_at DESC
    ''');
    return rows
        .map((row) => EstimateListItem(
              estimate: Estimate.fromMap(row),
              total: (row['list_total'] as num).toDouble(),
            ))
        .toList();
  }

  /// Loads a full estimate with zones, vertices, materials, and line items.
  ///
  /// Returns `null` when no estimate with [id] exists.
  Future<EstimateFull?> getEstimateFull(String id) async {
    final db = await _db();

    final estimateRows =
        await db.query('estimates', where: 'id = ?', whereArgs: [id], limit: 1);
    if (estimateRows.isEmpty) return null;
    final estimate = Estimate.fromMap(estimateRows.first);

    final zoneRows = await db.query(
      'zones',
      where: 'estimate_id = ?',
      whereArgs: [id],
      orderBy: 'sequence ASC',
    );
    final zones = zoneRows.map(LawnZone.fromMap).toList();

    final verticesByZone = <String, List<Vertex>>{};
    for (final zone in zones) {
      final vertexRows = await db.query(
        'vertices',
        where: 'zone_id = ?',
        whereArgs: [zone.id],
        orderBy: 'sequence ASC',
      );
      verticesByZone[zone.id] = vertexRows.map(Vertex.fromMap).toList();
    }

    final materialRows = await db.query(
      'material_estimates',
      where: 'estimate_id = ?',
      whereArgs: [id],
    );
    final materials = materialRows.map(MaterialEstimate.fromMap).toList();

    final lineItemRows = await db.query(
      'line_items',
      where: 'estimate_id = ?',
      whereArgs: [id],
    );
    final lineItems = lineItemRows.map(LineItem.fromMap).toList();

    return EstimateFull(
      estimate: estimate,
      zones: zones,
      verticesByZone: verticesByZone,
      materials: materials,
      lineItems: lineItems,
    );
  }

  /// Deletes an estimate and every record that belongs to it, then removes
  /// the estimate's photo file if one is stored on disk.
  Future<void> deleteEstimate(String id) async {
    final db = await _db();

    // Grab the photo path before the rows disappear.
    String? photoPath;
    final estimateRows =
        await db.query('estimates', where: 'id = ?', whereArgs: [id], limit: 1);
    if (estimateRows.isNotEmpty) {
      photoPath = estimateRows.first['photo_path'] as String?;
    }

    await db.transaction((txn) async {
      await txn.delete('line_items',
          where: 'estimate_id = ?', whereArgs: [id]);
      await txn.delete('material_estimates',
          where: 'estimate_id = ?', whereArgs: [id]);
      await txn.rawDelete(
        'DELETE FROM vertices WHERE zone_id IN '
        '(SELECT id FROM zones WHERE estimate_id = ?)',
        [id],
      );
      await txn.delete('zones', where: 'estimate_id = ?', whereArgs: [id]);
      await txn.delete('estimates', where: 'id = ?', whereArgs: [id]);
    });

    // Best-effort photo cleanup: never let a file error fail the delete.
    if (photoPath != null && photoPath.isNotEmpty) {
      try {
        final file = File(photoPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignored on purpose — the database rows are already gone.
      }
    }
  }

  /// Upserts each pricing row (matched on the `service` primary key).
  Future<void> savePricing(List<PricingSettings> settings) async {
    final db = await _db();
    final batch = db.batch();
    for (final row in settings) {
      batch.insert(
        'pricing_settings',
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Loads all saved pricing settings.
  Future<List<PricingSettings>> loadPricing() async {
    final db = await _db();
    final rows = await db.query('pricing_settings');
    return rows.map(PricingSettings.fromMap).toList();
  }

  /// Loads the owner's company profile; returns a blank profile when
  /// none has been saved yet.
  Future<CompanyProfile> loadCompanyProfile() async {
    final db = await _db();
    final rows =
        await db.query('company_profile', where: 'id = ?', whereArgs: [1], limit: 1);
    if (rows.isEmpty) return const CompanyProfile();
    return CompanyProfile.fromMap(rows.first);
  }

  /// Saves the owner's company profile (single row, id always 1).
  Future<void> saveCompanyProfile(CompanyProfile profile) async {
    final db = await _db();
    await db.insert(
      'company_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
