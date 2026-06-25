#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Thasos Wildfire Pipeline
# Downloads Copernicus EMS satellite-derived burned area data
# for Thasos island, Greece, converts shapefiles to GeoParquet.
#
# Data source: Copernicus Emergency Management Service (EMS)
# License: European Commission reuse notice (open, attribution required)
#
# Events covered:
#   EMSR624 - August 2022 (Potamia/Kinira fire) — auto-downloaded
#   EMSR180 - September 2016 (four fires, dry lightning) — see README
#
# Usage:
#   ./pipeline.sh
# ============================================================

DATA_RAW="data/raw"
DATA_PROCESSED="data/processed"
mkdir -p "$DATA_RAW" "$DATA_PROCESSED"

echo "Thasos Wildfire Pipeline - Copernicus EMS Data"
echo ""

# ============================================================
# EMSR624 - August 2022 fire near Potamia/Kinira
# Confirmed working URL from EU S3 bucket
# ============================================================
EVENT="EMSR624"
URL="https://cems-mapping-website.s3.eu-west-1.amazonaws.com/static/activations/EMSR624/EMSR624_AOI01_GRA_PRODUCT_r1_RTP01_v1_vector.zip"
ZIP_FILE="$DATA_RAW/${EVENT}_vector.zip"
EXTRACT_DIR="$DATA_RAW/${EVENT}"
OUTPUT="$DATA_PROCESSED/${EVENT}_burned_areas.parquet"

echo "Processing $EVENT (2022-08-10)"
echo "================================================================"

# Download
if [ -f "$ZIP_FILE" ]; then
    echo "Already downloaded: $ZIP_FILE"
else
    echo "Downloading $EVENT vector package..."
    curl -L --progress-bar -o "$ZIP_FILE" "$URL"
    FILE_SIZE=$(wc -c < "$ZIP_FILE" | tr -d ' ')
    if [ "$FILE_SIZE" -lt 10000 ]; then
        echo "ERROR: Download failed - file is only $FILE_SIZE bytes."
        echo "Check URL: $URL"
        rm "$ZIP_FILE"
        exit 1
    fi
    echo "Downloaded ($FILE_SIZE bytes)"
fi

# Extract
if [ -d "$EXTRACT_DIR" ]; then
    echo "Already extracted: $EXTRACT_DIR"
else
    echo "Extracting..."
    mkdir -p "$EXTRACT_DIR"
    unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"
    echo "Extracted to $EXTRACT_DIR"
fi

# Find shapefile - Copernicus grading products contain _GRA_ in filename
SHP_FILE=$(find "$EXTRACT_DIR" -name "*GRA*.shp" | head -1)
[ -z "$SHP_FILE" ] && SHP_FILE=$(find "$EXTRACT_DIR" -name "*.shp" | head -1)

if [ -z "$SHP_FILE" ]; then
    echo "ERROR: No shapefile found in $EXTRACT_DIR"
    find "$EXTRACT_DIR" -type f
    exit 1
fi

echo "Shapefile: $SHP_FILE"

# Convert to GeoParquet - reproject to EPSG:4326 for portability
echo "Converting to GeoParquet (EPSG:4326)..."
rm -f "$OUTPUT"
ogr2ogr \
    -f "Parquet" \
    "$OUTPUT" \
    "$SHP_FILE" \
    -t_srs EPSG:4326 \
    -skipfailures

PARQUET_SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
echo "Created $OUTPUT ($PARQUET_SIZE bytes)"
echo ""

# ============================================================
# EMSR180 - September 2016 fires (optional, manual download)
# The old Copernicus file server migrated and direct URLs changed.
# Download manually from:
# https://emergency.copernicus.eu/mapping/list-of-components/EMSR180
# Place the zip in data/raw/EMSR180_vector.zip and rerun this script.
# ============================================================
EMSR180_ZIP="$DATA_RAW/EMSR180_vector.zip"
EMSR180_DIR="$DATA_RAW/EMSR180"
EMSR180_OUT="$DATA_PROCESSED/EMSR180_burned_areas.parquet"

if [ -f "$EMSR180_ZIP" ]; then
    echo "Processing EMSR180 (2016-09-10)"
    echo "================================================================"
    if [ ! -d "$EMSR180_DIR" ]; then
        mkdir -p "$EMSR180_DIR"
        unzip -q "$EMSR180_ZIP" -d "$EMSR180_DIR"
        echo "Extracted EMSR180"
    fi
    SHP180=$(find "$EMSR180_DIR" -name "*.shp" | head -1)
    if [ -n "$SHP180" ]; then
        rm -f "$EMSR180_OUT"
        ogr2ogr -f "Parquet" "$EMSR180_OUT" "$SHP180" -t_srs EPSG:4326 -skipfailures
        echo "Created $EMSR180_OUT"
    fi
else
    echo "EMSR180 (2016) not found - skipping."
    echo "To include: download manually from Copernicus EMS and place at:"
    echo "$EMSR180_ZIP"
fi

echo ""
echo "================================================================"
echo "Summary"
echo "================================================================"
ls -lh "$DATA_PROCESSED"/*.parquet 2>/dev/null || echo "No parquet files yet."
echo ""
echo "Dataset info:"
ogrinfo -so "$OUTPUT" 2>/dev/null || true
echo ""
echo "Done. Load parquet files into QGIS, DuckDB or GeoPandas."
echo "Source: Copernicus EMS - European Union (attribution required)"
