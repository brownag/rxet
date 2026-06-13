context("Client initialization and lifecycle")

test_that("xet_client_new returns non-empty character handle", {
  skip_if_not(is_compiled(), "Rust extension not available")

  with_test_client({
    expect_is(client, "character")
    expect_gt(nchar(client), 0)
  })
})

test_that("xet_client_new handle is valid UUID format", {
  skip_if_not(is_compiled())

  with_test_client({
    # UUID format: 8-4-4-4-12 hex digits separated by hyphens
    uuid_pattern <- "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    expect_match(client, uuid_pattern, ignore.case = TRUE)
  })
})

test_that("xet_client_close closes the handle", {
  skip_if_not(is_compiled())

  client <- xet_client_new("https://cas-cf.huggingface.co", "test_token")
  expect_silent(xet_client_close(client))
})

test_that("xet_client_close with unknown handle errors", {
  skip_if_not(is_compiled())

  fake_handle <- "00000000-0000-0000-0000-000000000000"
  expect_error(xet_client_close(fake_handle), "invalid")
})

test_that("double-close produces error", {
  skip_if_not(is_compiled())

  client <- xet_client_new("https://cas-cf.huggingface.co", "test_token")
  xet_client_close(client)
  expect_error(xet_client_close(client), "invalid")
})

test_that("multiple clients can coexist", {
  skip_if_not(is_compiled())

  client1 <- xet_client_new("https://cas-cf.huggingface.co", "token1")
  client2 <- xet_client_new("https://cas-cf.huggingface.co", "token2")

  expect_false(identical(client1, client2))

  expect_silent(xet_client_close(client1))
  expect_silent(xet_client_close(client2))
})

test_that("xet_client_close returns NULL invisibly", {
  skip_if_not(is_compiled())

  client <- xet_client_new("https://cas-cf.huggingface.co", "test_token")
  result <- xet_client_close(client)
  expect_null(result)
})
