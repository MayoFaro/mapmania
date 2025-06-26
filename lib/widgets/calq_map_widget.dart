// lib/widgets/map_widget.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
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
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final TransformationController _transformController = TransformationController();
  late Future<Map<String, dynamic>> _countriesFuture;
  late Future<Map<String, dynamic>> _outlineFuture;
  List<_CountryGeometry> _geometries = [];
  late Rect _geoBounds;
  ui.Image? _reliefImage;
  bool _isReliefLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _initializeData() {
    _loadGeoBounds();
    _loadReliefImage();
    _countriesFuture = _loadGeoJson(widget.continentCode.toLowerCase());

    if (widget.gameMode == GameMode.hard) {
      _outlineFuture = _loadGeoJson('${widget.continentCode.toLowerCase()}_outline');
    }
  }

  Future<void> _loadGeoBounds() async {
    try {
      final boundsJson = await rootBundle.loadString('assets/maps/africa/bounds.json');
      final bounds = jsonDecode(boundsJson);
      setState(() {
        _geoBounds = Rect.fromLTRB(
          bounds['left'].toDouble(),
          bounds['top'].toDouble(),
          bounds['right'].toDouble(),
          bounds['bottom'].toDouble(),
        );
      });
    } catch (e) {
      debugPrint('Erreur chargement bounds: $e');
      setState(() {
        _geoBounds = Rect.fromLTRB(-25.0, 37.0, 58.0, -37.0);
      });
    }
  }

  Future<void> _loadReliefImage() async {
    try {
      final byteData = await rootBundle.load('assets/maps/africa/relief.png');
      final image = await decodeImageFromList(byteData.buffer.asUint8List());
      setState(() {
        _reliefImage = image;
        _isReliefLoaded = true;
      });
    } catch (e) {
      debugPrint('Erreur chargement relief: $e');
      setState(() => _isReliefLoaded = true);
    }
  }

  Future<Map<String, dynamic>> _loadGeoJson(String name) async {
    final raw = await rootBundle.loadString('assets/maps/$name.geojson');
    return json.decode(raw) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReliefLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return widget.gameMode == GameMode.hard
        ? _buildHardModeMap()
        : _buildNormalModeMap();
  }

  Widget _buildHardModeMap() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Future.wait([_outlineFuture, _countriesFuture]),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erreur: ${snap.error}'));
        }
        return _buildMap(snap.data![0], snap.data![1]);
      },
    );
  }

  Widget _buildNormalModeMap() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _countriesFuture,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erreur: ${snap.error}'));
        }
        return _buildMap(null, snap.data!);
      },
    );
  }

  Widget _buildMap(Map<String, dynamic>? outline, Map<String, dynamic> countries) {
    _prepareGeometries(countries);

    return Stack(
      children: [
        if (_reliefImage != null)
          Positioned.fill(
            child: CustomPaint(
              painter: _ReliefPainter(
                image: _reliefImage!,
                geoBounds: _geoBounds,
              ),
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleMapTap(details, context),
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
                geoBounds: _geoBounds,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleMapTap(TapUpDetails details, BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    final scene = _transformController.toScene(local);
    final iso = _hitTest(scene, box.size);
    widget.onTapCountry?.call(iso);
  }

  void _prepareGeometries(Map<String, dynamic> countriesJson) {
    _geometries = (countriesJson['features'] as List).map((f) {
      final props = f['properties'] as Map<String, dynamic>;
      return _CountryGeometry(
        iso: props['ISO3166-1-Alpha-2'] as String,
        geometry: f['geometry'],
      );
    }).toList();

    _geometries.sort((a, b) =>
        _computeBboxArea(a.geometry).compareTo(_computeBboxArea(b.geometry)));
  }

  String? _hitTest(Offset pos, Size size) {
    final bounds = _computeBounds(_geometries.map((g) => g.geometry));
    final geoW = bounds.maxX - bounds.minX;
    final geoH = bounds.maxY - bounds.minY;
    final scaleX = size.width / geoW;
    final scaleY = size.height / geoH;
    final scale = min(scaleX, scaleY);
    final dx = (size.width - geoW * scale) / 2;
    final dy = (size.height - geoH * scale) / 2;
    final tx = (pos.dx - dx) / scale + bounds.minX;
    final ty = bounds.maxY - ((pos.dy - dy) / scale);

    for (var g in _geometries) {
      if (_pointInPolygon(g.geometry, Offset(tx, ty))) {
        return g.iso;
      }
    }

    return _findClosestCountry(tx, ty);
  }

  String? _findClosestCountry(double x, double y) {
    String? closestIso;
    double minDistance = double.infinity;

    for (var g in _geometries) {
      final centroid = _computeGeoCentroid(g.geometry);
      final distance = pow(x - centroid.dx, 2) + pow(y - centroid.dy, 2);
      if (distance < minDistance) {
        minDistance = distance.toDouble();
        closestIso = g.iso;
      }
    }

    return closestIso;
  }

  // Méthodes utilitaires déplacées de _MapPainter à _MapWidgetState
  _Bounds _computeBounds(Iterable geometries) {
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

  double _computeBboxArea(dynamic geom) {
    final b = _computeBounds([geom]);
    return (b.maxX - b.minX) * (b.maxY - b.minY);
  }

  bool _pointInPolygon(dynamic geom, Offset p) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (var ring in _collectRings(geom)) {
      for (var i = 0; i < ring.length; i++) {
        final pt = ring[i] as List;
        final x = (pt[0] as num).toDouble();
        final y = (pt[1] as num).toDouble();
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
    }
    return path.contains(p);
  }

  Offset _computeGeoCentroid(dynamic geom) {
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

  List<List<dynamic>> _collectRings(dynamic geom) {
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
}

class _ReliefPainter extends CustomPainter {
  final ui.Image image;
  final Rect geoBounds;

  _ReliefPainter({required this.image, required this.geoBounds});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(
      size.width / geoBounds.width,
      size.height / geoBounds.height,
    );

    final offset = Offset(
      (size.width - geoBounds.width * scale) / 2 - geoBounds.left * scale,
      (size.height - geoBounds.height * scale) / 2 - geoBounds.top * scale,
    );

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale, scale);

    // Dessin du relief avec plus de contraste
    final rect = Rect.fromLTRB(
      geoBounds.left,
      geoBounds.top,
      geoBounds.right,
      geoBounds.bottom,
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(
          Colors.white.withOpacity(0.7),
          BlendMode.modulate,
        ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReliefPainter old) =>
      old.image != image || old.geoBounds != geoBounds;
}

class _MapPainter extends CustomPainter {
  final Map<String, dynamic>? outlineJson;
  final Map<String, dynamic> countriesJson;
  final Set<String> discovered;
  final GameMode gameMode;
  final String? highlightIso;
  final Rect geoBounds;

  _MapPainter({
    this.outlineJson,
    required this.countriesJson,
    required this.discovered,
    required this.gameMode,
    this.highlightIso,
    required this.geoBounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(
      size.width / geoBounds.width,
      size.height / geoBounds.height,
    ) * 0.9; // Réduit légèrement l'échelle

    final offset = Offset(
      (size.width - geoBounds.width * scale) / 2 - geoBounds.left * scale,
      (size.height - geoBounds.height * scale) / 2 - geoBounds.top * scale,
    );

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale, scale);

    // Dessin des pays
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.2 // Épaisseur réduite des frontières
      ..color = Colors.black.withOpacity(0.7);

    for (var f in countriesJson['features'] as List) {
      final iso = (f['properties']['ISO3166-1-Alpha-2'] as String);

      fillPaint.color = discovered.contains(iso)
          ? Colors.green.withOpacity(0.5) // Semi-transparent
          : Colors.grey.withOpacity(0.3); // Très transparent

      _drawGeom(canvas, f['geometry'], fillPaint);
      _drawGeom(canvas, f['geometry'], strokePaint);
    }

    canvas.restore();
  }

  Offset _computeGeoCentroid(dynamic geom) {
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

  void _drawGeom(Canvas canvas, dynamic geom, Paint paint) {
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

  void _drawRing(Canvas canvas, List<dynamic> ring, Paint paint) {
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

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
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