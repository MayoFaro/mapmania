// tools/generate_flags.dart
import 'dart:convert';
import 'dart:io';

/// Génère lib/icons/flags.dart avec :
///  - flagMap : Map<String, IconData>
///  - class FlagIcons { static IconData of(iso); static const IconData AD = …; … }
void main() async {
  final sel = File('assets/fonts/selection.json');
  if (!await sel.exists()) {
    stderr.writeln('ERREUR : selection.json introuvable');
    exit(1);
  }
  final data = jsonDecode(await sel.readAsString()) as Map<String, dynamic>;
  final icons = data['icons'] as List<dynamic>;

  final buf = StringBuffer()
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln("const String _kFontFam = 'Flags';\n")
    ..writeln('const Map<String, IconData> flagMap = {');

  for (var icon in icons) {
    final raw = icon['properties']['name'] as String;
    final isoKey = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
    final cp = (icon['properties']['code'] as int).toRadixString(16).padLeft(4, '0');
    buf.writeln("  '$isoKey': IconData(0x$cp, fontFamily: _kFontFam),");
  }
  buf.writeln('};\n');

  buf.writeln('class FlagIcons {');
  buf.writeln('  const FlagIcons._();');
  buf.writeln('  static IconData of(String iso) {');
  buf.writeln("    final key = iso.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'),'_');");
  buf.writeln('    return flagMap[key]!;');
  buf.writeln('  }\n');

  // constantes individuelles
  for (var icon in icons) {
    final raw = icon['properties']['name'] as String;
    final isoKey = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
    buf.writeln('  static const IconData $isoKey = flagMap[\'$isoKey\']!;');
  }
  buf.writeln('}');

  final out = File('lib/icons/flags.dart');
  await out.create(recursive: true);
  await out.writeAsString(buf.toString());
  print('✅ flags.dart généré avec ${icons.length} drapeaux.');
}
