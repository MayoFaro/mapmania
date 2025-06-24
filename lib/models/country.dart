// lib/models/country.dart

/// Modèle représentant un pays avec ses noms, capitales et code ISO.
class Country {
  /// Map des noms du pays par langue (ex: {'en': 'Morocco', 'fr': 'Maroc'})
  final Map<String, String> name;

  /// Map des capitales par langue (ex: {'en': 'Rabat', 'fr': 'Rabat'})
  final Map<String, String> capital;

  /// Code ISO Alpha-2 (ex: 'MA'), correspond à la clé 'code' dans le JSON
  final String isoA2;

  /// URL ou chemin du drapeau (optionnel)
  final String? flag;

  Country({
    required this.name,
    required this.capital,
    required this.isoA2,
    this.flag,
  });

  /// Crée un Country à partir d'un JSON
  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: Map<String, String>.from(json['name'] as Map),
      capital: Map<String, String>.from(json['capital'] as Map),
      isoA2: json['code'] as String, // utilise 'code' dans le JSON
      flag: json['flag'] as String?,
    );
  }

  @override
  String toString() => '$isoA2: ${name['en'] ?? name.values.first}';
}
