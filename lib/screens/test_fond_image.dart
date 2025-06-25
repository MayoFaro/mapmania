// lib/screens/test_fond_image.dart

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Écran de test pour superposer un fond de relief avec les frontières des pays d'Afrique
/// et afficher dynamiquement les dimensions de la bbox géographique
class TestFondImageScreen extends StatefulWidget {
  const TestFondImageScreen({Key? key}) : super(key: key);

  @override
  _TestFondImageScreenState createState() => _TestFondImageScreenState();
}

class _TestFondImageScreenState extends State<TestFondImageScreen> {
  ui.Image? _backgroundImage;
  Map<String, dynamic>? _countriesJson;
  double? _geoWidth;
  double? _geoHeight;

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
    _loadCountriesGeoJson();
  }

  /// Charge l'image de relief et stocke dans _backgroundImage
  Future<void> _loadBackgroundImage() async {
    final data = await rootBundle.load('assets/relief.png');
    final bytes = Uint8List.view(data.buffer);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() => _backgroundImage = frame.image);
  }

  /// Charge le GeoJSON et calcule la bbox (geoWidth, geoHeight)
  Future<void> _loadCountriesGeoJson() async {
    final jsonStr = await rootBundle.loadString('assets/maps/af.geojson');
    final geo = json.decode(jsonStr) as Map<String, dynamic>;

    // Calcul de la bounding box
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final feature in geo['features'] as List) {
      final geom = feature['geometry'];
      Iterable rings;
      if (geom['type'] == 'Polygon') {
        rings = (geom['coordinates'] as List).cast<List<dynamic>>();
      } else {
        rings = (geom['coordinates'] as List)
            .expand((poly) => (poly as List).cast<List<dynamic>>());
      }
      for (final ring in rings) {
        for (final pt in ring) {
          final x = (pt[0] as num).toDouble();
          final y = (pt[1] as num).toDouble();
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }
    final width = maxX - minX;
    final height = maxY - minY;

    debugPrint('🌍 geoWidth = $width   geoHeight = $height');

    setState(() {
      _countriesJson = geo;
      _geoWidth = width;
      _geoHeight = height;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Affiche la bbox avant de dessiner si déjà calculée
    return Scaffold(
      appBar: AppBar(title: const Text('Test Fond & Map')),
      body: _backgroundImage == null || _countriesJson == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_geoWidth != null && _geoHeight != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'geoWidth: ${_geoWidth!.toStringAsFixed(2)}, '
                    'geoHeight: ${_geoHeight!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          Expanded(
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _FondMapPainter(
                background: _backgroundImage!,
                countriesJson: _countriesJson!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter pour dessiner le relief et les frontières avec même transform
class _FondMapPainter extends CustomPainter {
  final ui.Image background;
  final Map<String, dynamic> countriesJson;

  _FondMapPainter({
    required this.background,
    required this.countriesJson,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // Extraction des anneaux
    final rings = <List<dynamic>>[];
    for (final feature in countriesJson['features'] as List) {
      _collectRings(feature['geometry'], rings);
    }
    if (rings.isEmpty) return;

    // Calcul bbox
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final ring in rings) {
      for (final coord in ring) {
        final x = (coord[0] as num).toDouble();
        final y = (coord[1] as num).toDouble();
        minX = x < minX ? x : minX;
        minY = y < minY ? y : minY;
        maxX = x > maxX ? x : maxX;
        maxY = y > maxY ? y : maxY;
      }
    }
    final geoWidth = maxX - minX;
    final geoHeight = maxY - minY;

    // Scale & translate
    final scaleX = size.width / geoWidth;
    final scaleY = size.height / geoHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final dx = (size.width - geoWidth * scale) / 2 - minX * scale;
    final dy = (size.height - geoHeight * scale) / 2 + maxY * scale;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, -scale);

    // Dessin du fond
    final src = Rect.fromLTWH(0, 0, background.width.toDouble(), background.height.toDouble());
    final dst = Rect.fromLTWH(minX, minY, geoWidth, geoHeight);
    canvas.drawImageRect(background, src, dst, paint);

    // Dessin contours
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey.shade300
      ..strokeWidth = 1 / scale;
    for (final ring in rings) {
      final path = Path();
      for (int i = 0; i < ring.length; i++) {
        final x = (ring[i][0] as num).toDouble();
        final y = (ring[i][1] as num).toDouble();
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, borderPaint);
    }
    canvas.restore();
  }

  void _collectRings(dynamic geom, List<List<dynamic>> rings) {
    final type = geom['type'] as String;
    final coords = geom['coordinates'];
    if (type == 'Polygon') {
      for (final ring in coords as List) rings.add(ring as List<dynamic>);
    } else if (type == 'MultiPolygon') {
      for (final poly in coords as List)
        for (final ring in poly as List) rings.add(ring as List<dynamic>);
    }
  }

  @override
  bool shouldRepaint(covariant _FondMapPainter old) =>
      old.background != background || old.countriesJson != countriesJson;
}
