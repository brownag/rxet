# Mock Xet backend for testing
# Provides in-process HTTP mocking without external dependencies

#' Create a mock CAS endpoint response
#'
#' @param hash Character string, the content hash
#' @param size Numeric, size in bytes
#' @keywords internal
mock_cas_chunk <- function(hash, size = 1024) {
  # Generate deterministic fake chunk bytes based on hash
  set.seed(as.numeric(charToRaw(substr(hash, 1, 8))))
  raw(size)
}

#' Create a mock metadata shard file (.xet format)
#'
#' Creates a list representing parsed shard metadata with chunk mappings.
#'
#' @param num_chunks Number of chunks in the shard
#' @param chunk_size Size of each chunk in bytes (last may be smaller)
#' @param total_size Total file size
#'
#' @return List with structure: list(chunks = list(list(hash, offset_start, offset_end, size), ...))
#' @keywords internal
mock_metadata_shard <- function(num_chunks = 10, chunk_size = 1e7, total_size = NULL) {
  if (is.null(total_size)) {
    total_size <- num_chunks * chunk_size
  }

  chunks <- lapply(seq_len(num_chunks), function(i) {
    offset_start <- (i - 1) * chunk_size
    offset_end <- min(i * chunk_size, total_size)
    actual_size <- offset_end - offset_start

    list(
      hash = sprintf("chunk_%03d_%s", i, substr(uuid::UUIDgenerate(), 1, 12)),
      offset_start = offset_start,
      offset_end = offset_end,
      size = actual_size
    )
  })

  list(
    file_hash = uuid::UUIDgenerate(),
    file_size = total_size,
    chunks = chunks
  )
}

#' Create a mock XET token endpoint response
#'
#' Simulates HuggingFace token endpoint for CAS access.
#'
#' @param validity_seconds How long the token is valid for (default 3600 = 1 hour)
#' @keywords internal
mock_xet_read_token <- function(validity_seconds = 3600) {
  list(
    accessToken = sprintf("token_%s", uuid::UUIDgenerate()),
    casUrl = "https://cas-cf.huggingface.co",
    exp = as.numeric(Sys.time()) + validity_seconds
  )
}

#' Simulate a file metadata HEAD request
#'
#' Returns HTTP response headers that would come from HF Hub.
#'
#' @param file_hash Character string, the content hash
#' @param file_size Numeric, total file size
#' @keywords internal
mock_head_file_response <- function(file_hash, file_size) {
  list(
    status = 200,
    headers = list(
      "X-Xet-Hash" = file_hash,
      "X-Linked-Size" = as.character(file_size),
      "Content-Type" = "application/octet-stream"
    )
  )
}

#' Mock backend state tracker
#'
#' Creates an in-memory backend that tracks all requests for test verification.
#'
#' @return List with methods: list(request_log = ..., get_chunk = ..., get_token = ..., get_file_metadata = ...)
#' @keywords internal
create_mock_backend <- function() {
  state <- list(
    requests = list(),  # Log of all requests
    shards = list(),    # Cached metadata shards
    chunks = list(),    # Cached chunk data
    tokens = list(),    # Cached tokens
    failures = list()   # Simulated failure scenarios
  )

  #' Record a request in the log
  record_request <- function(method, endpoint, params = NULL, response_status = 200) {
    request <- list(
      timestamp = Sys.time(),
      method = method,
      endpoint = endpoint,
      params = params,
      response_status = response_status
    )
    state$requests <<- c(state$requests, list(request))
    invisible(NULL)
  }

  #' Get or create a chunk
  get_or_create_chunk <- function(hash, size = 1024) {
    if (!(hash %in% names(state$chunks))) {
      state$chunks[[hash]] <<- mock_cas_chunk(hash, size)
    }
    state$chunks[[hash]]
  }

  #' Get or create a metadata shard
  get_or_create_shard <- function(file_hash, num_chunks = 10, chunk_size = 1e7) {
    if (!(file_hash %in% names(state$shards))) {
      state$shards[[file_hash]] <<- mock_metadata_shard(num_chunks, chunk_size)
    }
    state$shards[[file_hash]]
  }

  #' Simulate CAS GET /cas/<hash> endpoint
  api_get_chunk <- function(hash, size = 1024) {
    # Check if this endpoint is set to fail
    if (!is.null(state$failures[[hash]])) {
      record_request("GET", sprintf("/cas/%s", hash), response_status = 500)
      return(list(success = FALSE, error = state$failures[[hash]]))
    }

    chunk <- get_or_create_chunk(hash, size)
    record_request("GET", sprintf("/cas/%s", hash), response_status = 200)

    list(success = TRUE, data = chunk)
  }

  #' Simulate HF Hub HEAD /<repo>/<path> endpoint
  api_head_file <- function(repo_id, file_path) {
    endpoint <- sprintf("/%s/resolve/main/%s", repo_id, file_path)

    file_hash <- sprintf("file_%s_%s", repo_id, file_path)
    file_size <- 1e9  # Default 1GB

    record_request("HEAD", endpoint, response_status = 200)
    list(success = TRUE, data = mock_head_file_response(file_hash, file_size))
  }

  #' Simulate token endpoint: GET /api/models/<repo>/xet-read-token/<branch>
  api_get_read_token <- function(repo_id, branch = "main") {
    endpoint <- sprintf("/api/models/%s/xet-read-token/%s", repo_id, branch)

    if (!is.null(state$failures[[endpoint]])) {
      record_request("GET", endpoint, response_status = 401)
      return(list(success = FALSE, error = "Unauthorized"))
    }

    token <- mock_xet_read_token(3600)
    record_request("GET", endpoint, response_status = 200)

    list(success = TRUE, data = token)
  }

  #' Get the request log
  get_request_log <- function() {
    state$requests
  }

  #' Check if an endpoint was called
  endpoint_called <- function(method, endpoint) {
    any(sapply(state$requests, function(req) {
      req$method == method && grepl(endpoint, req$endpoint)
    }))
  }

  #' Count calls to an endpoint
  count_calls <- function(method, endpoint) {
    sum(sapply(state$requests, function(req) {
      req$method == method && grepl(endpoint, req$endpoint)
    }))
  }

  #' Set an endpoint to fail on next request
  set_failure <- function(identifier, error_message) {
    state$failures[[identifier]] <<- error_message
    invisible(NULL)
  }

  #' Clear all failures
  clear_failures <- function() {
    state$failures <<- list()
    invisible(NULL)
  }

  #' Reset state for new test
  reset <- function() {
    state$requests <<- list()
    state$shards <<- list()
    state$chunks <<- list()
    state$tokens <<- list()
    state$failures <<- list()
    invisible(NULL)
  }

  # Return public API
  list(
    api_get_chunk = api_get_chunk,
    api_head_file = api_head_file,
    api_get_read_token = api_get_read_token,
    get_request_log = get_request_log,
    endpoint_called = endpoint_called,
    count_calls = count_calls,
    set_failure = set_failure,
    clear_failures = clear_failures,
    reset = reset,
    state = function() state  # For debugging
  )
}

#' Create a test fixture with sample files
#'
#' Returns a list of test data: file metadata, chunks, shards.
#'
#' @keywords internal
create_test_fixtures <- function() {
  # Small test file (10MB, 10 chunks of 1MB each)
  small_file <- mock_metadata_shard(
    num_chunks = 10,
    chunk_size = 1e6,
    total_size = 1e7
  )

  # Medium test file (1GB, 10 chunks of 100MB each)
  medium_file <- mock_metadata_shard(
    num_chunks = 10,
    chunk_size = 1e8,
    total_size = 1e9
  )

  # Large test file (10GB, 100 chunks of 100MB each)
  large_file <- mock_metadata_shard(
    num_chunks = 100,
    chunk_size = 1e8,
    total_size = 1e10
  )

  # Parquet-like file (500MB)
  parquet_file <- mock_metadata_shard(
    num_chunks = 5,
    chunk_size = 1e8,
    total_size = 5e8
  )

  # GeoTIFF-like file (2GB)
  geotiff_file <- mock_metadata_shard(
    num_chunks = 20,
    chunk_size = 1e8,
    total_size = 2e9
  )

  list(
    small = small_file,
    medium = medium_file,
    large = large_file,
    parquet = parquet_file,
    geotiff = geotiff_file
  )
}

#' Create test scenarios with known outcomes
#'
#' Returns list of scenarios: slow network, transient failure, token expiry, etc.
#'
#' @keywords internal
create_test_scenarios <- function() {
  list(
    # Scenario 1: Slow network (token expires mid-download)
    slow_network = list(
      name = "Slow network with token expiry",
      description = "Token expires while chunks are downloading; client must refresh",
      token_validity = 30,  # seconds
      chunk_download_time = 10,  # seconds per chunk
      expected_behavior = "Token refresh succeeds; download resumes"
    ),

    # Scenario 2: Transient failure (CAS returns 503, then succeeds)
    transient_failure = list(
      name = "Transient CAS failure",
      description = "CAS returns 503 Service Unavailable; retry succeeds",
      failure_count = 1,
      expected_behavior = "Retry succeeds; total attempts = 2"
    ),

    # Scenario 3: Byte-range request for partial file
    byte_range = list(
      name = "Partial file download",
      description = "Download middle 100MB of 1GB file",
      file_size = 1e9,
      start_byte = 450e6,
      end_byte = 550e6,
      expected_behavior = "Returns only overlapping chunks; 5-10x faster than full download"
    ),

    # Scenario 4: Concurrent clients (multiple simultaneous downloads)
    concurrent = list(
      name = "Concurrent downloads",
      description = "4 clients download different files simultaneously",
      num_clients = 4,
      files_per_client = 3,
      expected_behavior = "All complete without resource exhaustion; memory stays bounded"
    ),

    # Scenario 5: Very large file with 100+ chunks
    large_file = list(
      name = "Large file with many chunks",
      description = "Download 10GB file split into 100 chunks",
      file_size = 1e10,
      num_chunks = 100,
      expected_behavior = "Metadata lookup O(log N); download parallelizes; completes < 5min"
    )
  )
}
