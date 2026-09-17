/// Unit tests for the pure-Dart geometry engine (lib/core/geometry.dart).
///
/// The area fixtures are built from exact meter offsets converted to
/// degrees with the same Earth radius the implementation uses
/// (R = 6371000 m), so the expected areas are known analytically:
///   rectangle 100 ft x 50 ft = 5000 ft²
///   right triangle with legs 100 ft x 50 ft = 2500 ft²
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:lawn_estimator/core/geometry.dart';

void main() {
  group('polygonAreaFt2', () {
    test('100ft x 50ft rectangle measures ~5000 ft² (within 2%)', () {
      final rect = [
        LatLng(39.9999315, -105.0001789),
        LatLng(39.9999315, -104.9998211),
        LatLng(40.0000685, -104.9998211),
        LatLng(40.0000685, -105.0001789),
      ];
      expect(polygonAreaFt2(rect), closeTo(5000, 5000 * 0.02));
    });

    test('winding order does not change the area', () {
      final rect = [
        LatLng(39.9999315, -105.0001789),
        LatLng(39.9999315, -104.9998211),
        LatLng(40.0000685, -104.9998211),
        LatLng(40.0000685, -105.0001789),
      ];
      expect(polygonAreaFt2(rect.reversed.toList()),
          closeTo(polygonAreaFt2(rect), 0.001));
    });

    test('right triangle with 100ft x 50ft legs measures ~2500 ft²', () {
      final triangle = [
        LatLng(38.9999543, -105.0001176),
        LatLng(38.9999543, -104.9997649),
        LatLng(39.0000914, -105.0001176),
      ];
      expect(polygonAreaFt2(triangle), closeTo(2500, 2500 * 0.02));
    });

    test('fewer than 3 points returns 0', () {
      expect(polygonAreaFt2([]), 0);
      expect(polygonAreaFt2([LatLng(40.0, -105.0)]), 0);
      expect(
        polygonAreaFt2([LatLng(40.0, -105.0), LatLng(40.1, -105.1)]),
        0,
      );
      expect(polygonAreaM2([LatLng(40.0, -105.0)]), 0);
    });
  });

  group('segmentsIntersect', () {
    test('crossing segments intersect', () {
      expect(
        segmentsIntersect(
          LatLng(0, 0),
          LatLng(1, 1),
          LatLng(0, 1),
          LatLng(1, 0),
        ),
        isTrue,
      );
    });

    test('parallel non-touching segments do not intersect', () {
      expect(
        segmentsIntersect(
          LatLng(0, 0),
          LatLng(1, 0),
          LatLng(0, 1),
          LatLng(1, 1),
        ),
        isFalse,
      );
    });

    test('segments sharing an endpoint intersect', () {
      expect(
        segmentsIntersect(
          LatLng(0, 0),
          LatLng(1, 1),
          LatLng(1, 1),
          LatLng(2, 0),
        ),
        isTrue,
      );
    });

    test('collinear overlapping segments intersect', () {
      expect(
        segmentsIntersect(
          LatLng(0, 0),
          LatLng(2, 0),
          LatLng(1, 0),
          LatLng(3, 0),
        ),
        isTrue,
      );
    });
  });

  group('polygonSelfIntersects', () {
    test('bowtie polygon self-intersects', () {
      final bowtie = [
        LatLng(0, 0),
        LatLng(1, 1),
        LatLng(0, 1),
        LatLng(1, 0),
      ];
      expect(polygonSelfIntersects(bowtie), isTrue);
    });

    test('simple square does not self-intersect', () {
      final square = [
        LatLng(0, 0),
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ];
      expect(polygonSelfIntersects(square), isFalse);
    });

    test('simple pentagon does not self-intersect', () {
      final pentagon = [
        LatLng(0, 0),
        LatLng(1, 0.3),
        LatLng(0.8, 1),
        LatLng(0.2, 1),
        LatLng(-0.2, 0.4),
      ];
      expect(polygonSelfIntersects(pentagon), isFalse);
    });

    test('fewer than 4 points cannot self-intersect', () {
      expect(polygonSelfIntersects([]), isFalse);
      expect(
        polygonSelfIntersects([LatLng(0, 0), LatLng(1, 1), LatLng(0, 1)]),
        isFalse,
      );
    });

    test('duplicate consecutive points do not cause a false positive', () {
      final withDoubleTap = [
        LatLng(0, 0),
        LatLng(0, 0), // user tapped the same spot twice
        LatLng(0, 1),
        LatLng(1, 1),
        LatLng(1, 0),
      ];
      expect(polygonSelfIntersects(withDoubleTap), isFalse);
    });
  });
}
