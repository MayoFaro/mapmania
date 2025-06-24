# tools/generate_missing_entries.py

"""
Ce script génère automatiquement des entrées JSON pour les codes ISO manquants
dans countries.json, en se basant sur les GeoJSON de chaque continent.
Usage:
  python tools/generate_missing_entries.py --continent AF

Il lit:
  - assets/datas/countries.json (liste de pays)
  - assets/maps/af.geojson (GeoJSON du continent)

Il produit en sortie un tableau JSON d'objets Country à ajouter:
  [ {"code":..., "continent":"AF", "flag":..., "name":..., "capital":...}, ... ]

L'utilisateur peut copier ce tableau dans countries.json.
"""
import json
import os
import argparse

# Config
TOOLS_DIR = os.path.dirname(__file__)
COUNTRIES_JSON = os.path.join(TOOLS_DIR, '..', 'assets', 'datas', 'countries.json')
GEOJSON_DIR = os.path.join(TOOLS_DIR, '..', 'assets', 'maps')

# Clés GeoJSON possibles pour le nom
NAME_KEYS = ['NAME_EN', 'ADMIN', 'name', 'ISO3166-1-Alpha-3']


def load_existing_codes():
    with open(COUNTRIES_JSON, 'r', encoding='utf-8') as f:
        existing = json.load(f)
    # countries.json est une liste de dicts
    return {entry.get('code') for entry in existing if entry.get('code')}


def load_geojson_features(cont_code):
    filename = f'{cont_code.lower()}.geojson'
    path = os.path.join(GEOJSON_DIR, filename)
    gj = json.load(open(path, 'r', encoding='utf-8'))
    return gj.get('features', [])


def extract_missing_entries(cont_code):
    existing = load_existing_codes()
    features = load_geojson_features(cont_code)
    missing_entries = []
    for feat in features:
        props = feat.get('properties', {})
        code = props.get('ISO_A2') or props.get('ADM0_A2') or props.get('code')
        if not code or code in existing:
            continue
        # Trouver un nom anglais
        name_en = None
        for key in NAME_KEYS:
            if key in props:
                name_en = props[key]
                break
        name_en = name_en or code
        # Construire l'entrée minimale
        entry = {
            "code": code,
            "continent": cont_code.upper(),
            "flag": f"assets/flags/{code.lower()}.png",
            "name": {"en": name_en, "fr": name_en},  # à ajuster
            "capital": {"en": "", "fr": ""},       # à renseigner
        }
        missing_entries.append(entry)
    return missing_entries


def main():
    parser = argparse.ArgumentParser(description="Génère les entrées manquantes pour countries.json.")
    parser.add_argument('--continent', required=True, help="Code du continent (AF, EU, etc.)")
    args = parser.parse_args()

    entries = extract_missing_entries(args.continent)
    print(json.dumps(entries, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
