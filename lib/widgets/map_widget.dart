// lib/widgets/map_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_config.dart';

class MapWidget extends StatefulWidget {
  final String continentCode;
  final Set<String> discoveredCountries;
  final GameMode gameMode;
  final String? highlightIso;
  final void Function(String? countryCode)? onTapCountry;

  const MapWidget({
    Key? key,
    required this.continentCode,
    required this.discoveredCountries,
    required this.gameMode,
    this.highlightIso,
    this.onTapCountry,
  }) : super(key: key);

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final TransformationController _transformController = TransformationController();
  late Future<Map<String, dynamic>> _countriesFuture;
  late Future<Map<String, dynamic>> _outlineFuture;
  List<_CountryGeometry> _geometries = [];

  @override
  void initState() {
    super.initState();
    _countriesFuture = _loadGeoJson(widget.continentCode.toLowerCase());
    if (widget.gameMode == GameMode.hard) {
      _outlineFuture = _loadGeoJson('${widget.continentCode.toLowerCase()}_outline');
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadGeoJson(String name) async {
    final raw = await rootBundle.loadString('assets/maps/$name.geojson');
    return json.decode(raw) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    Widget buildMap(Map<String, dynamic>? outline, Map<String, dynamic> countries) {
      _prepareGeometries(countries);

      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (ev) {
              final box = context.findRenderObject() as RenderBox;
              final local = box.globalToLocal(ev.globalPosition);
              final scene = _transformController.toScene(local);
              final iso = _hitTest(scene, box.size);
              widget.onTapCountry?.call(iso);
            },
            child: InteractiveViewer(
              transformationController: _transformController,
              panEnabled: true,
              minScale: 0.5,
              maxScale: 5.0,
              child: CustomPaint(
                size: Size(width, height),
                painter: _MapPainter(
                  outlineJson: outline,
                  countriesJson: countries,
                  discovered: widget.discoveredCountries,
                  gameMode: widget.gameMode,
                  highlightIso: widget.highlightIso,
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.gameMode == GameMode.hard) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.wait([_outlineFuture, _countriesFuture]),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
          return buildMap(snap.data![0], snap.data![1]);
        },
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _countriesFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
        return buildMap(null, snap.data!);
      },
    );
  }

  void _prepareGeometries(Map<String, dynamic> countriesJson) {
    _geometries = (countriesJson['features'] as List).map((f) {
      final props = f['properties'] as Map<String, dynamic>;
      return _CountryGeometry(
        iso: props['ISO3166-1-Alpha-2'] as String,
        geometry: f['geometry'],
      );
    }).toList();

    _geometries.sort((a, b) => _MapPainter.computeBboxArea(a.geometry).compareTo(_MapPainter.computeBboxArea(b.geometry)));
  }

  String? _hitTest(Offset pos, Size size) {
    final bounds = _MapPainter.computeBounds(_geometries.map((g) => g.geometry));
    final geoW = bounds.maxX - bounds.minX;
    final geoH = bounds.maxY - bounds.minY;
    final scaleX = size.width / geoW;
    final scaleY = size.height / geoH;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final dx = (size.width - geoW * scale) / 2;
    final dy = (size.height - geoH * scale) / 2;
    final tx = (pos.dx - dx) / scale + bounds.minX;
    final ty = bounds.maxY - ((pos.dy - dy) / scale);

    for (var g in _geometries) {
      if (_MapPainter.pointInPolygon(g.geometry, Offset(tx, ty))) {
        return g.iso;
      }
    }
    String? best;
    double minDist2 = double.infinity;
    for (var g in _geometries) {
      final c = _MapPainter.computeGeoCentroid(g.geometry);
      final dx2 = tx - c.dx;
      final dy2 = ty - c.dy;
      final d2 = dx2 * dx2 + dy2 * dy2;
      if (d2 < minDist2) {
        minDist2 = d2;
        best = g.iso;
      }
    }
    return best;
  }
}

class _CountryGeometry {
  final String iso;
  final dynamic geometry;
  _CountryGeometry({required this.iso, required this.geometry});
}

class _Bounds {
  final double minX, minY, maxX, maxY;
  _Bounds(this.minX, this.minY, this.maxX, this.maxY);
}

class _MapPainter extends CustomPainter {
  final Map<String, dynamic>? outlineJson;
  final Map<String, dynamic> countriesJson;
  final Set<String> discovered;
  final GameMode gameMode;
  final String? highlightIso;

  _MapPainter({
    required this.outlineJson,
    required this.countriesJson,
    required this.discovered,
    required this.gameMode,
    required this.highlightIso,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final rings = <List<dynamic>>[];
    for (var f in countriesJson['features'] as List) {
      final geom = f['geometry'];
      rings.addAll(_collectRings(geom));
    }
    if (rings.isEmpty) return;

    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (var ring in rings) {
      for (var pt in ring) {
        final x = (pt[0] as num).toDouble();
        final y = (pt[1] as num).toDouble();
        minX = x < minX ? x : minX;
        minY = y < minY ? y : minY;
        maxX = x > maxX ? x : maxX;
        maxY = y > maxY ? y : maxY;
      }
    }

    final geoW = maxX - minX;
    final geoH = maxY - minY;
    final scaleX = size.width / geoW;
    final scaleY = size.height / geoH;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final dx = (size.width - geoW * scale) / 2;
    final dy = (size.height - geoH * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy + geoH * scale);
    canvas.scale(scale, -scale);
    canvas.translate(-minX, -minY);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale;

    for (var f in countriesJson['features'] as List) {
      final props = f['properties'] as Map<String, dynamic>?;
      final iso = props?['ISO3166-1-Alpha-2'] as String?;
      final isLink = props?['isLabelLink'] == true;
      final geom = f['geometry'];

      if (isLink && geom['type'] == 'LineString') {
        final path = Path();
        final coords = geom['coordinates'] as List;
        if (coords.length >= 2) {
          final p0 = coords[0] as List;
          path.moveTo((p0[0] as num).toDouble(), (p0[1] as num).toDouble());
          for (var i = 1; i < coords.length; i++) {
            final pt = coords[i] as List;
            path.lineTo((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.black.withOpacity(0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
        }
        continue;
      }

      if (iso == null) continue;

      fill.color = discovered.contains(iso) ? Colors.green.shade300 : Colors.grey.shade300;
      stroke.color = discovered.contains(iso) ? Colors.green.shade800 : Colors.grey.shade600;

      _drawGeom(canvas, geom, fill);
      _drawGeom(canvas, geom, stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  static List<List<dynamic>> _collectRings(dynamic geom) {
    final rings = <List<dynamic>>[];
    final type = geom['type'] as String;
    final coords = geom['coordinates'];
    if (type == 'Polygon') {
      for (var r in coords as List) rings.add(List<dynamic>.from(r));
    } else if (type == 'MultiPolygon') {
      for (var poly in coords as List) {
        for (var r in poly as List) rings.add(List<dynamic>.from(r));
      }
    }
    return rings;
  }

  static void _drawGeom(Canvas canvas, dynamic geom, Paint paint) {
    final type = geom['type'] as String;
    final coords = geom['coordinates'];
    if (type == 'Polygon') {
      for (var ring in coords as List) _drawRing(canvas, ring as List<dynamic>, paint);
    } else if (type == 'MultiPolygon') {
      for (var poly in coords as List) {
        for (var ring in poly as List) _drawRing(canvas, ring as List<dynamic>, paint);
      }
    }
  }

  static void _drawRing(Canvas canvas, List<dynamic> ring, Paint paint) {
    final path = Path();
    for (var i = 0; i < ring.length; i++) {
      final pt = ring[i] as List;
      final x = (pt[0] as num).toDouble();
      final y = (pt[1] as num).toDouble();
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  static _Bounds computeBounds(Iterable geometries) {
    final rings = <List<dynamic>>[];
    for (var g in geometries) rings.addAll(_collectRings(g));
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (var ring in rings) {
      for (var pt in ring) {
        final x = (pt[0] as num).toDouble();
        final y = (pt[1] as num).toDouble();
        minX = x < minX ? x : minX;
        minY = y < minY ? y : minY;
        maxX = x > maxX ? x : maxX;
        maxY = y > maxY ? y : maxY;
      }
    }
    return _Bounds(minX, minY, maxX, maxY);
  }

  static Offset computeGeoCentroid(dynamic geom) {
    final pts = <Offset>[];
    void collect(dynamic g) {
      final t = g['type'] as String;
      final c = g['coordinates'];
      if (t == 'Polygon') {
        for (var ring in c as List) {
          for (var pt in ring as List) {
            pts.add(Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble()));
          }
        }
      } else if (t == 'MultiPolygon') {
        for (var poly in c as List) {
          collect({'type': 'Polygon', 'coordinates': poly});
        }
      }
    }
    collect(geom);
    if (pts.isEmpty) return Offset.zero;
    double sx = 0, sy = 0;
    for (var o in pts) {
      sx += o.dx;
      sy += o.dy;
    }
    return Offset(sx / pts.length, sy / pts.length);
  }

  static bool pointInPolygon(dynamic geom, Offset p) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (var ring in _collectRings(geom)) {
      for (var i = 0; i < ring.length; i++) {
        final pt = ring[i] as List;
        final x = (pt[0] as num).toDouble();
        final y = (pt[1] as num).toDouble();
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
    }
    return path.contains(p);
  }

  static double computeBboxArea(dynamic geom) {
    final b = computeBounds([geom]);
    return (b.maxX - b.minX) * (b.maxY - b.minY);
  }

  static double computeGeoArea(dynamic geom) {
    double area = 0;
    void processRing(List pts, bool positive) {
      double sum = 0;
      for (var i = 0; i < pts.length; i++) {
        final x1 = (pts[i][0] as num).toDouble();
        final y1 = (pts[i][1] as num).toDouble();
        final nxt = pts[(i + 1) % pts.length];
        final x2 = (nxt[0] as num).toDouble();
        final y2 = (nxt[1] as num).toDouble();
        sum += x1 * y2 - x2 * y1;
      }
      final ringArea = 0.5 * sum.abs();
      area += positive ? ringArea : -ringArea;
    }

    final type = geom['type'] as String;
    final coords = geom['coordinates'];
    if (type == 'Polygon') {
      for (var i = 0; i < coords.length; i++) {
        processRing(coords[i] as List, i == 0);
      }
    } else if (type == 'MultiPolygon') {
      for (var poly in coords as List) {
        processRing(poly[0] as List, true);
      }
    }
    return area.abs();
  }
}
