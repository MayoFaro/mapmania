// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import '../models/game_config.dart';
import '../services/game_service.dart';
import '../models/question.dart';
import '../widgets/countdown_timer.dart';
import '../widgets/map_widget.dart';

/// Écran principal de jeu : gère les phases (pays, capitales, drapeaux)
class GameScreen extends StatefulWidget {
  final GameConfig config;

  const GameScreen({Key? key, required this.config}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameService _service;
  late Question _currentQuestion;
  bool _isCountingDown = true;

  @override
  void initState() {
    super.initState();
    _service = GameService(widget.config);
    _initializeGame();
  }

  /// Initialise le service et lance le compte à rebours
  Future<void> _initializeGame() async {
    await _service.init();
    setState(() => _isCountingDown = true);
  }

  /// Appelé lorsque le compte à rebours est terminé
  void _onCountdownFinished() {
    setState(() {
      _isCountingDown = false;
      _currentQuestion = _service.nextQuestion();
    });
  }

  /// Gère le tap sur une frontière de pays
  void _onCountryTap(String code) {
    final correct = _service.submitAnswer(code);
    setState(() {
      if (!_service.isFinished) {
        _currentQuestion = _service.nextQuestion();
      } else {
        // TODO: naviguer vers l'écran de résultats
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCountingDown) {
      // Affiche uniquement le compte à rebours initial
      return Scaffold(
        backgroundColor: Colors.black87,
        body: CountdownTimer(
          seconds: 3,
          onFinished: _onCountdownFinished,
        ),
      );
    }

    // Partie de jeu active
    return Scaffold(
      appBar: AppBar(
        title: Text(_service.currentPhaseLabel),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _currentQuestion.prompt,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
              textAlign: TextAlign.center,
            ),
          ),

        ],
      ),
    );
  }
}
