import json
import os

# Chemins
TOOLS_DIR = os.path.dirname(__file__)
COUNTRIES_JSON = os.path.join(TOOLS_DIR, '..', 'assets', 'datas', 'countries.json')
WORLD_GEOJSON = os.path.join(TOOLS_DIR, '..', 'assets', 'maps', 'world_countries.geojson')

def load_country_codes():
    """Charge les codes pays depuis countries.json"""
    with open(COUNTRIES_JSON, 'r', encoding='utf-8') as f:
        data = json.load(f)  # liste de dicts
    return {entry['code'] for entry in data if 'code' in entry}

def load_world_geojson_codes(filepath):
    """Extrait les codes ISO_A2 des features dans le GeoJSON mondial"""
    with open(filepath, 'r', encoding='utf-8') as f:
        gj = json.load(f)
    codes = set()
    for feat in gj.get('features', []):
        props = feat.get('properties', {})
        # Essaye plusieurs clés possibles pour le code pays
        code = props.get('ISO3166-1-Alpha-2') or props.get('ISO_A2') or props.get('code')
        if code:
            codes.add(code)
    return codes

def main():
    # Charge les codes depuis les deux fichiers
    country_codes = load_country_codes()
    world_codes = load_world_geojson_codes(WORLD_GEOJSON)

    # Trouve les codes présents dans world mais absents de countries
    missing_codes = sorted(world_codes - country_codes)

    # Formatage de sortie
    result = {
        'code: missing_codes
    }

    # Affichage du résultat (peut être enregistré dans un fichier si besoin)
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()