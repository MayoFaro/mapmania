// lib/services/game_service.dart

import 'dart:collection';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import '../models/game_config.dart';
import '../models/country.dart';
import '../models/question.dart';

/// Service central qui gère la progression d'une partie.
class GameService {
  final GameConfig config;
  late final List<Country> _countries;      // tous les pays du continent
  final Set<String> _discovered = {};       // codes ISO trouvés
  int _index = 0;                           // position dans la liste de quiz
  GamePhase _phase = GamePhase.countries;   // phase actuelle

  GameService(this.config);

  /// Charge et prépare la liste des pays/capitales/drapeaux
  Future<void> init() async {
    final data = await rootBundle.loadString('assets/datas/countries.json');
    final Map<String, dynamic> decoded = json.decode(data) as Map<String, dynamic>;
    final List<dynamic> raw = decoded[config.continentCode] as List<dynamic>;
    _countries = raw.map((e) => Country.fromJson(e as Map<String, dynamic>)).toList();
    _countries.shuffle();
    _index = 0;
    _discovered.clear();
    _phase = GamePhase.countries;
  }

  /// Prochain prompt (change de phase si nécessaire)
  Question nextQuestion() {
    if (_phase == GamePhase.countries && _index >= _countries.length) {
      _phase = GamePhase.capitals;
      _index = 0;
    }
    if (_phase == GamePhase.capitals && _index >= _countries.length) {
      if (config.formula == GameFormula.complete) {
        _phase = GamePhase.flags;
        _index = 0;
      } else {
        _phase = GamePhase.finished;
      }
    }
    if (_phase == GamePhase.flags && _index >= _countries.length) {
      _phase = GamePhase.finished;
    }

    if (_phase == GamePhase.finished) {
      return Question(
        prompt: 'Terminé ! Score : ${_discovered.length}/${_countries.length}',
        answerCode: '',
      );
    }

    final country = _countries[_index];
    String prompt;
    switch (_phase) {
      case GamePhase.countries:
      // Utilise le nom dans la langue choisie. Ici on prend English comme défaut.
        prompt = country.name['en'] ?? country.name.values.first;
        break;
      case GamePhase.capitals:
      // capital est un Map<String, String>
        prompt = country.capital['en'] ?? country.capital.values.first;
        break;
      case GamePhase.flags:
        prompt = 'Quel est ce drapeau ?';
        break;
      default:
        prompt = '';
    }
    return Question(
      prompt: prompt,
      answerCode: country.isoA2, // utilise isoA2 depuis Country
    );
  }

  /// Soumet la réponse et met à jour découvertes, renvoie true si correct
  bool submitAnswer(String tappedCode) {
    final correctCode = _countries[_index].isoA2;
    final isCorrect = tappedCode.toUpperCase() == correctCode.toUpperCase();
    if (isCorrect) _discovered.add(correctCode);
    _index++;
    return isCorrect;
  }

  /// Codes ISO découverts exposés à la carte
  Set<String> get discoveredCountries => UnmodifiableSetView(_discovered);

  /// Libellé de la phase pour l'AppBar
  String get currentPhaseLabel {
    switch (_phase) {
      case GamePhase.countries:
        return 'Pays';
      case GamePhase.capitals:
        return 'Capitales';
      case GamePhase.flags:
        return 'Drapeaux';
      case GamePhase.finished:
      default:
        return 'Terminé';
    }
  }

  /// Indique si la partie est terminée
  bool get isFinished => _phase == GamePhase.finished;
}

/// Phases du quiz
enum GamePhase { countries, capitals, flags, finished }
