#!/usr/bin/env bash
# Regenerate every boundary tileset in public/tiles/ from the raw ABS
# shapefiles in data/. Safe to re-run any time the source data changes.
#
#   nvm use && scripts/build-all.sh
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=public/tiles
mkdir -p "$OUT"
BUILD=scripts/build-tiles.sh

# --- Direct shapefile -> tiles (one feature per area) ------------------------
"$BUILD" data/lga_2025/LGA_2025_AUST_GDA2020.shp lgas LGA_CODE25 LGA_NAME25 STE_NAME21 "$OUT/lga_2025"
"$BUILD" data/sa2_2021/SA2_2021_AUST_GDA2020.shp sa2  SA2_CODE21 SA2_NAME21 STE_NAME21 "$OUT/sa2_2021"
"$BUILD" data/sa3_2021/SA3_2021_AUST_GDA2020.shp sa3  SA3_CODE21 SA3_NAME21 STE_NAME21 "$OUT/sa3_2021"
"$BUILD" data/sa4_2021/SA4_2021_AUST_GDA2020.shp sa4  SA4_CODE21 SA4_NAME21 STE_NAME21 "$OUT/sa4_2021"

# --- State/territory: dissolved from the LGA shapefile (no separate source) --
echo "[states] dissolving LGAs -> states"
STATE_TMP="$(mktemp -t states)"   # no extension: format is set explicitly below
trap 'rm -f "$STATE_TMP"' EXIT
npx -y mapshaper data/lga_2025/LGA_2025_AUST_GDA2020.shp \
  -dissolve STE_NAME21 copy-fields=STE_CODE21 \
  -o format=geojson precision=0.000001 "$STATE_TMP" 2>&1 \
  | grep -viE 'EBADENGINE|deprecated|npm warn|prebuild|SWITCH|WARNING|buffer' || true

node -e "
const fs=require('fs');
const g=JSON.parse(fs.readFileSync('$STATE_TMP','utf8'));
g.features=g.features.filter(f=>f.geometry);
fs.writeFileSync('$STATE_TMP',JSON.stringify(g));
const bbox=f=>{let a=[180,90,-180,-90];const w=c=>{if(typeof c[0]==='number'){if(c[0]<a[0])a[0]=c[0];if(c[1]<a[1])a[1]=c[1];if(c[0]>a[2])a[2]=c[0];if(c[1]>a[3])a[3]=c[1];}else c.forEach(w)};w(f.geometry.coordinates);return a.map(n=>+n.toFixed(5));};
const meta=g.features.map(f=>({code:f.properties.STE_CODE21,name:f.properties.STE_NAME21,bbox:bbox(f)})).sort((x,y)=>x.name.localeCompare(y.name));
fs.writeFileSync('$OUT/state_2025_index.json',JSON.stringify(meta));
console.log('  states:',g.features.length);
"
# Few, large features: no coalescing / dropping needed.
tippecanoe -o "$OUT/state_2025.pmtiles" -f -l states \
  --minimum-zoom=0 --maximum-zoom=7 \
  --no-feature-limit --no-tile-size-limit \
  --simplification=4 --generate-ids \
  "$STATE_TMP" >/dev/null 2>&1
echo "[states] done -> $OUT/state_2025.pmtiles ($(ls -lh "$OUT/state_2025.pmtiles" | awk '{print $5}'))"

echo "All boundary tilesets rebuilt into $OUT/"
