# tools/extract_af_outline.py

import json
import os
# Requires shapely: pip install shapely
from shapely.geometry import shape, mapping
from shapely.ops import unary_union

# Fichier d'entrée : GeoJSON des pays d'Afrique (output du script extract_afrique)
INPUT_GEOJSON = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "..", "assets", "maps", "af.geojson")
# Fichier de sortie : contour global de l'Afrique
OUTPUT_GEOJSON = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "..", "assets", "maps", "af_outline.geojson")


def main():
    # 1. Charge le GeoJSON des pays d'Afrique
    with open(INPUT_GEOJSON, 'r', encoding='utf-8') as f:
        data = json.load(f)
    features = data.get('features', [])

    # 2. Convertit chaque géométrie en objet shapely
    geoms = []
    for feat in features:
        geom = feat.get('geometry')
        if geom:
            geoms.append(shape(geom))

    if not geoms:
        print('❌ Aucun géométrie trouvée dans af.geojson')
        return

    # 3. Fusionne toutes les géométries en un seul polygone (union)
    union_geom = unary_union(geoms)

    # 4. Extrait l'extérieur (contour) de l'union
    # union_geom peut être un MultiPolygon ou Polygon
    if union_geom.geom_type == 'Polygon':
        exterior = union_geom.exterior
        contour_geom = mapping(exterior)
        features_out = [
            {
                'type': 'Feature',
                'geometry': contour_geom,
                'properties': {}
            }
        ]
    else:
        # MultiPolygon: on prend tous les extérieurs
        features_out = []
        for poly in union_geom.geoms:
            exterior = poly.exterior
            contour_geom = mapping(exterior)
            features_out.append({
                'type': 'Feature',
                'geometry': contour_geom,
                'properties': {}
            })

    outline = {
        'type': 'FeatureCollection',
        'features': features_out
    }

    # 5. Sauvegarde
    os.makedirs(os.path.dirname(OUTPUT_GEOJSON), exist_ok=True)
    with open(OUTPUT_GEOJSON, 'w', encoding='utf-8') as f:
        json.dump(outline, f, ensure_ascii=False, indent=2)

    print(f"✔ Généré le contour de l'Afrique dans {OUTPUT_GEOJSON}")


if __name__ == '__main__':
    main()
