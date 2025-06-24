// lib/services/data_service.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/country.dart';

/// Service responsable du chargement des données depuis les assets JSON.
/// Le JSON racine est un tableau de pays, chacun ayant une clé "continent".
class DataService {
  DataService._();
  static final DataService instance = DataService._();

  /// Charge et renvoie la liste des pays pour un continent donné
  /// (par ex. 'AF', 'EU', etc.) en filtrant sur la propriété 'continent'.
  Future<List<Country>> loadCountries(String continentCode) async {
    // Lit le fichier JSON qui est un tableau de pays
    final jsonStr = await rootBundle.loadString('assets/datas/countries.json');
    final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;

    // Filtre les pays dont la propriété 'continent' correspond
    final filtered = list.where((e) {
      final props = e as Map<String, dynamic>;
      return (props['continent'] as String).toUpperCase() == continentCode.toUpperCase();
    }).toList();

    if (filtered.isEmpty) {
      throw Exception('Aucun pays trouvé pour le continent: $continentCode');
    }

    // Convertit les maps en Country
    return filtered
        .map((e) => Country.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
