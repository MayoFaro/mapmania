// lib/screens/test_fond_image.dart

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Écran de test pour superposer un fond de relief avec les frontières des pays d'Afrique
class TestFondImageScreen extends StatefulWidget {
  const TestFondImageScreen({Key? key}) : super(key: key);

  @override
  _TestFondImageScreenState createState() => _TestFondImageScreenState();
}

class _TestFondImageScreenState extends State<TestFondImageScreen> {
  ui.Image? _backgroundImage;
  Map<String, dynamic>? _countriesJson;

  @override
  void initState() {
    super.initState();
    _loadBackgroundImage();
    _loadCountriesGeoJson();
  }

  /// Charge l'image de relief "relief.png" depuis les assets
  Future<void> _loadBackgroundImage() async {
    final data = await rootBundle.load('assets/relief.png');
    final bytes = Uint8List.view(data.buffer);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    setState(() => _backgroundImage = frame.image);
  }

  /// Charge le GeoJSON des pays d'Afrique depuis "assets/maps/af.geojson"
  Future<void> _loadCountriesGeoJson() async {
    final jsonStr = await rootBundle.loadString('assets/maps/af.geojson');
    setState(() => _countriesJson = json.decode(jsonStr) as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    if (_backgroundImage == null || _countriesJson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test Fond & Map')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Test Fond & Map')),
      body: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _FondMapPainter(
          background: _backgroundImage!,
          countriesJson: _countriesJson!,
        ),
      ),
    );
  }
}

/// CustomPainter qui dessine le relief en fond et superpose les frontières des pays
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

    // 1. Dessine l'image de fond réduite : 50% hauteur, 50% largeur,
    //    centrée puis ajustée vers le haut et la gauche.
    const horizontalOffsetFraction = 0.053; // déplace de 10% de la largeur vers la gauche
    const verticalOffsetFraction = 0.11;   // déplace de 10% de la hauteur vers le haut

    final imageWidth = background.width.toDouble();
    final imageHeight = background.height.toDouble();
    final dstWidth = imageWidth * 0.534;  // largeur à 50%
    final dstHeight = imageHeight * 0.534; // hauteur à 50%

    // Calcul pour centrer l'image réduite
    double dxBg = (size.width - dstWidth) / 2;
    double dyBg = (size.height - dstHeight) / 2;
    // Applique les offsets négatifs pour remonter et décaler à gauche
    dxBg -= dstWidth * horizontalOffsetFraction;
    dyBg -= dstHeight * verticalOffsetFraction;

    final srcRect = Rect.fromLTWH(0, 0, imageWidth, imageHeight);
    final dstRect = Rect.fromLTWH(dxBg, dyBg, dstWidth, dstHeight);
    canvas.drawImageRect(background, srcRect, dstRect, paint);

    // 2. Récupère tous les anneaux (rings) des géométries des pays
    final rings = <List<dynamic>>[];
    for (final feature in countriesJson['features'] as List) {
      _collectRings(feature['geometry'], rings);
    }
    if (rings.isEmpty) {
      debugPrint('Aucun contour de pays trouvé');
      return;
    }

    // 3. Calcule la bounding box (minX, minY, maxX, maxY)
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final ring in rings) {
      for (final coord in ring) {
        final x = (coord[0] as num).toDouble();
        final y = (coord[1] as num).toDouble();
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    final geoWidth = maxX - minX;
    final geoHeight = maxY - minY;

    // 4. Calcule le scale (zoom) et la translation pour centrer la carte
    final scaleX = size.width / geoWidth;
    final scaleY = size.height / geoHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final dx = (size.width - geoWidth * scale) / 2 - minX * scale;
    final dy = (size.height - geoHeight * scale) / 2 + maxY * scale;

    // 5. Applique la translation et l’inversion de l’axe Y
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, -scale);

    // 6. Prépare le Paint pour tracer les frontières
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey.shade300
      ..strokeWidth = 1 / scale;

    // 7. Trace chaque anneau pour dessiner les contours
    for (final ring in rings) {
      final path = Path();
      bool first = true;
      for (final coord in ring) {
        final x = (coord[0] as num).toDouble();
        final y = (coord[1] as num).toDouble();
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, borderPaint);
    }

    canvas.restore();
  }

  /// Extrait les anneaux de polygones ou multipolygones
  void _collectRings(dynamic geom, List<List<dynamic>> rings) {
    final type = geom['type'] as String;
    final coords = geom['coordinates'];
    if (type == 'Polygon') {
      for (final ring in coords as List) {
        rings.add(ring as List<dynamic>);
      }
    } else if (type == 'MultiPolygon') {
      for (final poly in coords as List) {
        for (final ring in poly as List) {
          rings.add(ring as List<dynamic>);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FondMapPainter old) {
    return old.background != background || old.countriesJson != countriesJson;
  }
}
