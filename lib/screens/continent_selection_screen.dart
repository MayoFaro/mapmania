import 'package:flutter/material.dart';
import './game_settings_screen.dart';

class ContinentSelectionScreen extends StatelessWidget {
  const ContinentSelectionScreen({super.key});

  final List<String> continents = const [
    'Afrique',
    'Europe',
    'Asie',
    'Amérique',
    'Océanie',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisis ton continent')),
      body: ListView.builder(
        itemCount: continents.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(continents[index]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GameSettingsScreen(continent: continents[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
