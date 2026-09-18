/// Map screen for outlining lawn zones: tap to drop vertices, drag markers
/// to adjust, and get a live area readout before continuing.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:lawn_estimator/core/geometry.dart';
import 'package:lawn_estimator/core/units.dart';
import 'package:lawn_estimator/features/measure/draft_provider.dart';

/// Draw mode is always on (v1): every map tap drops a vertex on the active
/// zone. Markers are draggable to fine-tune the outline.
class MeasureScreen extends ConsumerStatefulWidget {
  const MeasureScreen({super.key});

  @override
  ConsumerState<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends ConsumerState<MeasureScreen> {
  GoogleMapController? _mapController;
  MapType _mapType = MapType.satellite;

  /// Geographic center of the contiguous US — fallback when the draft has
  /// no center (should not normally happen after address search).
  static const LatLng _fallbackCenter = LatLng(39.8283, -98.5795);

  /// Small dot icon for zone vertices, built once. The default map pin is
  /// huge next to a small lawn at max zoom, so vertices get a compact dot
  /// anchored at its center instead.
  BitmapDescriptor? _vertexIcon;

  @override
  void initState() {
    super.initState();
    _buildVertexIcon();
  }

  Future<void> _buildVertexIcon() async {
    const size = 30.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final center = const ui.Offset(size / 2, size / 2);
    canvas.drawCircle(
      center,
      size / 2 - 2,
      ui.Paint()..color = const Color(0xFFD32F2F),
    );
    canvas.drawCircle(
      center,
      size / 2 - 3.5,
      ui.Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted || bytes == null) return;
    setState(() {
      _vertexIcon =
          BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  CameraPosition _cameraFor(EstimateDraft draft) {
    final lat = draft.centerLat;
    final lng = draft.centerLng;
    if (lat != null && lng != null) {
      // Zoom 19 shows a single residential lot nicely for outlining.
      return CameraPosition(target: LatLng(lat, lng), zoom: 19);
    }
    return const CameraPosition(target: _fallbackCenter, zoom: 4);
  }

  void _recenter(EstimateDraft draft) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_cameraFor(draft)),
    );
  }

  void _toggleMapType() {
    setState(() {
      _mapType =
          _mapType == MapType.satellite ? MapType.normal : MapType.satellite;
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(estimateDraftProvider);
    final notifier = ref.read(estimateDraftProvider.notifier);
    final activePoints = draft.activeZonePoints;
    final selfIntersects = polygonSelfIntersects(activePoints);
    final canContinue = draft.canContinue && !selfIntersects;

    return Scaffold(
      appBar: AppBar(
        title: Text(draft.addressLabel ?? 'Measure lawn'),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMap(draft, notifier)),
          if (selfIntersects) _buildSelfIntersectWarning(),
          _buildAreaPanel(draft),
          _buildZoneChips(draft, notifier),
          _buildControls(draft, notifier),
          _buildContinueButton(canContinue),
        ],
      ),
    );
  }

  Widget _buildMap(EstimateDraft draft, EstimateDraftNotifier notifier) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _cameraFor(draft),
          mapType: _mapType,
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // custom recenter button below
          polygons: _buildPolygons(draft),
          markers: _buildMarkers(draft, notifier),
          onMapCreated: (controller) => _mapController = controller,
          // Draw mode is always on: a tap drops a vertex on the active zone.
          onTap: notifier.addVertex,
        ),
        Positioned(
          top: 12,
          left: 12,
          child: FloatingActionButton.small(
            heroTag: 'mapType',
            tooltip: 'Toggle satellite / map',
            onPressed: _toggleMapType,
            child: const Icon(Icons.layers),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            tooltip: 'Recenter on property',
            onPressed: () => _recenter(draft),
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Set<Polygon> _buildPolygons(EstimateDraft draft) {
    return {
      for (var i = 0; i < draft.zones.length; i++)
        if (draft.zones[i].isNotEmpty)
          Polygon(
            polygonId: PolygonId('zone_$i'),
            points: draft.zones[i],
            fillColor: i == draft.activeZone
                ? const Color(0x4000C853)
                : const Color(0x2000C853),
            strokeColor: i == draft.activeZone
                ? const Color(0xFF00C853)
                : const Color(0xAA00C853),
            strokeWidth: 3,
          ),
    };
  }

  Set<Marker> _buildMarkers(EstimateDraft draft, EstimateDraftNotifier notifier) {
    final markers = <Marker>{};
    for (var i = 0; i < draft.zones.length; i++) {
      final zone = draft.zones[i];
      for (var j = 0; j < zone.length; j++) {
        markers.add(
          Marker(
            markerId: MarkerId('zone_${i}_vtx_$j'),
            position: zone[j],
            draggable: true,
            // Center the dot on the vertex; the default pin anchors at its
            // tip and covers the outline underneath.
            anchor: const Offset(0.5, 0.5),
            icon: _vertexIcon ?? BitmapDescriptor.defaultMarker,
            onDragEnd: (pos) => notifier.moveVertex(i, j, pos),
          ),
        );
      }
    }
    return markers;
  }

  Widget _buildSelfIntersectWarning() {
    return Container(
      width: double.infinity,
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Text(
        'Lines cross — drag a point to fix',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAreaPanel(EstimateDraft draft) {
    final activeArea = polygonAreaFt2(draft.activeZonePoints);
    final totalArea = draft.totalAreaFt2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This zone: ${formatFt2(activeArea)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Total: ${formatFt2(totalArea)}'
            '  •  ${(totalArea / 9).toStringAsFixed(1)} yd²'
            '  •  ${(totalArea / 43560).toStringAsFixed(2)} ac',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (draft.activeZonePoints.length < 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Tap the map to drop outline points (3 or more needed).',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZoneChips(EstimateDraft draft, EstimateDraftNotifier notifier) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: draft.zones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return InputChip(
            label: Text('Zone ${i + 1} • ${formatFt2(draft.zoneAreaFt2(i))}'),
            selected: i == draft.activeZone,
            onSelected: (_) => notifier.setActiveZone(i),
            onDeleted:
                draft.zones.length > 1 ? () => notifier.removeZone(i) : null,
          );
        },
      ),
    );
  }

  Widget _buildControls(EstimateDraft draft, EstimateDraftNotifier notifier) {
    final hasVertices = draft.activeZonePoints.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: hasVertices ? notifier.undoVertex : null,
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
          ),
          TextButton.icon(
            onPressed: hasVertices ? notifier.clearActiveZone : null,
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Clear zone'),
          ),
          TextButton.icon(
            onPressed: notifier.addZone,
            icon: const Icon(Icons.add),
            label: const Text('Add zone'),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(bool enabled) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed:
              enabled ? () => Navigator.pushNamed(context, '/confirm') : null,
          child: const Text('Use this area'),
        ),
      ),
    );
  }
}
