// lib/screens/test_fond_image_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:math';

class TestFondImageScreen extends StatefulWidget {
  const TestFondImageScreen({Key? key}) : super(key: key);

  @override
  State<TestFondImageScreen> createState() => _TestFondImageScreenState();
}

class _TestFondImageScreenState extends State<TestFondImageScreen> {
  // État
  ui.Image? _reliefImage;
  List<Offset> _borderPoints = [];
  bool _isLoading = true;
  String? _debugInfo;
  final TransformationController _transformController = TransformationController();

  // Constantes ajustables
  static const String _reliefPath = 'assets/maps/africa/relief.png';
  static const String _geoJsonPath = 'assets/maps/africa/af.geojson';
  static const Rect _africaBounds = Rect.fromLTRB(-25, 10, 35, -17); // Ajusté selon vos points // À ajuster selon votre image

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      // 1. Charge l'image PNG
      final ByteData imageData = await rootBundle.load(_reliefPath);
      _reliefImage = await decodeImageFromList(imageData.buffer.asUint8List());
      _debugInfo = 'Image loaded: ${_reliefImage!.width}x${_reliefImage!.height}';

      // 2. Charge et convertit le GeoJSON
      final geoJson = await rootBundle.loadString(_geoJsonPath);
      _borderPoints = _convertGeoJsonToPoints(geoJson);
      _debugInfo = '${_debugInfo}\nPoints: ${_borderPoints.length}';

      // 3. Vérification des coordonnées
      if (_borderPoints.isNotEmpty) {
        final firstPoint = _borderPoints.first;
        final lastPoint = _borderPoints.last;
        _debugInfo = '${_debugInfo}\nFirst: (${firstPoint.dx}, ${firstPoint.dy})';
        _debugInfo = '${_debugInfo}\nLast: (${lastPoint.dx}, ${lastPoint.dy})';
      }

      setState(() => _isLoading = false);
    } catch (e) {
      _debugInfo = 'Erreur: $e';
      setState(() => _isLoading = false);
    }
  }

  List<Offset> _convertGeoJsonToPoints(String geoJson) {
    final List<Offset> points = [];

    try {
      final data = json.decode(geoJson);
      for (final feature in data['features'] as List) {
        final geometry = feature['geometry'];
        points.addAll(_extractPointsFromGeometry(geometry));
      }
    } catch (e) {
      _debugInfo = 'GeoJSON error: $e';
    }
    return points;
  }

  List<Offset> _extractPointsFromGeometry(dynamic geometry) {
    final List<Offset> points = [];
    final type = geometry['type'];
    final coords = geometry['coordinates'];

    if (type == 'Polygon') {
      for (final ring in coords as List) {
        for (final coord in ring as List) {
          points.add(Offset(
            (coord[0] as num).toDouble(),
            -(coord[1] as num).toDouble(), // Inversion Y
          ));
        }
      }
    } else if (type == 'MultiPolygon') {
      for (final polygon in coords as List) {
        for (final ring in polygon as List) {
          for (final coord in ring as List) {
            points.add(Offset(
              (coord[0] as num).toDouble(),
              -(coord[1] as num).toDouble(),
            ));
          }
        }
      }
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Carte Afrique')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // Fond interactif
          InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.1,
            maxScale: 5.0,
            child: CustomPaint(
              size: Size.infinite,
              painter: _AfricaMapPainter(
                reliefImage: _reliefImage!,
                borderPoints: _borderPoints,
                bounds: _africaBounds,
              ),
            ),
          ),

          // Overlay de debug
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: EdgeInsets.all(8),
              color: Colors.black.withOpacity(0.5),
              child: Text(
                _debugInfo ?? 'No debug info',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AfricaMapPainter extends CustomPainter {
  final ui.Image reliefImage;
  final List<Offset> borderPoints;
  final Rect bounds;

  _AfricaMapPainter({
    required this.reliefImage,
    required this.borderPoints,
    required this.bounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Calcul des échelles
    final imageAspect = reliefImage.width / reliefImage.height;
    final screenAspect = size.width / size.height;

    double scale, dx = 0, dy = 0;
    if (screenAspect > imageAspect) {
      scale = size.height / reliefImage.height;
      dx = (size.width - reliefImage.width * scale) / 2;
    } else {
      scale = size.width / reliefImage.width;
      dy = (size.height - reliefImage.height * scale) / 2;
    }

    @override
    void paint(Canvas canvas, Size size) {
      // 1. Dessin du relief (inchangé)

      // 2. Transformation géographique CORRIGÉE :
      if (borderPoints.isNotEmpty) {
        final geoScaleX = reliefImage.width / bounds.width;
        final geoScaleY = reliefImage.height / bounds.height;
        final geoScale = min(geoScaleX, geoScaleY);

        // Décalage corrigé :
        final geoOffset = Offset(
          dx + (bounds.left.abs() * geoScale * scale), // Ajustement X
          dy + (bounds.top * geoScale * scale),        // Ajustement Y
        );

        canvas.save();
        canvas.translate(geoOffset.dx, geoOffset.dy);
        canvas.scale(geoScale * scale, -geoScale * scale); // Notez l'inversion Y

        // Dessin des frontières en ROUGE pour mieux voir :
        final path = Path();
        path.moveTo(borderPoints[0].dx, borderPoints[0].dy);
        for (final point in borderPoints.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }

        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.red // Couleur visible
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0, // Épaisseur augmentée
        );

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AfricaMapPainter old) {
    return old.reliefImage != reliefImage || old.borderPoints != borderPoints;
  }
}