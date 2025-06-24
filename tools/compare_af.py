#!/usr/bin/env python3
# tools/compare_af.py
# Compare la liste de codes ISO entre:
# - assets/datas/countries.json
# - assets/maps/af.geojson

import json
from pathlib import Path
import sys

# Détermine le répertoire du script
script_dir = Path(__file__).parent.resolve()
project_root = script_dir.parent  # mapmania/

countries_file = project_root / 'assets' / 'datas' / 'countries.json'
geojson_file  = project_root / 'assets' / 'maps' / 'af.geojson'

# Vérifie l'existence
if not countries_file.exists():
    print(f"❌ Fichier introuvable: {countries_file}")
    sys.exit(1)
if not geojson_file.exists():
    print(f"❌ Fichier introuvable: {geojson_file}")
    sys.exit(1)

# Charge countries.json
with countries_file.open(encoding='utf-8') as f:
    countries = json.load(f)
country_codes = {c['code'] for c in countries if c.get('continent') == 'AF'}

# Charge af.geojson
with geojson_file.open(encoding='utf-8') as f:
    geo = json.load(f)
geo_codes = {feat['properties']['ISO3166-1-Alpha-2'] for feat in geo['features']}

# Différences
in_geo_not_json = sorted(geo_codes - country_codes)
in_json_not_geo = sorted(country_codes - geo_codes)

print("Codes ISO présents dans af.geojson mais pas dans countries.json:")
for code in in_geo_not_json:
    print(f"- {code}")
print()
print("Codes ISO présents dans countries.json mais pas dans af.geojson:")
for code in in_json_not_geo:
    print(f"- {code}")
