// lib/screens/test_countries_screen.dart

import 'package:flutter/material.dart';
import '../models/country.dart';
import '../services/data_service.dart';

/// Écran de test pour charger et afficher la liste des pays d'Afrique
class TestCountriesNameScreen extends StatelessWidget {
  const TestCountriesNameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Countries')),
      body: FutureBuilder<List<Country>>(
        future: DataService.instance.loadCountries('AF'),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint('Erreur TestCountries: ${snapshot.error}');
            debugPrint('${snapshot.stackTrace}');
            return Center(child: Text('Erreur: \${snapshot.error}'));
          }
          final countries = snapshot.data!;
          return ListView.builder(
            itemCount: countries.length,
            itemBuilder: (context, index) {
              final c = countries[index];
              // Affiche le code ISO
              final iso = c.isoA2;
              // Récupère le nom en français (ou fallback)
              final nameFr = c.name['fr'] ?? c.name.values.first;
              // Récupère la capitale en français (ou fallback)
              final capitalFr = c.capital['fr'] ?? c.capital.values.first;

              return ListTile(
                leading: Text(iso),
                title: Text(nameFr),
                subtitle: Text(capitalFr),
              );
            },
          );
        },
      ),
    );
  }
}
