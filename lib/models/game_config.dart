// lib/models/game_config.dart

import 'package:flutter/foundation.dart';

/// Les cinq continents supportés
enum Continent { AF, EU, AS, NA, SA, OC }

/// Mode de jeu (détermine comment afficher les frontières)
enum GameMode { normal, hard }

/// Formule du quiz (nombre de questions)
enum GameFormula { quick, complete }

/// Contenu du quiz (type d'éléments)
enum GameContent { basic, expert }

/// Configuration d'une partie
@immutable
class GameConfig {
  /// Continent choisi
  final Continent continent;
  /// Mode normal (frontières visibles) ou hard (outline seul)
  final GameMode mode;
  /// Quick = 20 items, Complete = tous
  final GameFormula formula;
  /// Basic = pays/capitales, Expert = + drapeaux
  final GameContent content;
  /// Mode pédagogique libre activé ?
  final bool isPegado;

  const GameConfig({
    required this.continent,
    this.mode = GameMode.normal,
    this.formula = GameFormula.quick,
    this.content = GameContent.basic,
    this.isPegado = false,
  });

  /// Code ISO du continent pour charger les assets
  String get continentCode => describeEnum(continent);

  /// Label affiché en UI
  String get continentLabel => describeEnum(continent);
}
