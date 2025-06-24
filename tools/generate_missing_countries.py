"""
Génère 'missing_countries.json' pour la liste de codes manquants,
en conservant la structure de countries.json.
"""

import json
import requests
import sys
import io
import os
from urllib.parse import quote

# Configuration de l'encodage UTF-8 pour stdout
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Liste des codes manquants
missing_codes = [
    "EC", "EE", "EG", "EH", "ER", "ES", "ET", "FI", "FJ", "FK",
    "FM", "FO", "GB", "GD", "GE", "GG", "GI", "GL", "GM", "GQ",
    "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM", "HN", "HR",
    "HT", "HU", "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR",
    "IS", "IT", "JE", "JM", "JO", "KE", "KG", "KH", "KI", "KM",
    "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC", "LI",
    "LK", "LR", "LS", "LT", "LU", "LV", "MC", "MD", "ME", "MF",
    "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MR", "MS",
    "MT", "MU", "MV", "MW", "MX", "MY", "MZ", "NA", "NC", "NE",
    "NF", "NG", "NI", "NL", "NP", "NR", "NU", "NZ", "OM", "PA",
    "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS",
    "PT", "PW", "PY", "QA", "RO", "RS", "RU", "RW", "SA", "SB",
    "SC", "SD", "SE", "SG", "SH", "SI", "SK", "SL", "SM", "SO",
    "SR", "SS", "ST", "SV", "SX", "SY", "SZ", "TC", "TF", "TG",
    "TH", "TJ", "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TZ",
    "UA", "UG", "UM", "UY", "UZ", "VA", "VC", "VE", "VG", "VI",
    "VN", "VU", "WF", "WS", "YE", "ZA", "ZM", "ZW"
]

# Map region -> continent code
region_to_cont = {
    'Africa': 'AF', 'Americas': 'AM', 'Asia': 'AS',
    'Europe': 'EU', 'Oceania': 'OC', 'Antarctic': 'AN'
}

# On traite les codes par lots pour éviter les requêtes trop longues
BATCH_SIZE = 20
output = []

for i in range(0, len(missing_codes), BATCH_SIZE):
    batch = missing_codes[i:i+BATCH_SIZE]
    encoded_codes = quote(','.join(batch))
    url = f"https://restcountries.com/v3.1/alpha?codes={encoded_codes}"

    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        countries = resp.json()

        for c in countries:
            try:
                code = c.get('cca2', '')
                if not code:
                    continue

                region = c.get('region', '')
                continent = region_to_cont.get(region, '')

                names = c.get('name', {})
                common_en = names.get('common', code)

                # Gestion des traductions françaises
                translations = c.get('translations', {})
                fr_translation = translations.get('fra', {})
                fr_name = fr_translation.get('common', common_en)

                # Gestion de la capitale
                capital_list = c.get('capital', [''])
                cap = capital_list[0] if capital_list else ''

                entry = {
                    'code': code,
                    'continent': continent,
                    'flag': f"assets/flags/{code.lower()}.png",
                    'name': {'en': common_en, 'fr': fr_name},
                    'capital': {'en': cap, 'fr': cap}
                }
                output.append(entry)

            except Exception as e:
                print(f"Error processing country {c.get('cca2', 'unknown')}: {str(e)}", file=sys.stderr)

    except requests.exceptions.RequestException as e:
        print(f"API request failed for batch {batch}: {str(e)}", file=sys.stderr)
    except json.JSONDecodeError as e:
        print(f"Failed to decode API response for batch {batch}: {str(e)}", file=sys.stderr)

# Tri par code pays
output.sort(key=lambda x: x['code'])


output_path = os.path.join(os.path.dirname(__file__), 'missing_countries.json')

try:
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    print(f"Fichier généré avec succès : {output_path}")
except PermissionError:
    print("Erreur : Permission denied. Essayez :")
    print("1. D'exécuter en tant qu'administrateur")
    print("2. De spécifier un autre répertoire de sortie")
    print("3. D'exécuter sans redirection (> fichier.json)")
    sys.exit(1)