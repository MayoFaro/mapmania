import 'package:flutter/material.dart';
// TODO: importer GameScreen une fois créé

class GameSettingsScreen extends StatefulWidget {
  final String continent;
  const GameSettingsScreen({super.key, required this.continent});

  @override
  State<GameSettingsScreen> createState() => _GameSettingsScreenState();
}

class _GameSettingsScreenState extends State<GameSettingsScreen> {
  String _difficulty = 'Facile';
  String _formule = 'Complète';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Paramètres - ${widget.continent}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Choisis ton niveau de difficulté :'),
            DropdownButton<String>(
              value: _difficulty,
              items: ['Facile', 'Moyen', 'Difficile']
                  .map((level) => DropdownMenuItem(value: level, child: Text(level)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _difficulty = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            const Text('Choisis la formule de jeu :'),
            DropdownButton<String>(
              value: _formule,
              items: ['Complète', 'Light']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _formule = value;
                  });
                }
              },
            ),
            const Spacer(),
            ElevatedButton(
              child: const Text('Lancer la partie'),
              onPressed: () {
                // TODO: passer à GameScreen avec params
              },
            ),
          ],
        ),
      ),
    );
  }
}
