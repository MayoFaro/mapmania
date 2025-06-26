import 'dart:async';
import 'package:flutter/material.dart';

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /// Chrono
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isChronoRunning = false;

  /// Counters
  int _correctCount = 0;
  int _errorCount = 0;
  int _jokerCount = 0;

  /// Phase tracking
  int _currentPhase = 1;
  final int _questionsPerPhase = 54;
  int _answeredInPhase = 0;

  @override
  void initState() {
    super.initState();
    _startChrono();  // Démarre le chrono en début de jeu
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Démarre le chronomètre
  void _startChrono() {
    _timer?.cancel();
    setState(() {
      _secondsElapsed = 0;
      _isChronoRunning = true;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  /// Arrête (pause) le chronomètre
  void _stopChrono() {
    _timer?.cancel();
    setState(() {
      _isChronoRunning = false;
    });
  }

  /// Appelé quand une phase est terminée
  void _onPhaseComplete() {
    _stopChrono();  // Arrête le chrono

    // Affiche un SnackBar avec option de reprendre
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phase $_currentPhase terminée !'),
        action: SnackBarAction(
          label: 'Reprendre',
          onPressed: () {
            // Réinitialise le compteur de la phase et repart le chrono
            setState(() {
              _answeredInPhase = 0;
              _currentPhase++;
            });
            _startChrono();
          },
        ),
      ),
    );
  }

  /// Gestion de la réponse utilisateur
  void _onAnswer({ required bool correct, bool usedJoker = false }) {
    // Met à jour les compteurs
    setState(() {
      _answeredInPhase++;
      if (correct) {
        _correctCount++;
      } else {
        _errorCount++;
      }
      if (usedJoker) {
        _jokerCount++;
      }
    });

    // Si la phase est terminée
    if (_answeredInPhase >= _questionsPerPhase) {
      _onPhaseComplete();
    }
  }

  /// Formate en mm:ss
  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jeu géographique – Phase $_currentPhase')),
      body: Column(
        children: [
          // Affichage des compteurs et chrono
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Temps : ${_formatTime(_secondsElapsed)}'),
                Text('✔️ : $_correctCount'),
                Text('❌ : $_errorCount'),
                Text('🎫 : $_jokerCount'),
              ],
            ),
          ),
          // TODO: Insérer ici la map et la logique de sélection des pays
          Expanded(
            child: Center(child: Text('Contenu de la phase en cours')),
          ),
        ],
      ),
    );
  }
}
