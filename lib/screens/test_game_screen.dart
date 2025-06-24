// lib/screens/test_game_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/map_widget.dart';
import '../models/game_config.dart';

/// Écran de test du jeu :
/// Affiche la carte (frontières visibles), un prompt fixe, et gère le tap.
class TestGameScreen extends StatefulWidget {
  const TestGameScreen({Key? key}) : super(key: key);

  @override
  _TestGameScreenState createState() => _TestGameScreenState();
}

class _TestGameScreenState extends State<TestGameScreen> {
  static const String _continentCode = 'AF';
  static const String _targetCountryName = 'Gabon';
  static const String _targetCountryCode = 'GA'; // ISO Alpha-2 pour le Gabon

  // Ensemble des pays correctement découverts (ici, au plus le Gabon)
  final Set<String> _discovered = {};

  // Pour afficher brièvement le message d'erreur
  bool _showError = false;
  Timer? _errorTimer;

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  void _onTapCountry(String countryCode) {
    if (countryCode.toUpperCase() == _targetCountryCode) {
      // Bonne réponse : on surligne en vert
      setState(() {
        _discovered.add(_targetCountryCode);
        _showError = false;
      });
    } else {
      // Mauvaise réponse : on affiche un message temporaire
      setState(() {
        _showError = true;
      });
      _errorTimer?.cancel();
      _errorTimer = Timer(const Duration(seconds: 1), () {
        setState(() {
          _showError = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Jeu : Positionner un pays')),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Affichage du prompt
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Cliquez sur : $_targetCountryName',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              // Carte interactive

            ],
          ),
          // Message d'erreur overlay
          if (_showError)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Mauvaise réponse',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
