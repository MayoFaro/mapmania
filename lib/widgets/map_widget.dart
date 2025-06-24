// lib/widgets/map_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_config.dart';

/// Widget affichant la carte d'un continent avec deux modes :
/// - normal : toutes les frontières des pays (gris = non découvert, vert = découvert)
/// - hard   : contour externe du continent uniquement
/// Possibilité de mettre en évidence (centroid) un pays avec un point rouge.
class MapWidget extends StatefulWidget {
  final String continentCode;
  final Set<String> discoveredCountries;
  final GameMode gameMode;
  /// ISO d'un pays à centrer avec un marqueur rouge (null pour désactiver)
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
    // Exemple de log d'aires
    _countriesFuture.then((json) {
      for (var code in ['LS', 'SZ', 'GM']) {
        final feat = (json['features'] as List).firstWhere(
              (f) => (f['properties']['ISO3166-1-Alpha-2'] as String) == code,
          orElse: () => null,
        );
        if (feat != null) {
          final area = _MapPainter.computeGeoArea(feat['geometry']);
          debugPrint('[MapWidget] Aire de \$code = \$area');
        }
      }
    });
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
            size: MediaQuery.of(context).size,
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
    }

    if (widget.gameMode == GameMode.hard) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: Future.wait([_outlineFuture, _countriesFuture]),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Erreur: \${snap.error}'));
          return buildMap(snap.data![0], snap.data![1]);
        },
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _countriesFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Erreur: \${snap.error}'));
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
    // Trie par aire de bbox croissante
    _geometries.sort((a, b) =>
        _MapPainter.computeBboxArea(a.geometry)
            .compareTo(_MapPainter.computeBboxArea(b.geometry)));
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

    // Test précis
    for (var g in _geometries) {
      if (_MapPainter.pointInPolygon(g.geometry, Offset(tx, ty))) {
        return g.iso;
      }
    }
    // Fallback centroid
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

/// ISO + géométrie pour hit-test
class _CountryGeometry {
  final String iso;
  final dynamic geometry;
  _CountryGeometry({required this.iso, required this.geometry});
}

/// Bounding box utilitaire
class _Bounds {
  final double minX, minY, maxX, maxY;
  _Bounds(this.minX, this.minY, this.maxX, this.maxY);
}

/// Painter dessine la carte et méthodes statiques pour calculs
class _MapPainter extends CustomPainter {
  final Map<String, dynamic>? outlineJson;
  final Map<String, dynamic> countriesJson;
  final Set<String> discovered;
  final GameMode gameMode;
  final String? highlightIso;

  _MapPainter({
    this.outlineJson,
    required this.countriesJson,
    required this.discovered,
    required this.gameMode,
    this.highlightIso,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Fond blanc
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    // 2) Récupère anneaux pour bbox
    final rings = <List<dynamic>>[];
    if (gameMode == GameMode.hard && outlineJson != null) {
      for (var f in outlineJson!['features'] as List) {
        rings.addAll(_collectRings(f['geometry']));
      }
    }
    for (var f in countriesJson['features'] as List) {
      rings.addAll(_collectRings(f['geometry']));
    }
    if (rings.isEmpty) return;
    // 3) Calcul bbox
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
    // 4) Dessin pays
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 1/scale;
    if (gameMode == GameMode.hard && outlineJson != null) {
      final op = Paint()..style = PaintingStyle.stroke..color = Colors.black..strokeWidth = 2/scale;
      for (var f in outlineJson!['features'] as List) _drawGeom(canvas, f['geometry'], op);
    }
    for (var f in countriesJson['features'] as List) {
      final iso = (f['properties']['ISO3166-1-Alpha-2'] as String);
      fill.color = discovered.contains(iso) ? Colors.green.shade300 : Colors.grey.shade300;
      stroke.color = discovered.contains(iso) ? Colors.green.shade800 : Colors.grey.shade600;
      _drawGeom(canvas, f['geometry'], fill);
      _drawGeom(canvas, f['geometry'], stroke);
    }
    // 5) Marqueur rouge sur highlightIso
    if (highlightIso != null) {
      final feat = (countriesJson['features'] as List).firstWhere(
            (f) => (f['properties']['ISO3166-1-Alpha-2'] as String) == highlightIso,
        orElse: () => null,
      );
      if (feat != null) {
        final c = computeGeoCentroid(feat['geometry']);
        final mp = Paint()..color = Colors.red;
        canvas.drawCircle(Offset(c.dx, c.dy), 8/scale, mp);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;

  /// Calcule la bbox englobante pour un iterable de géométries
  static _Bounds computeBounds(Iterable geometries) {
    final rings = <List<dynamic>>[];
    for (var g in geometries) rings.addAll(_collectRings(g));
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (var ring in rings) for (var pt in ring) {
      final x = (pt[0] as num).toDouble();
      final y = (pt[1] as num).toDouble();
      minX = x < minX ? x : minX;
      minY = y < minY ? y : minY;
      maxX = x > maxX ? x : maxX;
      maxY = y > maxY ? y : maxY;
    }
    return _Bounds(minX, minY, maxX, maxY);
  }

  /// Calcule l'aire via algorithm shoelace
  static double computeGeoArea(dynamic geom) {
    double area = 0;
    void processRing(List pts, bool positive) {
      double sum = 0;
      for (var i = 0; i < pts.length; i++) {
        final x1 = (pts[i][0] as num).toDouble();
        final y1 = (pts[i][1] as num).toDouble();
        final nxt = pts[(i+1) % pts.length];
        final x2 = (nxt[0] as num).toDouble();
        final y2 = (nxt[1] as num).toDouble();
        sum += x1*y2 - x2*y1;
      }
      final ringArea = 0.5*sum.abs();
      area += positive ? ringArea : -ringArea;
    }
    final type = geom['type'] as String;
    final coords = geom['coordinates'];
    if (type=='Polygon') {
      for (var i=0;i<coords.length;i++) processRing(coords[i] as List, i==0);
    } else if (type=='MultiPolygon') {
      for (var poly in coords as List) processRing(poly[0] as List, true);
    }
    return area.abs();
  }

  /// Calcule aire de la bbox d'une seule géométrie
  static double computeBboxArea(dynamic geom) {
    final b = computeBounds([geom]);
    return (b.maxX - b.minX)*(b.maxY - b.minY);
  }

  /// Test point in polygon via even-odd winding
  static bool pointInPolygon(dynamic geom, Offset p) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (var ring in _collectRings(geom)) {
      for (var i=0;i<ring.length;i++) {
        final pt=ring[i] as List;
        final x=(pt[0] as num).toDouble();
        final y=(pt[1] as num).toDouble();
        i==0?path.moveTo(x,y):path.lineTo(x,y);
      }
      path.close();
    }
    return path.contains(p);
  }

  /// Calcule centroïde approximatif
  static Offset computeGeoCentroid(dynamic geom) {
    final pts=<Offset>[];
    void collect(dynamic g) {
      final t=g['type'] as String;
      final c=g['coordinates'];
      if(t=='Polygon') for(var ring in c as List) for(var pt in ring as List) pts.add(Offset((pt[0] as num).toDouble(),(pt[1] as num).toDouble()));
      else if(t=='MultiPolygon') for(var poly in c as List) collect({'type':'Polygon','coordinates':poly});
    }
    collect(geom);
    if(pts.isEmpty) return Offset.zero;
    double sx=0,sy=0; for(var o in pts){sx+=o.dx;sy+=o.dy;} return Offset(sx/pts.length,sy/pts.length);
  }

  /// Extrait tous les anneaux d'une géométrie
  static List<List<dynamic>> _collectRings(dynamic geom) {
    final rings=<List<dynamic>>[];
    final type=geom['type'] as String;
    final coords=geom['coordinates'];
    if(type=='Polygon') for(var r in coords as List) rings.add(List<dynamic>.from(r));
    else if(type=='MultiPolygon') for(var poly in coords as List) for(var r in poly as List) rings.add(List<dynamic>.from(r));
    return rings;
  }

  /// Dessine un polygone ou multi-polygone
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

  /// Dessine un anneau de polygone
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
}
