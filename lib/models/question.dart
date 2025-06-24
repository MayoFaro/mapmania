// lib/models/question.dart

import 'country.dart'; // ton modèle Country existant

/// Représente une question du quiz : prompt à afficher et la bonne réponse.
class Question {
  /// Texte à afficher (nom du pays, capitale ou description du drapeau)
  final String prompt;
  /// Code ISO du pays correct
  final String answerCode;
  /// Liste des codes ISO proposées (à l'avenir, si tu ajoutes des boutons)
  final List<String>? options;

  Question({
    required this.prompt,
    required this.answerCode,
    this.options,
  });
}
