# Australian Boundary Explorer

A minimal MapLibre GL app that shows Australian administrative/statistical
boundaries (LGA, SA2, SA3, SA4, State) on a map. Pick a boundary type and an
area from the dropdowns; the map zooms to it and highlights its border.

The boundaries are served as [PMTiles](https://docs.protomaps.com/pmtiles/)
vector tiles by a small [Fastify](https://fastify.dev/) static server.

## Installation

**Prerequisites**

- [nvm](https://github.com/nvm-sh/nvm) with Node 20+ (`.nvmrc` pins Node 22)
- [tippecanoe](https://github.com/felt/tippecanoe) — builds the vector tiles:
  ```sh
  brew install tippecanoe
  ```
  (`mapshaper` is used too, but runs via `npx` — nothing to install.)

**Install app dependencies**

```sh
nvm use          # switch to Node 22 (reads .nvmrc)
npm install      # Fastify + @fastify/static
```

## Generating the tiles

**Why this is needed:** browsers can't read ESRI shapefiles, and the raw ABS
files are huge (~200 MB). The build step converts them into compact PMTiles
vector tiles that MapLibre streams tile-by-tile, plus a tiny JSON index that
powers the dropdowns and the zoom-to-area behaviour.

1. Download the **GDA2020** digital boundary ZIPs from the ABS ASGS Edition 3
   page:
   <https://www.abs.gov.au/statistics/standards/australian-statistical-geography-standard-asgs/edition-3-july-2021-june-2026/access-and-downloads/digital-boundary-files>
   - LGA (2025), SA2 (2021), SA3 (2021), SA4 (2021)

2. Unzip each into `data/`, one folder per dataset. The scripts expect these
   exact folders and shapefile names:

   ```
   data/lga_2025/LGA_2025_AUST_GDA2020.shp   (+ .dbf .shx .prj)
   data/sa2_2021/SA2_2021_AUST_GDA2020.shp
   data/sa3_2021/SA3_2021_AUST_GDA2020.shp
   data/sa4_2021/SA4_2021_AUST_GDA2020.shp
   ```

3. Build every tileset into `public/tiles/`:

   ```sh
   nvm use
   npm run build
   ```

   This produces a `.pmtiles` + `_index.json` for each of LGA, SA2, SA3, SA4,
   and State. (State is derived by dissolving the LGA boundaries — no separate
   download.) To rebuild a single layer, call `scripts/build-tiles.sh`
   directly; see the comments at the top of that file.

## Running the application

```sh
nvm use
npm start        # http://localhost:8000  (set PORT to change)
```

Open <http://localhost:8000> and use the two dropdowns.

> The server must support HTTP range requests for PMTiles to work.
> `@fastify/static` does this out of the box.

## Data source

Boundary data © [Australian Bureau of Statistics](https://www.abs.gov.au/),
ASGS Edition 3, licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). LGA data is the 2025
edition; SA2/SA3/SA4 are the 2021 edition.
