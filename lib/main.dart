import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MapManiaApp());
}

class MapManiaApp extends StatelessWidget {
  const MapManiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapMania',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}
