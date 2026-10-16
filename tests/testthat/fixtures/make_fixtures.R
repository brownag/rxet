# Regenerate the small test fixtures.
#
# Run from the directory where the outputs should be written:
#   cd <dir> && Rscript /path/to/tests/testthat/fixtures/make_fixtures.R
#
# Writes small.parquet, small.geojson and small.tif to getwd(). Fixed seeds,
# no network access, no timestamps. See PROVENANCE.md for versions and hashes.

need_pkg <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("make_fixtures.R needs %s; install it to regenerate fixtures", pkg),
         call. = FALSE)
  }
}

out_dir <- getwd()

# Parquet: five rows, two columns.
need_pkg("arrow")
set.seed(20260101L)
df <- data.frame(id = 1:5L, value = round(rnorm(5), 4))
arrow::write_parquet(df, file.path(out_dir, "small.parquet"),
                     compression = "uncompressed")

# GeoJSON: three point features with a CRS member. Written by hand so the
# bytes do not depend on GDAL or sf.
geojson <- c(
  '{',
  '  "type": "FeatureCollection",',
  '  "crs": { "type": "name", "properties": { "name": "urn:ogc:def:crs:OGC:1.3:CRS84" } },',
  '  "features": [',
  '    { "type": "Feature", "properties": { "name": "a", "n": 1 }, "geometry": { "type": "Point", "coordinates": [-98.5, 39.8] } },',
  '    { "type": "Feature", "properties": { "name": "b", "n": 2 }, "geometry": { "type": "Point", "coordinates": [-97.9, 40.1] } },',
  '    { "type": "Feature", "properties": { "name": "c", "n": 3 }, "geometry": { "type": "Point", "coordinates": [-98.2, 39.5] } }',
  '  ]',
  '}'
)
writeLines(geojson, file.path(out_dir, "small.geojson"), useBytes = TRUE)

# GeoTIFF: 16x16, one band, Float32, uncompressed.
need_pkg("terra")
set.seed(20260102L)
r <- terra::rast(nrows = 16, ncols = 16, nlyrs = 1, crs = "EPSG:32633",
                 extent = terra::ext(500000, 500160, 4500000, 4500160))
terra::values(r) <- round(runif(256), 4)
terra::writeRaster(r, file.path(out_dir, "small.tif"),
                   datatype = "FLT4S", overwrite = TRUE,
                   gdal = c("COMPRESS=NONE"))

invisible(lapply(c("small.parquet", "small.geojson", "small.tif"),
                 function(f) cat(f, "written\n")))
