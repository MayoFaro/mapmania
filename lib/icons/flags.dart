import 'package:flutter/widgets.dart';
const String _kFontFam = 'Flags';

const Map<String, IconData> flagMap = {
  'CH': IconData(0xeeac, fontFamily: _kFontFam),
  'DE': IconData(0xeef7, fontFamily: _kFontFam),
  'GH': IconData(0xf433, fontFamily: _kFontFam),
};

class FlagIcons {
  const FlagIcons._();
  static IconData of(String iso) {
    final key = iso.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'),'_');
    return flagMap[key]!;
  }

  static final IconData CH = flagMap['CH']!;
  static final IconData DE = flagMap['DE']!;
  static final IconData GH = flagMap['GH']!;
}
