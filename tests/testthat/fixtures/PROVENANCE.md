# Fixture provenance

These fixtures are generated data. No third-party content is included.

## Generator

- Script: `tests/testthat/fixtures/make_fixtures.R` (committed beside the outputs).
- Command: `cd <empty dir> && Rscript /path/to/tests/testthat/fixtures/make_fixtures.R`
- The script writes to the current working directory, uses fixed seeds (`20260101` for the Parquet data, `20260102` for the raster values), makes no network calls and writes no timestamps. `small.geojson` is written by hand and does not depend on sf or GDAL.

## Versions used to generate

- R 4.6.1
- arrow 25.0.1 (Parquet)
- terra 1.9.51 (GeoTIFF, with its bundled GDAL)
- sf 1.1.2 (installed, not used by the generator)

## Files

| File | Content | Size (bytes) | SHA-256 |
|------|---------|--------------|---------|
| `small.parquet` | 5 rows, columns `id` (int) and `value` (double, rounded to 4 dp), uncompressed | 1204 | `b2304007dff06e49999a4f203e256f24c513f58a38b0c51e3f0b4468b6deacee` |
| `small.geojson` | FeatureCollection of 3 Point features, with a `crs` member naming CRS84 (`urn:ogc:def:crs:OGC:1.3:CRS84`) | 529 | `547fbd685ad0685b0ad59fded27ebe4003419e0b295d3073d8f07ce09349b4fd` |
| `small.tif` | 16 x 16, 1 band, Float32, uncompressed, EPSG:32633, extent 500000-500160 E, 4500000-4500160 N | 2240 | `b926f2c071b5eb1ce2b474698f305422c991f5069545c3afb91cc126dacfc7a9` |

## Determinism

The SHA-256 values above are the determinism check. Two runs in fresh directories produced identical hashes with the versions listed.

The bytes of `small.parquet` and `small.tif` depend on the arrow and GDAL/terra builds (for example, the Parquet writer version is recorded in the file). Regenerating with other versions may change those hashes while the data stays the same. In that case, update the hashes here and note the new versions.

## Licence

The generated data in these files is dedicated to the public domain under CC0 1.0 Universal (https://creativecommons.org/publicdomain/zero/1.0/).
