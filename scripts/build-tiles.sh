#!/usr/bin/env bash
# Convert an ABS ASGS shapefile into web assets: a simplified PMTiles vector
# tileset + a tiny {code,name,state,bbox} index JSON for the dropdown.
#
# Usage: scripts/build-tiles.sh <shp> <layer> <codeField> <nameField> <stateField> <outBase>
#   e.g. scripts/build-tiles.sh data/sa2_2021/SA2_2021_AUST_GDA2020.shp sa2 \
#          SA2_CODE21 SA2_NAME21 STE_NAME21 public/tiles/sa2_2021
#
# Writes <outBase>.pmtiles and <outBase>_index.json.
# See scripts/build-all.sh to (re)generate every boundary type at once.
set -euo pipefail

SHP="$1"; LAYER="$2"; CODE="$3"; NAME="$4"; STATE="$5"; OUT="$6"
# mapshaper/tippecanoe get an explicit `format=geojson`, so the temp file
# needs no extension — avoids orphaning a second mktemp stub on cleanup.
TMP="$(mktemp -t "${LAYER}")"
trap 'rm -f "$TMP"' EXIT

echo "[$LAYER] converting shapefile -> geojson (trim fields)"
npx -y mapshaper "$SHP" \
  -filter-fields "$CODE,$NAME,$STATE" \
  -o format=geojson precision=0.000001 "$TMP" 2>&1 | grep -viE 'EBADENGINE|deprecated|npm warn|prebuild|SWITCH|WARNING|buffer' || true

echo "[$LAYER] dropping null geometry + building index"
node -e "
const fs=require('fs');
const g=JSON.parse(fs.readFileSync('$TMP','utf8'));
const before=g.features.length;
g.features=g.features.filter(f=>f.geometry);
fs.writeFileSync('$TMP',JSON.stringify(g));
const bbox=f=>{let a=[180,90,-180,-90];const w=c=>{if(typeof c[0]==='number'){if(c[0]<a[0])a[0]=c[0];if(c[1]<a[1])a[1]=c[1];if(c[0]>a[2])a[2]=c[0];if(c[1]>a[3])a[3]=c[1];}else c.forEach(w)};w(f.geometry.coordinates);return a.map(n=>+n.toFixed(5));};
const meta=g.features.map(f=>({code:f.properties['$CODE'],name:f.properties['$NAME'],state:f.properties['$STATE'],bbox:bbox(f)})).sort((x,y)=>x.name.localeCompare(y.name));
fs.writeFileSync('${OUT}_index.json',JSON.stringify(meta));
console.log('  kept',g.features.length,'of',before,'features; index',(fs.statSync('${OUT}_index.json').size/1024).toFixed(0),'KB');
"

echo "[$LAYER] building pmtiles"
tippecanoe -o "${OUT}.pmtiles" -f \
  -l "$LAYER" \
  --minimum-zoom=0 --maximum-zoom=10 \
  --coalesce-densest-as-needed --extend-zooms-if-still-dropping \
  --simplification=4 --generate-ids \
  "$TMP" >/dev/null 2>&1

echo "[$LAYER] done -> ${OUT}.pmtiles ($(ls -lh "${OUT}.pmtiles" | awk '{print $5}'))"
