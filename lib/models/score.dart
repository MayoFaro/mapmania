import 'country.dart';

/// Une question à poser (pays ou capitale ou drapeau)
class Question {
  final String prompt;         // ex. 'France' ou 'Paris' ou chemin flag
  final List<Country> options; // les pays proposés à cliquer
  final Country answer;        // la bonne réponse

  Question({
    required this.prompt,
    required this.options,
    required this.answer,
  });
}
