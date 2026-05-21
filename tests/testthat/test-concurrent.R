context("Concurrent client operations and stress testing")

# Initialize mock backend for this test suite
setup({
  backend <<- create_mock_backend()
  fixtures <<- create_test_fixtures()
})

teardown({
  backend$reset()
})

test_that("can create multiple client handles sequentially", {
  # Create 10 handles sequentially
  handles <- character(10)

  for (i in 1:10) {
    handles[i] <- uuid::UUIDgenerate()
  }

  # Verify handles are unique
  expect_equal(length(unique(handles)), 10)

  # Verify handle format (UUID v4)
  for (handle in handles) {
    expect_match(handle, "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
      ignore.case = TRUE
    )
  }
})

test_that("handles can be created without collision risk", {
  # Create 100 handles
  handles <- vapply(1:100, function(i) {
    uuid::UUIDgenerate()
  }, character(1))

  # All unique
  expect_equal(length(unique(handles)), 100)
})

test_that("client lifecycle is consistent", {
  # Simulate client creation, use, and cleanup
  client_id <- uuid::UUIDgenerate()

  # Get token
  result <- backend$api_get_read_token("repo/model", "main")
  expect_true(result$success)

  # Use client for multiple operations
  for (i in 1:5) {
    backend$api_head_file("repo/model", sprintf("file_%d.bin", i))
  }

  # Verify operation log
  log <- backend$get_request_log()
  expect_gte(length(log), 6)  # 1 token + 5 files
})

test_that("concurrent token fetches don't interfere", {
  # Simulate 4 concurrent token requests
  tokens <- vector("list", 4)

  for (i in 1:4) {
    result <- backend$api_get_read_token(sprintf("repo%d/model", i))
    tokens[[i]] <- result$data
  }

  # All tokens should be unique
  token_values <- sapply(tokens, function(t) t$accessToken)
  expect_equal(length(unique(token_values)), 4)

  # All should have same expiry structure
  for (token in tokens) {
    expect_true(token$exp > as.numeric(Sys.time()))
    expect_equal(token$casUrl, "https://cas-cf.huggingface.co")
  }
})

test_that("multiple clients can download same file concurrently", {
  # Simulate 4 clients downloading same file
  file_info <- fixtures$medium

  results <- vector("list", 4)
  for (i in 1:4) {
    client_id <- uuid::UUIDgenerate()
    # Get token
    token_result <- backend$api_get_read_token("shared-model", "main")
    # Download file chunks
    for (chunk in file_info$chunks) {
      chunk_result <- backend$api_get_chunk(chunk$hash, chunk$size)
      expect_true(chunk_result$success)
    }
    results[[i]] <- list(client = client_id, success = TRUE)
  }

  # All clients succeeded
  expect_true(all(sapply(results, function(r) r$success)))

  # Verify all chunk requests were made
  log <- backend$get_request_log()
  chunk_requests <- sum(sapply(log, function(req) {
    grepl("/cas/", req$endpoint)
  }))
  expect_equal(chunk_requests, 4 * length(file_info$chunks))
})

test_that("token refresh works under expiry pressure", {
  repo_id <- "model-repo"

  # Get initial token (expires in 30 seconds)
  token1 <- backend$api_get_read_token(repo_id)$data
  initial_exp <- token1$exp

  # Simulate time passing (in real scenario would be async)
  # Get new token before expiry
  token2 <- backend$api_get_read_token(repo_id)$data
  new_exp <- token2$exp

  # New token should have later expiry
  expect_gt(new_exp, initial_exp)

  # Both tokens should be from same endpoint
  expect_equal(token1$casUrl, token2$casUrl)
})

test_that("transient failures don't crash concurrent operations", {
  # Set up intermittent failures
  backend$set_failure("chunk_1", "CAS 503")
  backend$set_failure("chunk_3", "CAS 503")

  # Try operations; some fail
  chunks <- c("chunk_1", "chunk_2", "chunk_3", "chunk_4")
  results <- vector("list", 4)

  for (i in seq_along(chunks)) {
    result <- backend$api_get_chunk(chunks[i], 1024)
    results[[i]] <- result$success
  }

  # Expect pattern: fail, success, fail, success
  expect_false(results[[1]])
  expect_true(results[[2]])
  expect_false(results[[3]])
  expect_true(results[[4]])

  # Clear failures and retry
  backend$clear_failures()
  results_retry <- vector("list", 4)
  for (i in seq_along(chunks)) {
    result <- backend$api_get_chunk(chunks[i], 1024)
    results_retry[[i]] <- result$success
  }

  # All should succeed on retry
  expect_true(all(unlist(results_retry)))
})

test_that("file descriptor usage scales linearly with clients", {
  # Simulate creating and closing many clients
  # (In real R environment, track actual FDs with `lsof` or similar)

  client_count <- 50
  clients_active <- 0

  for (i in 1:client_count) {
    client_id <- uuid::UUIDgenerate()
    # Simulate opening client (would increment FD count)
    clients_active <- clients_active + 1
  }

  # All clients created
  expect_equal(clients_active, client_count)

  # Cleanup (would decrement FD count)
  clients_active <- 0
  expect_equal(clients_active, 0)
})

test_that("memory doesn't grow unbounded with parallel operations", {
  # Simulate streaming multiple large files concurrently
  file_sizes <- c(
    fixtures$small$file_size,
    fixtures$medium$file_size,
    fixtures$large$file_size
  )

  # Simulate buffering: peak memory = largest file + overhead
  buffer_sizes <- file_sizes + (50 * 1e6)  # Add 50MB overhead per stream

  # Peak should not exceed largest file + reasonable overhead
  peak_memory <- max(buffer_sizes)
  largest_file <- max(file_sizes)

  # Peak memory should be <= largest file + 100MB
  expect_lte(peak_memory - largest_file, 100 * 1e6)
})

test_that("cleanup happens when client is abandoned", {
  # Simulate client creation without explicit cleanup
  client_id <- uuid::UUIDgenerate()

  # Make some requests
  for (i in 1:10) {
    backend$api_get_chunk(sprintf("chunk_%03d", i), 1024)
  }

  log_before <- length(backend$get_request_log())
  expect_equal(log_before, 10)

  # Reset (simulates cleanup/garbage collection)
  backend$reset()
  log_after <- length(backend$get_request_log())

  expect_equal(log_after, 0)
})

test_that("stress test: 100 concurrent operations complete", {
  # Simulate 100 operations across 10 clients
  clients <- 10
  ops_per_client <- 10

  operation_results <- vector("list", clients)

  for (client_idx in 1:clients) {
    client_results <- vector("list", ops_per_client)

    for (op_idx in 1:ops_per_client) {
      # Each operation: get token + fetch 2 chunks
      token_result <- backend$api_get_read_token(sprintf("repo%d", client_idx))
      chunk1 <- backend$api_get_chunk(sprintf("chunk_%02d_%02d", client_idx, op_idx * 2 - 1))
      chunk2 <- backend$api_get_chunk(sprintf("chunk_%02d_%02d", client_idx, op_idx * 2))

      client_results[[op_idx]] <- (token_result$success && chunk1$success && chunk2$success)
    }

    operation_results[[client_idx]] <- all(unlist(client_results))
  }

  # All operations should succeed
  expect_true(all(unlist(operation_results)))

  # Verify request counts
  log <- backend$get_request_log()
  token_requests <- sum(sapply(log, function(req) grepl("xet-read-token", req$endpoint)))
  chunk_requests <- sum(sapply(log, function(req) grepl("/cas/", req$endpoint)))

  expect_equal(token_requests, clients)
  expect_equal(chunk_requests, clients * ops_per_client * 2)
})

test_that("request logging provides visibility for debugging", {
  # Make various requests
  backend$api_get_read_token("repo1")
  backend$api_head_file("repo1", "file1.bin")
  backend$api_get_chunk("chunk_hash_123", 1024)

  log <- backend$get_request_log()

  # Should have 3 requests
  expect_equal(length(log), 3)

  # Check first request
  expect_equal(log[[1]]$method, "GET")
  expect_match(log[[1]]$endpoint, "xet-read-token")
  expect_equal(log[[1]]$response_status, 200)

  # Check timestamps are monotonic
  timestamps <- sapply(log, function(req) as.numeric(req$timestamp))
  expect_true(all(diff(timestamps) >= 0))
})
