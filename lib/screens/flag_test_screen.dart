import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../icons/flag_sprite_order.dart'; // Liste générée automatiquement

class FlagTestScreen extends StatefulWidget {
  const FlagTestScreen({Key? key}) : super(key: key);

  @override
  _FlagTestScreenState createState() => _FlagTestScreenState();
}

class _FlagTestScreenState extends State<FlagTestScreen> {
  final List<String> _isoCodes = flagSpriteOrder;
  static const int columns = 10;
  int _currentIndex = 0; // Commence à 0 au lieu de 1
  Timer? _timer;

  double? _spriteSize; // Taille d'un seul drapeau
  ImageInfo? _imageInfo;

  final AssetImage _spriteProvider = const AssetImage('assets/fonts/flags_sprite.png');

  @override
  void initState() {
    super.initState();
    _loadImage();
    _startTimer();
  }

  void _loadImage() {
    final stream = _spriteProvider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) {
        setState(() {
          _imageInfo = info;
          // Calculer la taille d'un seul drapeau
          _spriteSize = info.image.width.toDouble() / columns;
        });
      }
    }));
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _isoCodes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_imageInfo == null || _spriteSize == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final index = _currentIndex;
    final row = index ~/ columns;
    final col = index % columns;
    final iso = _isoCodes[index];

    return Scaffold(
      appBar: AppBar(
        title: Text('Sprite Map - $iso (#${index + 1}/${_isoCodes.length})'),
        centerTitle: true,
      ),
      body: Center(
        child: SizedBox(
          width: _spriteSize,
          height: _spriteSize,
          child: CustomPaint(
            painter: _FlagSpritePainter(
              image: _imageInfo!.image,
              spriteSize: _spriteSize!,
              columns: columns,
              row: row,
              col: col,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagSpritePainter extends CustomPainter {
  final ui.Image image;
  final double spriteSize;
  final int columns;
  final int row;
  final int col;

  _FlagSpritePainter({
    required this.image,
    required this.spriteSize,
    required this.columns,
    required this.row,
    required this.col,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(
      col * spriteSize,
      row * spriteSize,
      spriteSize,
      spriteSize,
    );

    final dstRect = Rect.fromLTWH(
      0,
      0,
      spriteSize,
      spriteSize,
    );

    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _FlagSpritePainter oldDelegate) {
    return oldDelegate.row != row || oldDelegate.col != col;
  }
}