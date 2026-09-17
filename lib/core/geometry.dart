/// Pure-Dart geometry helpers for measuring lawn polygons on a map.
///
/// Everything here operates on [LatLng] (from google_maps_flutter, which is
/// itself pure Dart) so this file stays fully unit-testable with no platform
/// channels or Flutter bindings involved.
library;

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Mean Earth radius in meters.
const double _earthRadiusM = 6371000.0;

/// Square feet per square meter.
const double _sqFtPerSqM = 10.7639;

/// Area of a [LatLng] polygon in square meters.
///
/// The polygon is projected onto a local tangent plane with an
/// equirectangular (plate carrée) projection centered on the polygon's
/// centroid:
///
///   x = R · Δλ · cos(φ₀)      y = R · Δφ
///
/// where R is the mean Earth radius, Δφ / Δλ are the latitude/longitude
/// offsets from the centroid in radians, and φ₀ is the centroid latitude.
///
/// Why this projection: a lawn polygon is tens of meters across — about
/// 1e-5 Earth radii — so the distortion of any local planar projection is
/// orders of magnitude below GPS / finger-tap noise. Centering the
/// projection on the centroid (rather than, say, the first vertex) keeps
/// the largest offset — and therefore the cos(φ₀) scale error — as small
/// as possible. A full UTM or ellipsoidal computation would buy nothing
/// measurable here and would complicate testing.
///
/// The projected ring is measured with the shoelace formula and the
/// absolute value is returned, so vertex winding order does not matter.
/// Returns 0 when [points] has fewer than 3 vertices.
double polygonAreaM2(List<LatLng> points) {
  if (points.length < 3) return 0;

  // Centroid of the ring — the projection origin.
  var latSum = 0.0;
  var lngSum = 0.0;
  for (final p in points) {
    latSum += p.latitude;
    lngSum += p.longitude;
  }
  final lat0 = latSum / points.length;
  final lng0 = lngSum / points.length;
  final cosLat0 = math.cos(lat0 * math.pi / 180);

  // Project every vertex to local meters.
  final xs = List<double>.filled(points.length, 0.0);
  final ys = List<double>.filled(points.length, 0.0);
  for (var i = 0; i < points.length; i++) {
    final dLatRad = (points[i].latitude - lat0) * math.pi / 180;
    final dLngRad = (points[i].longitude - lng0) * math.pi / 180;
    xs[i] = _earthRadiusM * dLngRad * cosLat0;
    ys[i] = _earthRadiusM * dLatRad;
  }

  // Shoelace formula over the closed ring.
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final j = (i + 1) % points.length;
    sum += xs[i] * ys[j] - xs[j] * ys[i];
  }
  return sum.abs() / 2;
}

/// Area of a [LatLng] polygon in square feet.
///
/// Returns 0 when [points] has fewer than 3 vertices.
double polygonAreaFt2(List<LatLng> points) =>
    polygonAreaM2(points) * _sqFtPerSqM;

/// Signed orientation of the triplet (a, b, c) in longitude/latitude space.
/// Positive = counter-clockwise, negative = clockwise, zero = collinear.
double _orientation(LatLng a, LatLng b, LatLng c) {
  return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);
}

/// True when point [b] lies within the bounding box of segment a→c.
/// Only meaningful when [b] is collinear with a→c.
bool _onSegment(LatLng a, LatLng b, LatLng c) {
  return b.longitude >= math.min(a.longitude, c.longitude) &&
      b.longitude <= math.max(a.longitude, c.longitude) &&
      b.latitude >= math.min(a.latitude, c.latitude) &&
      b.latitude <= math.max(a.latitude, c.latitude);
}

/// True when the segments a1→a2 and b1→b2 intersect.
///
/// Uses the standard orientation test. Touching endpoints and collinear
/// overlap count as intersecting.
bool segmentsIntersect(LatLng a1, LatLng a2, LatLng b1, LatLng b2) {
  final d1 = _orientation(b1, b2, a1);
  final d2 = _orientation(b1, b2, a2);
  final d3 = _orientation(a1, a2, b1);
  final d4 = _orientation(a1, a2, b2);

  // Proper crossing: endpoints straddle each other's lines.
  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
    return true;
  }

  // Collinear or endpoint-touching cases.
  if (d1 == 0 && _onSegment(b1, a1, b2)) return true;
  if (d2 == 0 && _onSegment(b1, a2, b2)) return true;
  if (d3 == 0 && _onSegment(a1, b1, a2)) return true;
  if (d4 == 0 && _onSegment(a1, b2, a2)) return true;

  return false;
}

/// True when any two non-adjacent edges of the polygon intersect.
///
/// [points] is treated as a closed ring (the last vertex connects back to
/// the first). Adjacent edges share a vertex by construction and are
/// skipped, as is the (first, last) edge pair which is adjacent in a closed
/// ring. Consecutive duplicate vertices (e.g. a double-tapped point) are
/// collapsed first: without that, the two edges flanking the duplicate
/// touch at the same location and read as a false self-intersection.
///
/// Returns false for fewer than 4 points — a triangle cannot self-intersect.
bool polygonSelfIntersects(List<LatLng> points) {
  // Collapse consecutive duplicate vertices into one. A zero-length edge
  // is not a real edge, and the edges on either side of the duplicate
  // would otherwise share that exact location.
  final cleaned = <LatLng>[];
  for (final p in points) {
    final prev = cleaned.isEmpty ? null : cleaned.last;
    if (prev == null ||
        prev.latitude != p.latitude ||
        prev.longitude != p.longitude) {
      cleaned.add(p);
    }
  }
  // The ring closes implicitly; a duplicated closing vertex adds nothing.
  if (cleaned.length > 1) {
    final first = cleaned.first;
    final last = cleaned.last;
    if (first.latitude == last.latitude && first.longitude == last.longitude) {
      cleaned.removeLast();
    }
  }

  final n = cleaned.length;
  if (n < 4) return false;

  bool degenerate(LatLng p, LatLng q) =>
      p.latitude == q.latitude && p.longitude == q.longitude;

  for (var i = 0; i < n; i++) {
    final a1 = cleaned[i];
    final a2 = cleaned[(i + 1) % n];
    if (degenerate(a1, a2)) continue;
    for (var j = i + 1; j < n; j++) {
      // Skip adjacent edges of the closed ring.
      if (j == i + 1) continue;
      if (i == 0 && j == n - 1) continue;
      final b1 = cleaned[j];
      final b2 = cleaned[(j + 1) % n];
      if (degenerate(b1, b2)) continue;
      if (segmentsIntersect(a1, a2, b1, b2)) return true;
    }
  }
  return false;
}
