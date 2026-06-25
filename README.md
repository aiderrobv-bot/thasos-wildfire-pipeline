# Thasos Wildfire Pipeline

A pipeline that downloads Copernicus Emergency Management Service (EMS) satellite-derived burned area data for Thasos island, Greece, and converts it to GeoParquet ready for analysis in QGIS, DuckDB, or GeoPandas.

## What it does

`pipeline.sh` pulls the official EU Copernicus EMS vector package for the August 2022 wildfire near Potamia and Kinira villages, extracts the burned area shapefile, reprojects to EPSG:4326, and outputs a GeoParquet file at `data/processed/EMSR624_burned_areas.parquet`.

The output contains satellite-derived **burn severity polygons** — not points, but actual mapped geometry of the fire extent graded by damage level. This is the same data used by local authorities for recovery and restoration planning.

## The data

- **Source:** [Copernicus Emergency Management Service — EMSR624](https://mapping.emergency.copernicus.eu/activations/EMSR624/)
- **License:** European Commission reuse notice — open, attribution required
- **What's in it:** Satellite-derived burned area polygons with damage grading for the August 2022 wildfire on Thasos island (Eastern Macedonia and Thrace Region, Greece)
- **Event:** Fire started 10 August 2022 near Potamia village. 135 firefighters, 56 vehicles, 14 aircraft deployed. Kinira village evacuated.

### Adding the 2016 event (EMSR180)

The September 2016 activation (four simultaneous fires caused by dry lightning) is supported but requires a manual download since the old Copernicus file server migrated and direct URLs changed.

1. Visit: https://emergency.copernicus.eu/mapping/list-of-components/EMSR180
2. Download the vector package zip
3. Place it at `data/raw/EMSR180_vector.zip`
4. Rerun `./pipeline.sh` — it will detect and process it automatically

## How to run it

Requires GDAL (`ogr2ogr`) and standard Unix utilities.

```bash
git clone https://github.com/aiderrobv-bot/thasos-wildfire-pipeline.git
cd thasos-wildfire-pipeline
chmod +x pipeline.sh
./pipeline.sh
```

On Linux, the system GDAL may lack the Parquet driver. Install via conda:

```bash
conda install -c conda-forge gdal libgdal-arrow-parquet
```

## Verify the output

```bash
ogrinfo -so data/processed/EMSR624_burned_areas.parquet
```

## What I learned

Copernicus EMS delivers burned area data as damage-graded polygons derived from satellite imagery — a completely different geometry type from point-based event datasets like NOAA. The 2016 activation (EMSR180) exposed a real-world data availability problem: the old Copernicus file server migrated without redirects, silently returning a small HTML error page instead of a 404. I built the pipeline to detect this, skip gracefully, and guide the user to the manual download instead of failing silently. Working with EU open geodata also introduced the distinction between datasets with confirmed stable cloud URLs versus older activations that require manual retrieval.

## Stack

- bash
- curl
- GDAL / ogr2ogr
- GeoParquet
- Copernicus EMS (EU satellite data)
