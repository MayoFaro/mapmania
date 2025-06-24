/// Petit script Dart pour vérifier le contenu de countries.json
/// Place ce fichier à la racine de ton projet et exécute-le avec `dart verify_countries.dart`.

import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // 1. Chemin vers ton fichier JSON
  final filePath = 'assets/datas/countries.json';

  // 2. Chargement du contenu
  final file = File(filePath);
  if (!await file.exists()) {
    print('❌ Fichier non trouvé : $filePath');
    return;
  }
  final raw = await file.readAsString();

  // 3. Décodage JSON
  List<dynamic> countries;
  try {
    countries = jsonDecode(raw) as List<dynamic>;
  } catch (e) {
    print('❌ Erreur de décodage JSON : \$e');
    return;
  }

  // 4. Filtre des pays d'Afrique (continent 'AF')
  final africa = countries
      .where((c) => c is Map<String, dynamic> && c['continent'] == 'AF')
      .cast<Map<String, dynamic>>()
      .toList();

  // 5. Affichage
  print('Pays trouvés avec continent == "AF" : ${africa.length}');
  for (final c in africa) {
    final code = c['code'];
    final nameFr = (c['name'] as Map<String, dynamic>)['fr'];
    final nameEn = (c['name'] as Map<String, dynamic>)['en'];
    print('- $code : $nameFr / $nameEn');
  }
}
