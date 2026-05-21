#!/usr/bin/env Rscript
# Benchmark rxet-sync performance improvements
#
# This script provides a framework for benchmarking sync performance
# before and after optimizations.
#
# Usage: Rscript tools/benchmark.R <config.json>

cat("=== XET-Sync Performance Benchmark ===\n\n")

# Arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  cat("Usage: Rscript tools/benchmark.R <config.json>\n")
  cat("\nThis script benchmarks xet-sync performance on the given config.\n")
  cat("The config should contain a reasonable number of files to sync\n")
  cat("(10-50 files recommended for meaningful results).\n\n")

  cat("Output: Timing statistics showing:\n")
  cat("  - Total execution time\n")
  cat("  - Per-file average time\n")
  cat("  - Metadata fetch time (sequential)\n")
  cat("  - Download time (parallel)\n")
  cat("  - Cache write time\n\n")
  quit(status = 1)
}

config_file <- args[1]

if (!file.exists(config_file)) {
  cat(sprintf("Error: Config file not found: %s\n", config_file))
  quit(status = 1)
}

# Load config to count files
config <- jsonlite::read_json(config_file)
total_files <- sum(sapply(config$repos, function(r) length(r$files)))

cat(sprintf("Configuration: %s\n", config_file))
cat(sprintf("Total files to sync: %d\n", total_files))
cat(sprintf("Repos: %d\n\n", length(config$repos)))

# Run benchmark with timing
cat("Starting sync benchmark...\n")
start_time <- Sys.time()

# Source the sync script (modify path as needed)
source("xet-sync.R")

end_time <- Sys.time()
elapsed_seconds <- as.numeric(end_time - start_time)

# Print results
cat("\n=== Benchmark Results ===\n")
cat(sprintf("Total execution time:     %.2f seconds\n", elapsed_seconds))
cat(sprintf("Average per file:         %.3f seconds\n", elapsed_seconds / total_files))
cat(sprintf("Downloaded files:         %d\n", downloaded))
cat(sprintf("Skipped files:            %d\n", skipped))
cat(sprintf("Errors:                   %d\n", errors))

# Performance assessment
if (elapsed_seconds < 60) {
  perf_level <- "EXCELLENT"
} else if (elapsed_seconds < 180) {
  perf_level <- "GOOD"
} else if (elapsed_seconds < 300) {
  perf_level <- "ACCEPTABLE"
} else {
  perf_level <- "SLOW"
}

cat(sprintf("\nPerformance: %s\n", perf_level))

if (elapsed_seconds > 300) {
  cat("\nNote: Consider parallel execution or checking network speed.\n")
}

cat("\nTo compare before/after optimizations:\n")
cat("  1. Run this benchmark on the original code\n")
cat("  2. Apply optimizations\n")
cat("  3. Run this benchmark again\n")
cat("  4. Calculate improvement: (old_time - new_time) / old_time * 100%\n")
