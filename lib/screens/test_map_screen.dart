// lib/screens/test_map_screen.dart

import 'package:flutter/material.dart';
import '../widgets/outline_map_widget.dart';

/// Écran de test pour afficher uniquement le contour du continent
/// à partir de af_outline.geojson.
class TestMapScreen extends StatelessWidget {
  const TestMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Outline')),
      body: const OutlineMapWidget(continentCode: 'AF'), //The name 'OutlineMapWidget' isn't a class.
    );
  }
}
