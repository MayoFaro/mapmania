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
  // ===== Champs de scoring =====
  int _correctCount = 0;
  int _errorCount = 0;
  int _jokerCount = 0;

  // Chronomètre
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _chronoStarted = false;
  String _elapsed = '00:00';

  // États divers
  bool _loading = true;
  String? _error;
  bool _showWrongFlash = false;
  Key _mapKey = UniqueKey();

  // Pools & état quiz
  late Map<String, dynamic> _countriesData;
  late List<String> _countryPool;
  late List<String> _capitalPool;
  late List<String> _flagPool;
  int _phase = 0;
  late List<String> _remaining;
  String? _currentIso;
  String? _currentName;
  final Set<String> _discovered = {};
  final Map<String, int> _failedTrialsByIso = {};
  int _taps = 0;

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

  /// Charge la sprite-sheet des drapeaux
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

  /// Initialise le quiz et prépare la première phase
  Future<void> _startQuiz() async {
    try {
      final raw = await rootBundle.loadString('assets/datas/countries.json');
      final dataAll = json.decode(raw) as List<dynamic>;
      _countriesData = {for (var c in dataAll) c['code'] as String: c};

      final allCodes = dataAll
          .where((c) => c['continent'] == 'AF')
          .map((c) => c['code'] as String)
          .toList()
        ..shuffle(Random());

      _countryPool = allCodes.take(10).toList();
      _capitalPool = allCodes.skip(10).take(10).toList();
      _flagPool = allCodes
          .where((iso) => flagSpriteOrder.contains(iso))
          .toList()
        ..shuffle(Random());
      _flagPool = _flagPool.take(5).toList();

      setState(() => _loading = false);
      _loadPhase();
      // Démarre le chrono après 3s si pas déjà démarré
      Timer(const Duration(seconds: 3), () {
        if (!_chronoStarted) {
          _startChrono();
          _chronoStarted = true;
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erreur chargement données: \$e';
      });
    }
  }

  /// Démarre ou reprend le chrono
  void _startChrono() {
    if (!_stopwatch.isRunning) _stopwatch.start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sec = _stopwatch.elapsed.inSeconds;
      setState(() {
        _elapsed = '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
      });
    });
  }

  /// Met en pause le chrono
  void _stopChrono() {
    _stopwatch.stop();
    _timer?.cancel();
  }

  /// Configure la liste d'items pour la phase actuelle
  void _loadPhase() {
    _taps = 0;
    _failedTrialsByIso.clear();
    _discovered.clear();
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

  /// Sélectionne l'item suivant ou termine la phase sans répétition consécutive
  void _pickNext() {
    _taps = 0;
    if (_remaining.isEmpty) {
      _showPhaseEnd();
      return;
    }
    String iso;
    do {
      iso = _remaining[Random().nextInt(_remaining.length)];
    } while (iso == _currentIso && _remaining.length > 1);
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

  /// Affiche le dialogue de fin de phase (pause) et configure la suite
  void _showPhaseEnd() {
    _stopChrono();
    final labels = ['Pays', 'Capitales', 'Drapeaux'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('${labels[_phase]} terminée'),
        content: const Text('Appuyez sur OK pour continuer'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final maxPhase = widget.formula == GameFormula.complete ? 2 : 1;
              if (_phase < maxPhase) {
                _phase++; _loadPhase(); _startChrono();
              } else {
                _stopChrono();
                setState(() {
                  _currentIso = null;
                  _currentName = 'Quiz terminé en $_elapsed';
                });
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Gère la sélection de l'utilisateur
  void _handleTap(String? tappedIso) {
    if (!_chronoStarted) { _startChrono(); _chronoStarted = true; }
    if (_currentIso == null) return;
    final iso = _currentIso!;
    if (tappedIso == iso) {
      setState(() {
        _correctCount++;
        _discovered.add(iso);
        _remaining.remove(iso);
        _failedTrialsByIso.remove(iso);
      });
      _pickNext();
    } else {
      _taps++;
      if (_taps < 2) {
        _showFlash(durationMs: 80);
      } else {
        setState(() => _errorCount++);
        final count = (_failedTrialsByIso[iso] ?? 0) + 1;
        _failedTrialsByIso[iso] = count;
        if (count < 3) {
          _showFlash(durationMs: 80);
          setState(() { _remaining.remove(iso); _remaining.add(iso); });
          _pickNext();
        } else {
          _showJokerDialog();
        }
      }
    }
  }

  /// Flash visuel pour erreur
  void _showFlash({required int durationMs}) {
    setState(() => _showWrongFlash = true);
    Future.delayed(Duration(milliseconds: durationMs), () {
      setState(() => _showWrongFlash = false);
    });
  }

  /// Dialogue pour proposer un joker
  void _showJokerDialog() {
    final iso = _currentIso!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Joker'),
        content: Text('3 essais échoués pour \$_currentName. Voulez-vous un joker ?'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); setState(() => _jokerCount++); _revealHint(); }, child: const Text('Oui')),
          TextButton(onPressed: () { Navigator.pop(context); setState(() { _remaining.remove(iso); _remaining.add(iso); }); _pickNext(); }, child: const Text('Non')),
        ],
      ),
    );
  }

  /// Clignotement pour révéler l'indice
  void _revealHint() {
    setState(() => _mapKey = UniqueKey());
    const blinkIntervalMs = 150;
    const totalDurationMs = 5000;
    final ticksMax = totalDurationMs ~/ blinkIntervalMs;
    int ticks = 0;
    Timer.periodic(Duration(milliseconds: blinkIntervalMs), (timer) {
      ticks++;
      setState(() {
        if (_discovered.contains(_currentIso!)) {
          _discovered.remove(_currentIso!);
        } else {
          _discovered.add(_currentIso!);
        }
      });
      if (ticks >= ticksMax) {
        timer.cancel();
        setState(() { _discovered.add(_currentIso!); _remaining.remove(_currentIso!); });
        _pickNext();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Erreur')), body: Center(child: Text(_error!)));
    return Scaffold(
      appBar: AppBar(title: _buildAppBarTitle(), centerTitle: true),
      body: Stack(children: [
        MapWidget(key: _mapKey, continentCode: 'AF', discoveredCountries: _discovered, gameMode: widget.difficulty, onTapCountry: _handleTap),
        Positioned(top: MediaQuery.of(context).padding.top + 8, left: 16, child: Text('⏱ $_elapsed', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        Positioned(top: MediaQuery.of(context).padding.top + 8, right: 16, child: Text('✔︎ $_correctCount  ❌ $_errorCount  🎫 $_jokerCount', style: const TextStyle(fontSize: 14))),
        if (_showWrongFlash) Positioned.fill(child: Container(color: Colors.red.withOpacity(0.3))),
      ]),
    );
  }

  /// Construction du titre AppBar selon la phase
  Widget _buildAppBarTitle() {
    if (_phase < 2) {
      return Text(_currentName ?? '', textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 18));
    }
    if (_currentIso != null && _spriteImage != null && _spriteSize != null) {
      final idx = flagSpriteOrder.indexOf(_currentIso!);
      final row = idx ~/ _columns;
      final col = idx % _columns;
      final displaySize = _spriteSize! * 0.8;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(size: Size(displaySize, displaySize), painter: _FlagSpritePainter(image: _spriteImage!, spriteSize: _spriteSize!, columns: _columns, row: row, col: col)),
        const SizedBox(width: 8),
        Text(_currentIso!, style: const TextStyle(fontSize: 20)),
      ]);
    }
    return Text(_currentName ?? '', textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 18));
  }
}

/// Painter pour afficher le drapeau depuis la sprite-sheet
class _FlagSpritePainter extends CustomPainter {
  final ui.Image image;
  final double spriteSize;
  final int columns;
  final int row;
  final int col;

  _FlagSpritePainter({required this.image, required this.spriteSize, required this.columns, required this.row, required this.col});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(col * spriteSize, row * spriteSize, spriteSize, spriteSize);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _FlagSpritePainter old) => old.row != row || old.col != col;
}
