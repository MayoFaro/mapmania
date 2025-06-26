// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:mapmania/screens/flag_test_screen.dart';
import 'package:mapmania/screens/test_fond_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_config.dart';
import '../screens/test_wid_screen.dart';
import 'continent_selection_screen.dart';
import '../screens/flag_test_screen.dart';
import '../screens/test_fond_image.dart';

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
    // Debug log
    print('AppSettings.load: language=$language, soundEffects=$soundEffects, music=$music');
  }

  /// Sauvegarde les paramètres dans SharedPreferences
  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    await prefs.setBool('soundEffects', soundEffects);
    await prefs.setBool('music', music);
    // Debug log
    print('AppSettings.save: language=$language, soundEffects=$soundEffects, music=$music');
  }
}

/// Écran d'accueil principal
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Charge les préférences avant d'afficher l'écran
    AppSettings.load().then((_) {
      print('HomeScreen.initState: preferences loaded -> language=${AppSettings.language}, soundEffects=${AppSettings.soundEffects}, music=${AppSettings.music}');
      setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Loader tant que les prefs ne sont pas chargées
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MapMania'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Paramètres',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('Jouer'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FlagTestScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text('Test map'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TestWidScreen(
                      language: AppSettings.language,
                      formula: GameFormula.complete,
                      difficulty: GameMode.normal,
                    ),
                  ),
                );
              },
            ),
            // const SizedBox(height: 16),
            // ElevatedButton(
            //   child: const Text('Test image'),
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (_) => const TestFondImageScreen()),
            //     );
            //   },
            //),
          ]
        ),
      ),
    );
  }

  /// Ouvre le panneau de paramètres en bas
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 50.0),
        child: const _SettingsSheet(),
      ),
    )
        .then((_) {
      // Reconstruit HomeScreen après fermeture de la feuille
      setState(() {});
    });
  }
}

/// Feuille de paramètres (langue, effets, musique)
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({Key? key}) : super(key: key);

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  String _lang = AppSettings.language;
  bool _sound = AppSettings.soundEffects;
  bool _music = AppSettings.music;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Charge les paramètres sauvegardés
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language') ?? AppSettings.language;
    final sound = prefs.getBool('soundEffects') ?? AppSettings.soundEffects;
    final music = prefs.getBool('music') ?? AppSettings.music;

    print('_SettingsSheet._loadSettings: fetched -> language=$lang, soundEffects=$sound, music=$music');

    setState(() {
      _lang = lang;
      _sound = sound;
      _music = music;
      _loading = false;
    });
  }

  @override
  void dispose() {
    // Sauvegarde automatique lors de la fermeture
    print('_SettingsSheet.dispose: saving -> language=$_lang, soundEffects=$_sound, music=$_music');
    AppSettings.language = _lang;
    AppSettings.soundEffects = _sound;
    AppSettings.music = _music;
    AppSettings.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Paramètres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Langue'),
              DropdownButton<String>(
                value: _lang,
                items: const [
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) => setState(() => _lang = v!),
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('Effets sonores'),
            value: _sound,
            onChanged: (v) => setState(() => _sound = v),
          ),
          SwitchListTile(
            title: const Text('Musique'),
            value: _music,
            onChanged: (v) => setState(() => _music = v),
          ),
        ],
      ),
    );
  }
}
