# tools/fix_accents.py

"""
Script pour corriger les problèmes d'encodage ou de typos d'accents
et caractères mal encodés dans les champs "fr" et "en" de missing_countries.json.

Usage:
  python tools/fix_accents.py --input missing_countries.json --output corrected.json

Le script :
 1. Charge le fichier JSON spécifié (liste d'objets) en 'utf-8-sig' pour ignorer un BOM éventuel.
 2. Parcourt chaque objet et applique des remplacements sur les valeurs
    des clés 'name.fr', 'name.en', 'capital.fr' et 'capital.en'.
 3. Écrit le JSON corrigé dans le fichier de sortie.

Ajoute/modifie le dictionnaire `replacements` pour gérer d'autres cas.
"""

import json
import argparse
import os

import chardet
# Dictionnaire des remplacements de caractères mal encodés -> correct
replacements = {
    'Ú': 'é',    # HerzÚgovine -> Herzégovine
    '╬': 'Î',    # ╬les Cook -> Îles Cook
    # ajoute d'autres corrections au besoin :
    # 'Ã©': 'é',  # cas de double encodage
    # 'â€™': '’', # apostrophe
}


def correct_text(text: str) -> str:
    """Applique tous les remplacements sur la chaîne fournie."""
    for wrong, right in replacements.items():
        text = text.replace(wrong, right)
    return text

def detect_encoding(file_path):
    with open(file_path, 'rb') as f:
        raw_data = f.read(1000)  # Lire les premiers octets pour détection
        return chardet.detect(raw_data)['encoding']

def fix_file(input_path: str, output_path: str):
    encoding = detect_encoding(input_path) or 'utf-8-sig'  # Fallback si échec
    with open(input_path, 'r', encoding=encoding) as f:
        data = json.load(f)

    for entry in data:
        # Corrige les noms
        if 'name' in entry:
            if 'fr' in entry['name']:
                entry['name']['fr'] = correct_text(entry['name']['fr'])
            if 'en' in entry['name']:
                entry['name']['en'] = correct_text(entry['name']['en'])
        # Corrige les capitales
        if 'capital' in entry:
            if 'fr' in entry['capital']:
                entry['capital']['fr'] = correct_text(entry['capital']['fr'])
            if 'en' in entry['capital']:
                entry['capital']['en'] = correct_text(entry['capital']['en'])

    # Sauvegarde en UTF-8 standard (sans BOM)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"Fichier corrigé enregistré dans {output_path}")


def main():
    parser = argparse.ArgumentParser(description='Corrige les accents mal encodés.')
    parser.add_argument('--input',  required=True, help='Chemin vers missing_countries.json')
    parser.add_argument('--output', required=True, help='Chemin du fichier JSON corrigé')
    args = parser.parse_args()

    if not os.path.isfile(args.input):
        print(f"Fichier non trouvé : {args.input}")
        return
    fix_file(args.input, args.output)


if __name__ == '__main__':
    main()
