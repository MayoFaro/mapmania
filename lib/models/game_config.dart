// lib/models/game_config.dart

import 'package:flutter/foundation.dart';

/// Les cinq continents supportés
enum Continent { AF, EU, AS, NA, SA, OC }

/// Mode de jeu (détermine comment afficher les frontières)
enum GameMode { normal, hard }

/// Formule du quiz (pays/capitale/drapeau)
enum GameFormula { light, complete }

/// Configuration d'une partie
@immutable
class GameConfig {
  /// Continent choisi
  final Continent continent;
  /// Mode normal (frontières visibles) ou hard (outline seul)
  final GameMode mode;
  /// Light = pays+capitale, Complete = +drapeau
  final GameFormula formula;

  const GameConfig({
    required this.continent,
    this.mode = GameMode.normal,
    this.formula = GameFormula.light,
  });

  /// Code ISO du continent pour charger les assets
  String get continentCode => describeEnum(continent);

  /// Label affiché en UI
  String get continentLabel => describeEnum(continent);
}
