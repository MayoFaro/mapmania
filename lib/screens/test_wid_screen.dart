// lib/screens/test_wid_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/map_widget.dart';
import '../models/game_config.dart';
import '../icons/flag_sprite_order.dart';

/// Écran de quiz géographique en 3 phases :
/// 1) 10 pays
/// 2) 10 capitales
/// 3) 5 drapeaux via sprite-sheet
class TestWidScreen extends StatefulWidget {
  final String language;
  final GameFormula formula;
  final GameMode difficulty;

  const TestWidScreen({
    Key? key,
    required this.language,
    required this.formula,
    required this.difficulty,
  }) : super(key: key);

  @override
  _TestWidScreenState createState() => _TestWidScreenState();
}

class _TestWidScreenState extends State<TestWidScreen> {
  /// Couleur du flash d'erreur (modifiable)
  final Color _flashColor = (Colors.redAccent[400] ?? Colors.redAccent).withAlpha(148);


  final Random _rng = Random();

  // JSON cache pour les noms
  late final Map<String, dynamic> _countriesData;
  // Pools des phases
  late List<String> _countryPool;
  late List<String> _capitalPool;
  late List<String> _flagPool;

  // État du quiz
  int _phase = 0; // 0=pays,1=capitales,2=drapeaux
  late List<String> _remaining;
  String? _currentIso;
  String? _currentName;
  final Set<String> _discovered = {};

  // Tentatives sur l'item courant (max 2)
  int _attempts = 0;

  // Chrono
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsed = '00:00';

  bool _loading = true;
  String? _error;
  bool _showWrongFlash = false;

  // Sprite drapeaux
  ui.Image? _spriteImage;
  double? _spriteSize;
  static const int _columns = 10;
  final AssetImage _spriteProvider = const AssetImage('assets/fonts/flags_sprite.png');

  @override
  void initState() {
    super.initState();
    _loadSprite();
    _startQuiz();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  /// Charge la sprite-sheet et calcule la taille d'une tuile
  void _loadSprite() {
    _spriteProvider
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((info, _) {
      setState(() {
        _spriteImage = info.image;
        _spriteSize = info.image.width / _columns;
      });
    }));
  }

  /// Initialise les données et pools, lance la phase 1
  Future<void> _startQuiz() async {
    try {
      final raw = await rootBundle.loadString('assets/datas/countries.json');
      final dataAll = json.decode(raw) as List<dynamic>;
      _countriesData = {for (var c in dataAll) c['code'] as String: c};

      final all = dataAll
          .where((c) => c['continent'] == 'AF')
          .map((c) => c['code'] as String)
          .toList()..shuffle(_rng);

      _countryPool = all.take(10).toList();
      _capitalPool = all.skip(10).take(10).toList();
      _flagPool = all.where((iso) => flagSpriteOrder.contains(iso)).toList()
        ..shuffle(_rng);
      _flagPool = _flagPool.take(5).toList();

      setState(() => _loading = false);
      _startChrono();
      _loadPhase();
    } catch (e) {
      setState(() {
        _error = 'Erreur chargement données: $e';
        _loading = false;
      });
    }
  }

  /// Démarre le chronomètre
  void _startChrono() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sec = _stopwatch.elapsed.inSeconds;
      setState(() {
        final m = (sec ~/ 60).toString().padLeft(2, '0');
        final s = (sec % 60).toString().padLeft(2, '0');
        _elapsed = '$m:$s';
      });
    });
  }

  /// Charge la liste _remaining selon la phase et réinitialise tentatives
  void _loadPhase() {
    _discovered.clear();
    _attempts = 0;
    switch (_phase) {
      case 0:
        _remaining = List.from(_countryPool);
        break;
      case 1:
        _remaining = List.from(_capitalPool);
        break;
      default:
        _remaining = List.from(_flagPool);
    }
    _pickNext();
  }

  /// Sélectionne et affiche le prochain item, ou termine la phase
  void _pickNext() {
    _attempts = 0;
    if (_remaining.isEmpty) {
      _showPhaseEnd();
      return;
    }
    final iso = _remaining[_rng.nextInt(_remaining.length)];
    setState(() {
      _currentIso = iso;
      if (_phase < 2) {
        final field = _phase == 0 ? 'name' : 'capital';
        _currentName = (_countriesData[iso]![field] as Map)[widget.language] as String;
      } else {
        _currentName = iso;
      }
    });
  }

  /// Affiche un dialog de fin de phase, puis passe à la suivante ou termine
  void _showPhaseEnd() {
    final labels = ['Pays', 'Capitales', 'Drapeaux'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('${labels[_phase]} terminée'),
        content: const Text('Appuyez sur OK pour continuer'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) {
      if (_phase < (widget.formula == GameFormula.complete ? 2 : 1)) {
        setState(() => _phase++);
        _loadPhase();
      } else {
        _stopwatch.stop();
        _timer?.cancel();
        setState(() {
          _currentIso = null;
          _currentName = 'Quiz terminé en $_elapsed';
        });
      }
    });
  }

  /// Gestion du tap sur la carte avec jusqu'à 2 essais
  void _handleTap(String? tappedIso) {
    if (_currentIso == null) return;
    final correct = tappedIso == _currentIso;
    if (correct) {
      // Succès : on passe au suivant
      _discovered.add(_currentIso!);
      _remaining.remove(_currentIso!);
      _pickNext();
    } else {
      if (_attempts == 0) {
        // Premier essai incorrect : flash rouge unique
        setState(() => _showWrongFlash = true);
        Future.delayed(const Duration(milliseconds: 100), () {
          setState(() => _showWrongFlash = false);
        });
        _attempts = 1;
      } else {
        // Deuxième essai incorrect : triple flash puis suivant
        for (int i = 0; i < 3; i++) {
          Future.delayed(Duration(milliseconds: i * 150), () {
            setState(() => _showWrongFlash = true);
          });
          Future.delayed(Duration(milliseconds: i * 150 + 80), () {
            setState(() => _showWrongFlash = false);
          });
        }
        Future.delayed(const Duration(milliseconds: 450), () {
          _remaining.remove(_currentIso!);
          _pickNext();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Erreur')), body: Center(child: Text(_error!)));

    return Scaffold(
        appBar: AppBar(
          title: _buildAppBarTitle(),
          centerTitle: true,
        ),
        body: Stack(
          children: [
          MapWidget(
          continentCode: 'AF',
          discoveredCountries: _discovered,
          gameMode: widget.difficulty,
          onTapCountry: _handleTap,
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: Text(_elapsed, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: Text('${_discovered.length}/${_phase < 2 ? 10 : 5}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
        if (_showWrongFlash)
    Positioned.fill(
      child: Container(color: _flashColor),
    ),
    ],
    ),
    );
  }

  /// Construit le widget titre pour l'AppBar selon la phase
  Widget _buildAppBarTitle() {
    if (_phase < 2) {
      return Text(_currentName ?? '', textAlign: TextAlign.center, maxLines: 2);
    }
    // Phase drapeaux
    if (_currentIso != null && _spriteImage != null && _spriteSize != null) {
      final idx = flagSpriteOrder.indexOf(_currentIso!);
      final row = idx ~/ _columns;
      final col = idx % _columns;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(_spriteSize!, _spriteSize!),
            painter: _FlagSpritePainter(
              image: _spriteImage!,
              spriteSize: _spriteSize!,
              columns: _columns,
              row: row,
              col: col,
            ),
          ),
          const SizedBox(width: 8),
          Text(_currentIso!, style: const TextStyle(fontSize: 20)),
        ],
      );
    }
    return Text(_currentName ?? '', textAlign: TextAlign.center, maxLines: 2);
  }
}

/// Painter pour extraire une tuile de la sprite-sheet
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
    final src = Rect.fromLTWH(col * spriteSize, row * spriteSize, spriteSize, spriteSize);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _FlagSpritePainter old) => old.row != row || old.col != col;
}
