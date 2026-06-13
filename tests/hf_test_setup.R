#' Generate test files in tests/fixtures/
#'
#' Creates test_data.parquet, test_data.json, and test_features.geojson.
#' See HF_TEST_SETUP.md for the workflow.
#'
#' @export
create_test_files <- function() {
  output_dir <- file.path(rprojroot::find_root(rprojroot::is_r_package), "tests", "fixtures")
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  # Parquet file (100 rows × 3 columns, ~2.9 KB)
  df <- data.frame(
    id = 1:100,
    value = rnorm(100),
    category = sample(c('A', 'B', 'C'), 100, replace = TRUE)
  )
  arrow::write_parquet(df, file.path(output_dir, "test_data.parquet"))

  # JSON file (3 records, ~146 bytes)
  json_data <- '[
    {"id": 1, "name": "test1", "value": 42.5},
    {"id": 2, "name": "test2", "value": 3.14},
    {"id": 3, "name": "test3", "value": 2.71}
  ]'
  writeLines(json_data, file.path(output_dir, "test_data.json"))

  # GeoJSON file (2 point features, ~368 bytes)
  geojson_data <- '{
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "properties": {"name": "test_point_1"},
        "geometry": {"type": "Point", "coordinates": [0, 0]}
      },
      {
        "type": "Feature",
        "properties": {"name": "test_point_2"},
        "geometry": {"type": "Point", "coordinates": [1, 1]}
      }
    ]
  }'
  writeLines(geojson_data, file.path(output_dir, "test_features.geojson"))

  message("Test files created in: ", output_dir)
  invisible(output_dir)
}
