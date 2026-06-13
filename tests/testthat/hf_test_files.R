# HuggingFace Hub Test File Hashes and Metadata
#
# This file contains the hashes and metadata for test files stored on HuggingFace Hub.
# To populate this file:
#
# 1. Follow the setup instructions in HF_TEST_SETUP.md
# 2. Upload test files to your HF Hub dataset repository
# 3. Retrieve Xet hashes using curl (see instructions)
# 4. Fill in the hashes below
#
# NOTE: If this file is not populated with real hashes, network tests will skip.

# Test repository on HuggingFace Hub
# Change this to your own repo if using a different one
HF_TEST_REPO <- "brownag/rxet-test-data"

# Test file hashes from HuggingFace Hub (retrieved via curl -i -L with grep x-xet-hash)
HF_TEST_FILES <- list(
  parquet = list(
    filename = "test_data.parquet",
    hash = "4e99cb45a4ad980707548c95f5cc3dadb91e36889c68adbff641e56c53981331",
    size_bytes = 2931,
    description = "Small test parquet file (100 rows × 3 cols, Xet-stored)"
  ),
  json = list(
    filename = "test_data.json",
    hash = "82b125d28b4895c416bcaec695cd3cff1dc646ea",  # Git-stored (not Xet), using etag
    size_bytes = 146,
    description = "Small test JSON file (3 records, git-stored)"
  ),
  geojson = list(
    filename = "test_features.geojson",
    hash = "b04f3a1aeab50e4fce14e1e670f62fa9d1d03b23",  # Git-stored (not Xet), using etag
    size_bytes = 368,
    description = "Test GeoJSON file (2 point features, git-stored)"
  )
)

# Helper function to check if hashes are configured
has_hf_test_hashes <- function() {
  all(nzchar(c(
    HF_TEST_FILES$parquet$hash,
    HF_TEST_FILES$json$hash,
    HF_TEST_FILES$geojson$hash
  )))
}

# Skip message for tests without configured hashes
get_hf_skip_reason <- function() {
  if (has_hf_test_hashes()) {
    return(NULL)
  }
  "HF test file hashes not configured - see hf_test_files.R"
}
