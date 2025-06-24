#!/usr/bin/env python3
"""
Script pour générer automatiquement la liste `_isoCodes` à partir des noms de fichiers
présents dans un dossier de drapeaux.
Usage:
  python tools/generate_flag_order.py
"""
import os

# --- CONFIGURATION : chemins à adapter ---
INPUT_DIR = r"C:/Users/cedric/Pictures/flags"
OUTPUT_FILE = r"lib/icons/flag_sprite_order.dart"
# -----------------------------------------

def main():
    # Lister les fichiers et extraire les codes ISO
    files = [f for f in os.listdir(INPUT_DIR) if os.path.isfile(os.path.join(INPUT_DIR, f))]
    iso_codes = []
    seen = set()
    for f in sorted(files):
        name, ext = os.path.splitext(f)
        if ext.lower() in ['.svg', '.png']:
            code = name.upper()
            if code not in seen:
                seen.add(code)
                iso_codes.append(code)

    # Générer les lignes du fichier Dart
    lines = [
        '// GENERATED CODE - Ne pas modifier manuellement',
        '',
        "/// Liste des codes ISO, dans l'ordre de montage de la sprite-sheet.",
        'const List<String> flagSpriteOrder = [',
    ]
    for iso in iso_codes:
        lines.append(f"  '{iso}',")
    lines.append('];')

    content = '\n'.join(lines) + '\n'

    # Assurer que le dossier de sortie existe
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    # Écrire le fichier
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"✅ {OUTPUT_FILE} généré avec {len(iso_codes)} entrées.")

if __name__ == '__main__':
    main()
