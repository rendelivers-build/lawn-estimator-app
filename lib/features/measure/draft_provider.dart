/// Riverpod state for the in-progress estimate ("draft").
///
/// The draft carries everything collected during the address → measure →
/// confirm → materials flow until the estimate is saved. State is immutable:
/// every mutation goes through [EstimateDraftNotifier], which always builds
/// fresh zone lists so widgets rebuild predictably.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:lawn_estimator/core/geometry.dart';
import 'package:lawn_estimator/models/models.dart';

/// The estimate currently being built. Immutable — use [copyWith] or
/// [EstimateDraftNotifier] to derive new states.
class EstimateDraft {
  const EstimateDraft({
    this.addressLabel,
    this.placeId,
    this.centerLat,
    this.centerLng,
    this.zones = const [[]],
    this.activeZone = 0,
    this.photoPath,
    this.note,
    this.internalNote,
    this.displayNote,
    this.confirmed = false,
    this.materials = const [],
    this.lineItems = const [],
    this.resumeRoute,
    this.editingEstimateId,
  });

  /// Human-readable address chosen on the search screen.
  final String? addressLabel;

  /// Google Places place ID for the chosen address, if any.
  final String? placeId;

  /// Map center seeded from the chosen place.
  final double? centerLat;
  final double? centerLng;

  /// Outlined lawn zones; each zone is an ordered ring of vertices.
  final List<List<LatLng>> zones;

  /// Index into [zones] of the zone currently being drawn/edited.
  final int activeZone;

  /// Local path of the confirmation photo, if one was taken.
  final String? photoPath;

  /// Optional free-text note from the confirm screen.
  final String? note;

  /// Company-only note: visible in the app, never printed on estimates.
  final String? internalNote;

  /// Customer-facing note: printed on the estimate.
  final String? displayNote;

  /// True once the user confirms the outlined area matches the photo.
  final bool confirmed;

  /// Material/pricing results produced downstream (carried for save).
  final List<MaterialEstimate> materials;
  final List<LineItem> lineItems;

  /// Flow screen the user was on when the draft was last saved
  /// ('/measure', '/confirm', '/materials', '/summary'), so resume drops
  /// them back exactly where the interruption happened.
  final String? resumeRoute;

  /// When set, the draft is an edit of an already-saved estimate: saving
  /// replaces that estimate instead of creating a duplicate.
  final String? editingEstimateId;

  /// Vertices of the active zone (empty list if the index is out of range).
  List<LatLng> get activeZonePoints =>
      (activeZone >= 0 && activeZone < zones.length)
          ? zones[activeZone]
          : const [];

  /// Area of one zone in square feet.
  double zoneAreaFt2(int index) =>
      (index >= 0 && index < zones.length) ? polygonAreaFt2(zones[index]) : 0;

  /// Combined area of all zones in square feet.
  double get totalAreaFt2 =>
      zones.fold(0.0, (sum, zone) => sum + polygonAreaFt2(zone));

  /// True when an address with a map center has been chosen.
  bool get hasAddress =>
      (addressLabel?.trim().isNotEmpty ?? false) &&
      centerLat != null &&
      centerLng != null;

  /// True when at least one zone has enough vertices to form a polygon.
  bool get canContinue => zones.any((zone) => zone.length >= 3);

  /// True when the draft holds anything worth resuming after an
  /// interruption (a phone call, backing out, the app being killed).
  bool get hasContent =>
      (addressLabel?.trim().isNotEmpty ?? false) ||
      zones.any((zone) => zone.isNotEmpty) ||
      photoPath != null ||
      lineItems.isNotEmpty;

  /// Serializes the draft to a JSON-safe map for auto-save.
  Map<String, dynamic> toMap() {
    return {
      'addressLabel': addressLabel,
      'placeId': placeId,
      'centerLat': centerLat,
      'centerLng': centerLng,
      'zones': [
        for (final zone in zones)
          [
            for (final p in zone) {'lat': p.latitude, 'lng': p.longitude}
          ],
      ],
      'activeZone': activeZone,
      'photoPath': photoPath,
      'note': note,
      'internalNote': internalNote,
      'displayNote': displayNote,
      'confirmed': confirmed,
      'materials': [for (final m in materials) m.toMap()],
      'lineItems': [for (final i in lineItems) i.toMap()],
      'resumeRoute': resumeRoute,
      'editingEstimateId': editingEstimateId,
    };
  }

  /// Restores a draft written by [toMap]; null when the payload is empty
  /// or unusable.
  static EstimateDraft? fromMap(Map<String, dynamic> map) {
    try {
      final zonesRaw = map['zones'] as List? ?? const [];
      final zones = <List<LatLng>>[
        for (final zoneRaw in zonesRaw)
          <LatLng>[
            for (final p in (zoneRaw as List? ?? const []))
              LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ),
          ],
      ];
      return EstimateDraft(
        addressLabel: map['addressLabel'] as String?,
        placeId: map['placeId'] as String?,
        centerLat: (map['centerLat'] as num?)?.toDouble(),
        centerLng: (map['centerLng'] as num?)?.toDouble(),
        zones: zones.isEmpty ? const [[]] : zones,
        activeZone: (map['activeZone'] as num?)?.toInt() ?? 0,
        photoPath: map['photoPath'] as String?,
        note: map['note'] as String?,
        internalNote: map['internalNote'] as String?,
        displayNote: map['displayNote'] as String?,
        confirmed: map['confirmed'] as bool? ?? false,
        materials: [
          for (final m in (map['materials'] as List? ?? const []))
            MaterialEstimate.fromMap(Map<String, dynamic>.from(m as Map)),
        ],
        lineItems: [
          for (final i in (map['lineItems'] as List? ?? const []))
            LineItem.fromMap(Map<String, dynamic>.from(i as Map)),
        ],
        resumeRoute: map['resumeRoute'] as String?,
        editingEstimateId: map['editingEstimateId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  EstimateDraft copyWith({
    String? addressLabel,
    String? placeId,
    double? centerLat,
    double? centerLng,
    List<List<LatLng>>? zones,
    int? activeZone,
    String? photoPath,
    bool clearPhoto = false,
    String? note,
    bool clearNote = false,
    String? internalNote,
    bool clearInternalNote = false,
    String? displayNote,
    bool clearDisplayNote = false,
    bool? confirmed,
    List<MaterialEstimate>? materials,
    List<LineItem>? lineItems,
    String? resumeRoute,
    String? editingEstimateId,
    bool clearEditingId = false,
  }) {
    return EstimateDraft(
      addressLabel: addressLabel ?? this.addressLabel,
      placeId: placeId ?? this.placeId,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      zones: zones ?? this.zones,
      activeZone: activeZone ?? this.activeZone,
      // Nullable fields need an explicit clear flag because `??` cannot
      // distinguish "not passed" from "passed as null".
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      note: clearNote ? null : (note ?? this.note),
      internalNote: clearInternalNote ? null : (internalNote ?? this.internalNote),
      displayNote: clearDisplayNote ? null : (displayNote ?? this.displayNote),
      confirmed: confirmed ?? this.confirmed,
      materials: materials ?? this.materials,
      lineItems: lineItems ?? this.lineItems,
      resumeRoute: resumeRoute ?? this.resumeRoute,
      editingEstimateId:
          clearEditingId ? null : (editingEstimateId ?? this.editingEstimateId),
    );
  }
}

/// Mutates the in-progress [EstimateDraft].
class EstimateDraftNotifier extends StateNotifier<EstimateDraft> {
  EstimateDraftNotifier() : super(const EstimateDraft());

  /// Fresh outer + inner lists so state stays immutable.
  List<List<LatLng>> _copyZones() => [for (final z in state.zones) [...z]];

  /// Starts a new draft for [addressLabel], discarding any previous draft.
  /// Seeds one empty zone at [lat]/[lng].
  void startNew({
    required String addressLabel,
    String? placeId,
    required double lat,
    required double lng,
  }) {
    state = EstimateDraft(
      addressLabel: addressLabel,
      placeId: placeId,
      centerLat: lat,
      centerLng: lng,
      zones: [[]],
      activeZone: 0,
    );
  }

  /// Appends a vertex to the active zone.
  void addVertex(LatLng point) {
    final zones = _copyZones();
    zones[state.activeZone].add(point);
    state = state.copyWith(zones: zones);
  }

  /// Removes the most recently added vertex of the active zone, if any.
  void undoVertex() {
    final zones = _copyZones();
    final zone = zones[state.activeZone];
    if (zone.isEmpty) return;
    zone.removeLast();
    state = state.copyWith(zones: zones);
  }

  /// Empties the active zone.
  void clearActiveZone() {
    final zones = _copyZones();
    zones[state.activeZone] = [];
    state = state.copyWith(zones: zones);
  }

  /// Adds a new empty zone and makes it active.
  void addZone() {
    final zones = _copyZones()..add([]);
    state = state.copyWith(zones: zones, activeZone: zones.length - 1);
  }

  /// Removes the zone at [index]. Always keeps at least one (empty) zone so
  /// the map always has a draw target, and keeps the active index valid.
  void removeZone(int index) {
    if (index < 0 || index >= state.zones.length) return;
    final zones = _copyZones()..removeAt(index);
    if (zones.isEmpty) zones.add([]);

    var active = state.activeZone;
    if (index < active) {
      active -= 1;
    } else if (index == active && active >= zones.length) {
      // Removed the active zone itself and it was the last one.
      active = zones.length - 1;
    }
    state = state.copyWith(zones: zones, activeZone: active);
  }

  /// Makes the zone at [index] the active one. Ignores out-of-range indexes.
  void setActiveZone(int index) {
    if (index < 0 || index >= state.zones.length) return;
    if (index == state.activeZone) return;
    state = state.copyWith(activeZone: index);
  }

  /// Moves a single vertex (used by draggable map markers).
  void moveVertex(int zoneIdx, int vertexIdx, LatLng point) {
    if (zoneIdx < 0 || zoneIdx >= state.zones.length) return;
    final zone = state.zones[zoneIdx];
    if (vertexIdx < 0 || vertexIdx >= zone.length) return;
    final zones = _copyZones();
    zones[zoneIdx][vertexIdx] = point;
    state = state.copyWith(zones: zones);
  }

  /// Sets (or clears, when null) the confirmation photo path.
  void setPhoto(String? path) {
    state = state.copyWith(photoPath: path, clearPhoto: path == null);
  }

  /// Sets (or clears, when null) the optional note.
  void setNote(String? note) {
    state = state.copyWith(note: note, clearNote: note == null);
  }

  /// Sets (or clears, when null) the company-only internal note.
  void setInternalNote(String? note) {
    state = state.copyWith(
        internalNote: note, clearInternalNote: note == null);
  }

  /// Sets (or clears, when null) the customer-facing display note.
  void setDisplayNote(String? note) {
    state =
        state.copyWith(displayNote: note, clearDisplayNote: note == null);
  }

  /// Records whether the user confirmed the outline matches the photo.
  void setConfirmed(bool confirmed) {
    state = state.copyWith(confirmed: confirmed);
  }

  /// Stores material/pricing results computed downstream.
  void setMaterials(List<MaterialEstimate> materials, List<LineItem> lineItems) {
    state = state.copyWith(
      materials: [...materials],
      lineItems: [...lineItems],
    );
  }

  /// Replaces the draft with a previously auto-saved one (resume flow).
  void restore(EstimateDraft draft) {
    state = draft;
  }

  /// Records which flow screen the user is on, so an interrupted estimate
  /// resumes on that exact screen instead of always restarting at /measure.
  void setResumeRoute(String route) {
    if (state.resumeRoute != route) {
      state = state.copyWith(resumeRoute: route);
    }
  }

  /// Discards the draft entirely.
  void reset() {
    state = const EstimateDraft();
  }
}

/// The in-progress estimate for the current flow.
final estimateDraftProvider =
    StateNotifierProvider<EstimateDraftNotifier, EstimateDraft>(
  (ref) => EstimateDraftNotifier(),
);
