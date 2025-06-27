import json

# Groupes de pays par direction du décalage
UP_RIGHT = ['KM','SC']
DOWN_RIGHT = [ ]
UP_LEFT = ['CV' ]
DOWN_LEFT = ['GQ','GM','ST','MU']

# Taille du rectangle (en degrés)
RECT_SIZE = 1.5
HALF = RECT_SIZE / 2

# Décalages par groupe
OFFSETS = {
    'UP_RIGHT':  (5.0, 5.0),
    'DOWN_RIGHT': (5.0, -5.0),
    'UP_LEFT':   (-5.0, 5.0),
    'DOWN_LEFT': (-5.0, -5.0)
}

INPUT_FILE = 'af.geojson'
OUTPUT_FILE = 'af_with_labels.geojson'

def compute_centroid(geometry):
    pts = []

    def collect_coords(coords):
        for ring in coords:
            for pt in ring:
                pts.append(pt)

    if geometry['type'] == 'Polygon':
        collect_coords(geometry['coordinates'])
    elif geometry['type'] == 'MultiPolygon':
        for poly in geometry['coordinates']:
            collect_coords(poly)

    if not pts:
        return None

    lon_avg = sum(pt[0] for pt in pts) / len(pts)
    lat_avg = sum(pt[1] for pt in pts) / len(pts)
    return [lon_avg, lat_avg]

def get_offset(iso):
    if iso in UP_RIGHT:
        return OFFSETS['UP_RIGHT']
    elif iso in DOWN_RIGHT:
        return OFFSETS['DOWN_RIGHT']
    elif iso in UP_LEFT:
        return OFFSETS['UP_LEFT']
    elif iso in DOWN_LEFT:
        return OFFSETS['DOWN_LEFT']
    else:
        return None

def generate_features(original_features):
    new_features = []
    seen = set()

    for feature in original_features:
        props = feature['properties']
        iso = props.get('ISO3166-1-Alpha-2')
        if not iso or iso in seen:
            continue

        offset = get_offset(iso)
        if offset is None:
            continue
        seen.add(iso)

        centroid = compute_centroid(feature['geometry'])
        if not centroid:
            continue

        dx, dy = offset
        lon, lat = centroid
        target = [lon + dx, lat + dy]

        # Trait
        line_feature = {
            "type": "Feature",
            "properties": {
                "ISO3166-1-Alpha-2": iso,
                "isLabelLink": True
            },
            "geometry": {
                "type": "LineString",
                "coordinates": [centroid, target]
            }
        }

        # Rectangle centré sur la cible
        rect = [[
            [target[0] - HALF, target[1] + HALF],
            [target[0] + HALF, target[1] + HALF],
            [target[0] + HALF, target[1] - HALF],
            [target[0] - HALF, target[1] - HALF],
            [target[0] - HALF, target[1] + HALF]
        ]]
        rect_feature = {
            "type": "Feature",
            "properties": {
                "ISO3166-1-Alpha-2": iso
            },
            "geometry": {
                "type": "Polygon",
                "coordinates": rect
            }
        }

        new_features.extend([line_feature, rect_feature])

    return new_features

def main():
    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)

    base_features = data['features']
    label_features = generate_features(base_features)

    all_features = base_features + label_features
    enriched = {
        "type": "FeatureCollection",
        "features": all_features
    }

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(enriched, f, ensure_ascii=False, indent=2)

    print(f"{len(label_features)} objets ajoutés. Fichier généré : {OUTPUT_FILE}")

if __name__ == '__main__':
    main()
