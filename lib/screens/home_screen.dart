import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_config.dart';
import 'game_screen.dart';

/// Modèle global de paramètres de l'application
class AppSettings {
  static String language = 'fr'; // 'fr' ou 'en'
  static bool soundEffects = true;
  static bool music = true;

  /// Charge les paramètres depuis SharedPreferences
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString('language') ?? language;
    soundEffects = prefs.getBool('soundEffects') ?? soundEffects;
    music = prefs.getBool('music') ?? music;
    print('AppSettings.load: language=\$language, soundEffects=\$soundEffects, music=\$music');
  }

  /// Sauvegarde les paramètres dans SharedPreferences
  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    await prefs.setBool('soundEffects', soundEffects);
    await prefs.setBool('music', music);
    print('AppSettings.save: language=\$language, soundEffects=\$soundEffects, music=\$music');
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedContinent = 'AF';
  GameMode _gameMode = GameMode.normal;
  GameFormula _gameFormula = GameFormula.quick;
  GameContent _gameContent = GameContent.basic;
  bool _isPegadoMode = false;

  @override
  void initState() {
    super.initState();
    AppSettings.load();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => _SettingsSheet(),
    ).whenComplete(() => setState(() {}));
  }

  void _startGame() {
    final config = GameConfig(
      continent: Continent.values.firstWhere((c) => c.name == _selectedContinent),
      mode: _gameMode,
      formula: _gameFormula,
      content: _gameContent,
      isPegado: _isPegadoMode,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(config: config, language: AppSettings.language),
      ),
    );
  }

  Widget _buildOptionGroup<T>(String title, Map<T, String> labels, T selected, void Function(T) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 10,
          children: labels.entries.map((entry) => ChoiceChip(
            label: Text(entry.value),
            selected: selected == entry.key,
            onSelected: (_) => onChanged(entry.key),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildContinentSelector() {
    final continents = ['AF', 'EU', 'AS', 'NA', 'SA', 'OC'];
    return _buildOptionGroup<String>(
      'Continent',
      {for (var c in continents) c: c},
      _selectedContinent,
          (val) => setState(() => _selectedContinent = val),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MapMania'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _buildContinentSelector(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOptionGroup<GameMode>('Mode de jeu', {
                        GameMode.normal: 'Normal',
                        GameMode.hard: 'Hard',
                      }, _gameMode, (val) => setState(() => _gameMode = val)),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _gameMode == GameMode.normal
                            ? Image.asset('assets/images/normal_mode_preview.png', height: 100)
                            : Image.asset('assets/images/hard_mode_preview.png', height: 100),
                      ),
                    ],
                  ),
                  _buildOptionGroup<GameFormula>('Type de partie', {
                    GameFormula.quick: 'Rapide',
                    GameFormula.complete: 'Complète',
                  }, _gameFormula, (val) => setState(() => _gameFormula = val)),
                  _buildOptionGroup<GameContent>('Contenu', {
                    GameContent.basic: 'Classique',
                    GameContent.expert: 'Expert',
                  }, _gameContent, (val) => setState(() => _gameContent = val)),
                  Row(
                    children: [
                      const Text('Mode Pégado'),
                      const Spacer(),
                      Switch(
                        value: _isPegadoMode,
                        onChanged: (val) => setState(() => _isPegadoMode = val),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lancer la partie'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            )
          ],
        ),
      ),
    );
  }
}

/// Feuille de réglages accessibles via la roue crantée
class _SettingsSheet extends StatefulWidget {
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Langue'),
              const Spacer(),
              DropdownButton<String>(
                value: AppSettings.language,
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (val) => setState(() {
                  if (val != null) AppSettings.language = val;
                  AppSettings.save();
                }),
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('Effets sonores'),
            value: AppSettings.soundEffects,
            onChanged: (val) => setState(() {
              AppSettings.soundEffects = val;
              AppSettings.save();
            }),
          ),
          SwitchListTile(
            title: const Text('Musique de fond'),
            value: AppSettings.music,
            onChanged: (val) => setState(() {
              AppSettings.music = val;
              AppSettings.save();
            }),
          ),
        ],
      ),
    );
  }
}
