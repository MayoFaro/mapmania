# tools/check_countries.py

import json
import os
from collections import defaultdict

# Chemins
TOOLS_DIR = os.path.dirname(__file__)
COUNTRIES_JSON = os.path.join(TOOLS_DIR, '..', 'assets', 'datas', 'countries.json')
GEOJSON_DIR = os.path.join(TOOLS_DIR, '..', 'assets', 'maps')


def load_country_codes():
    """Charge tous les codes 'code' depuis countries.json (liste de dicts)."""
    with open(COUNTRIES_JSON, 'r', encoding='utf-8') as f:
        data = json.load(f)  # liste de pays
    return {entry.get('code') for entry in data if entry.get('code')}


def load_all_geojson_codes():
    """Parcourt tous les GeoJSON (hors outlines) et extrait tous les codes ISO."""
    all_codes = set()
    for fname in os.listdir(GEOJSON_DIR):
        if not fname.endswith('.geojson') or fname.endswith('_outline.geojson'):
            continue
        path = os.path.join(GEOJSON_DIR, fname)
        with open(path, 'r', encoding='utf-8') as f:
            gj = json.load(f)
        for feat in gj.get('features', []):
            props = feat.get('properties', {})
            # différentes clés possibles pour le code ISO
            code = props.get('ISO_A2') or props.get('ISO3166-1-Alpha-2') or props.get('code') or props.get('ADM0_A2')
            if code:
                all_codes.add(code)
    return all_codes


def main():
    # Charge codes JSON
    json_codes = load_country_codes()
    print(f"Loaded {len(json_codes)} country codes from countries.json")

    # Charge codes GeoJSON
    geo_codes = load_all_geojson_codes()
    print(f"Extracted {len(geo_codes)} unique country codes from GeoJSON files")

    # Calcule l'ensemble des codes manquants
    missing = sorted(geo_codes - json_codes)
    if missing:
        print(f"\nCountry codes present in GeoJSON but missing in countries.json ({len(missing)}):")
        print(missing)
    else:
        print("\nAll GeoJSON country codes are covered in countries.json")

if __name__ == '__main__':
    main()
