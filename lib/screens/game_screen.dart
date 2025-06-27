import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/map_widget.dart';
import '../models/game_config.dart';
import '../icons/flag_sprite_order.dart';

/// Écran de quiz géographique configuré dynamiquement
class GameScreen extends StatefulWidget {
  final GameConfig config;
  final String language;

  const GameScreen({
    Key? key,
    required this.config,
    required this.language,
  }) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _correctCount = 0;
  int _errorCount = 0;
  int _jokerCount = 0;
  int _combo = 0;
  int _score = 0;
  int _lastScoreGained = 0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _chronoStarted = false;
  String _elapsed = '00:00';
  bool _loading = true;
  String? _error;
  bool _showWrongFlash = false;
  Key _mapKey = UniqueKey();
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
  ui.Image? _spriteImage;
  double? _spriteSize;
  static const int _columns = 10;
  final AssetImage _spriteProvider = const AssetImage('assets/fonts/flags_sprite.png');

  double _comboMultiplier(int combo) {
    if (combo >= 40) return 2.0;
    if (combo >= 30) return 1.75;
    if (combo >= 20) return 1.5;
    if (combo >= 10) return 1.25;
    return 1.0;
  }

  void _addScore() {
    final multiplier = _comboMultiplier(_combo);
    _lastScoreGained = (100 * multiplier).round();
    _score += _lastScoreGained;
  }

  void _resetCombo() {
    _combo = 0;
  }

  void _incrementCombo() {
    _combo++;
  }

  @override
  void initState() {
    super.initState();
    _loadSprite();
    _startQuiz();
  }

  // ... le reste du code reste inchangé jusqu'à _handleTap

  void _handleTap(String? tappedIso) {
    if (!_chronoStarted) {
      _startChrono();
      _chronoStarted = true;
    }
    if (_currentIso == null) return;
    final iso = _currentIso!;
    if (tappedIso == iso) {
      setState(() {
        _correctCount++;
        _incrementCombo();
        _addScore();
        _discovered.add(iso);
        _remaining.remove(iso);
        _failedTrialsByIso.remove(iso);
      });
      _pickNext();
    } else {
      _resetCombo();
      _taps++;
      if (_taps < 2) {
        _showFlash(durationMs: 80);
      } else {
        setState(() => _errorCount++);
        final count = (_failedTrialsByIso[iso] ?? 0) + 1;
        _failedTrialsByIso[iso] = count;
        if (count < 3) {
          _showFlash(durationMs: 80);
          setState(() {
            _remaining.remove(iso);
            _remaining.add(iso);
          });
          _pickNext();
        } else {
          _showJokerDialog();
        }
      }
    }
  }

// ... autres méthodes conservées
}
