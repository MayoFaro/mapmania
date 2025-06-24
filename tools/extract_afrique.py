# tools/extract_afrique.py

import json
import os

# Liste des noms anglais de tous les pays d'Afrique
ENGLISH_NAMES = {
    "Algeria", "Angola", "Benin", "Botswana", "Burkina Faso", "Burundi",
    "Cabo Verde", "Cameroon", "Central African Republic", "Chad", "Comoros",
    "Republic of the Congo", "Democratic Republic of the Congo", "Djibouti", "Egypt",
    "Equatorial Guinea", "Eritrea", "eSwatini", "Ethiopia", "Gabon",
    "Gambia", "Ghana", "Guinea", "Guinea-Bissau", "Ivory Coast",
    "Kenya", "Lesotho", "Liberia", "Libya", "Madagascar", "Malawi",
    "Mali", "Mauritania", "Mauritius", "Morocco", "Mozambique", "Namibia",
    "Niger", "Nigeria", "Rwanda", "São Tomé and Principe", "Senegal",
    "Seychelles", "Sierra Leone", "Somalia", "South Africa", "South Sudan",
    "Sudan", "United Republic of Tanzania", "Togo", "Tunisia", "Uganda", "Zambia", "Zimbabwe"
}

# Chemins relatifs
ROOT = os.path.dirname(os.path.abspath(__file__))  # .../mapmania/tools
WORLD_GEOJSON = os.path.join(ROOT, "world_countries.geojson")
OUTPUT_GEOJSON = os.path.join(ROOT, "..", "assets", "maps", "af.geojson")


def main():
    # 1. Charge le GeoJSON mondial
    with open(WORLD_GEOJSON, "r", encoding="utf-8") as f:
        world = json.load(f)

    # 2. Filtre selon le nom anglais de la propriété
    filtered = []
    found_names = set()
    for feat in world.get("features", []):
        props = feat.get("properties", {})
        # Tenter plusieurs clés possibles pour le nom anglais
        name_en = (
            props.get("NAME_EN") or
            props.get("ADMIN") or
            props.get("name") or
            props.get("NAME")
        )
        if name_en and name_en in ENGLISH_NAMES:
            filtered.append(feat)
            found_names.add(name_en)

    # 3. Identifie les pays non trouvés
    missing = sorted(ENGLISH_NAMES - found_names)

    # 4. Nouveau FeatureCollection
    afrique = {
        "type": "FeatureCollection",
        "features": filtered
    }

    # 5. Assure-toi que le dossier assets/maps existe
    os.makedirs(os.path.dirname(OUTPUT_GEOJSON), exist_ok=True)

    # 6. Sauve dans assets/maps/af.geojson
    with open(OUTPUT_GEOJSON, "w", encoding="utf-8") as f:
        json.dump(afrique, f, ensure_ascii=False, indent=2)

    # 7. Affichage du résultat et des manquants
    print(f"✔ Généré : {OUTPUT_GEOJSON} ({len(filtered)} pays)")
    if missing:
        print("⚠️ Pays non trouvés :")
        for name in missing:
            print(f" - {name}")


if __name__ == '__main__':
    main()
