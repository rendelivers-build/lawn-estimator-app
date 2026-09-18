/// Local SQLite database for the Lawn Estimator app.
///
/// Single-connection singleton around sqflite. All table/column names use
/// snake_case so they line up exactly with the `toMap()` / `fromMap()` keys
/// in `package:lawn_estimator/models/models.dart` (the cross-module contract).
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and owns the app's SQLite database (`lawn_estimator.db`).
class AppDatabase {
  AppDatabase._();

  static Database? _instance;

  /// The shared database connection, opened on first use.
  static Future<Database> get database async {
    final existing = _instance;
    if (existing != null) return existing;
    final opened = await _open();
    _instance = opened;
    return opened;
  }

  static Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'lawn_estimator.db');
    return openDatabase(
      path,
      version: 3,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onConfigure(Database db) async {
    // Enforce foreign keys so child rows can't outlive their parent.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    // One row per saved estimate job.
    await db.execute('''
      CREATE TABLE estimates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address_label TEXT NOT NULL,
        place_id TEXT,
        center_lat REAL NOT NULL,
        center_lng REAL NOT NULL,
        area_ft2 REAL NOT NULL,
        confirmation_status TEXT NOT NULL,
        photo_path TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Measured lawn zones belonging to an estimate, in draw order.
    await db.execute('''
      CREATE TABLE zones (
        id TEXT PRIMARY KEY,
        estimate_id TEXT NOT NULL
          REFERENCES estimates(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        area_m2 REAL NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_zones_estimate ON zones(estimate_id)',
    );

    // Polygon vertices for each zone, in sequence order.
    await db.execute('''
      CREATE TABLE vertices (
        id TEXT PRIMARY KEY,
        zone_id TEXT NOT NULL
          REFERENCES zones(id) ON DELETE CASCADE,
        sequence INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_vertices_zone ON vertices(zone_id)',
    );

    // Calculated material quantities per estimate.
    await db.execute('''
      CREATE TABLE material_estimates (
        id TEXT PRIMARY KEY,
        estimate_id TEXT NOT NULL
          REFERENCES estimates(id) ON DELETE CASCADE,
        material_type TEXT NOT NULL,
        rate_per_1000 REAL,
        package_size_lb REAL,
        waste_percent REAL,
        unit_coverage_ft2 REAL,
        exact_quantity REAL NOT NULL,
        purchase_units REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_materials_estimate ON material_estimates(estimate_id)',
    );

    // Priced service lines per estimate.
    await db.execute('''
      CREATE TABLE line_items (
        id TEXT PRIMARY KEY,
        estimate_id TEXT NOT NULL
          REFERENCES estimates(id) ON DELETE CASCADE,
        service TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        unit_price TEXT NOT NULL,
        rate_source TEXT NOT NULL,
        extended_amount REAL NOT NULL,
        note TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_line_items_estimate ON line_items(estimate_id)',
    );

    // Per-service pricing configuration (owner prices vs. area defaults).
    await db.execute('''
      CREATE TABLE pricing_settings (
        service TEXT PRIMARY KEY,
        owner_price REAL,
        unit TEXT NOT NULL,
        area_default_price REAL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Owner's company identity for estimate letterheads (single row, id=1).
    await db.execute('''
      CREATE TABLE company_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        business_name TEXT NOT NULL DEFAULT '',
        street TEXT NOT NULL DEFAULT '',
        city TEXT NOT NULL DEFAULT '',
        state TEXT NOT NULL DEFAULT '',
        zip TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        labor_rate REAL NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 -> v2: company_profile table for estimate letterheads.
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute('''
        CREATE TABLE company_profile (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          business_name TEXT NOT NULL DEFAULT '',
          street TEXT NOT NULL DEFAULT '',
          city TEXT NOT NULL DEFAULT '',
          state TEXT NOT NULL DEFAULT '',
          zip TEXT NOT NULL DEFAULT '',
          phone TEXT NOT NULL DEFAULT '',
          email TEXT NOT NULL DEFAULT '',
          labor_rate REAL NOT NULL DEFAULT 0
        )
      ''');
    }
    // v2 -> v3: optional free-text note on line items (labor breakdown,
    // freebie notations, unset-pricing remarks).
    if (oldVersion < 3 && newVersion >= 3) {
      await db.execute('ALTER TABLE line_items ADD COLUMN note TEXT');
    }
  }
}
