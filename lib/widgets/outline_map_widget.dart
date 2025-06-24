// lib/widgets/outline_map_widget.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget de test : dessine chaque point du contour extérieur
/// du continent pour vérifier la géométrie.
class OutlineMapWidget extends StatefulWidget {
  /// Code du continent (e.g. 'AF' pour Afrique)
  final String continentCode;

  const OutlineMapWidget({
    Key? key,
    required this.continentCode,
  }) : super(key: key);

  @override
  _OutlineMapWidgetState createState() => _OutlineMapWidgetState();
}

class _OutlineMapWidgetState extends State<OutlineMapWidget> {
  late Future<Map<String, dynamic>> _outlineFuture;

  @override
  void initState() {
    super.initState();
    _outlineFuture = _loadOutline();
  }

  Future<Map<String, dynamic>> _loadOutline() async {
    final path = 'assets/maps/${widget.continentCode.toLowerCase()}_outline.geojson';
    debugPrint('Loading outline GeoJSON at $path');
    final jsonStr = await rootBundle.loadString(path);
    return json.decode(jsonStr) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _outlineFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur chargement outline: ${snapshot.error}'),
          );
        }
        final geoJson = snapshot.data!;
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _DebugPointPainter(geoJson),
        );
      },
    );
  }
}

class _DebugPointPainter extends CustomPainter {
  final Map<String, dynamic> geoJson;

  _DebugPointPainter(this.geoJson);

  @override
  void paint(Canvas canvas, Size size) {
    // Fond blanc
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );

    // Paint pour les points
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue;

    // Paint pour le cadre bounding box
    final bboxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.red
      ..strokeWidth = 1.0;

    // Récupère les features
    final features = geoJson['features'] as List<dynamic>;
    debugPrint('Outline features count: ${features.length}');

    // Collecte tous les points
    final List<Offset> points = [];
    for (final f in features) {
      final geom = f['geometry'] as Map<String, dynamic>;
      final type = geom['type'] as String;
      if (type == 'LineString' || type == 'LinearRing') {
        for (final pt in geom['coordinates'] as List<dynamic>) {
          points.add(Offset(
            (pt[0] as num).toDouble(),
            (pt[1] as num).toDouble(),
          ));
        }
      } else if (type == 'Polygon') {
        final ring = (geom['coordinates'] as List).first as List<dynamic>;
        for (final pt in ring) {
          points.add(Offset(
            (pt[0] as num).toDouble(),
            (pt[1] as num).toDouble(),
          ));
        }
      } else if (type == 'MultiPolygon') {
        for (final poly in geom['coordinates'] as List<dynamic>) {
          final ring = (poly as List).first as List<dynamic>;
          for (final pt in ring) {
            points.add(Offset(
              (pt[0] as num).toDouble(),
              (pt[1] as num).toDouble(),
            ));
          }
        }
      }
    }

    if (points.isEmpty) {
      debugPrint('No points found in outline GeoJSON');
      return;
    }

    // Calcul bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final pt in points) {
      minX = pt.dx < minX ? pt.dx : minX;
      minY = pt.dy < minY ? pt.dy : minY;
      maxX = pt.dx > maxX ? pt.dx : maxX;
      maxY = pt.dy > maxY ? pt.dy : maxY;
    }
    debugPrint('BBox: [$minX, $minY] to [$maxX, $maxY]');

    // Prépare transformation
    final geoWidth = maxX - minX;
    final geoHeight = maxY - minY;
    final scaleX = size.width / geoWidth;
    final scaleY = size.height / geoHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final dx = (size.width - geoWidth * scale) / 2;
    final dy = (size.height - geoHeight * scale) / 2;
    debugPrint('Scale: $scale, Offset: ($dx,$dy)');

    canvas.save();
    canvas.translate(dx, dy + geoHeight * scale);
    canvas.scale(scale, -scale);
    canvas.translate(-minX, -minY);

    // Trace le cadre
    final rect = Rect.fromLTWH(minX, minY, geoWidth, geoHeight);
    canvas.drawRect(rect, bboxPaint);

    // Trace les points avec un rayon de 5
    for (final pt in points) {
      canvas.drawCircle(pt, 0.2, pointPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
