context("Local CAS server harness")

test_that("local server starts, answers, and stops", {
  skip_without_local_cas()
  h <- start_local_cas()
  on.exit(stop_local_cas(h), add = TRUE)
  port <- as.integer(sub("^.*:", "", h$endpoint))
  conn <- socketConnection("127.0.0.1", port, open = "r+b", timeout = 5)
  expect_true(isOpen(conn))
  close(conn)
  stop_local_cas(h)
  expect_false(h$proc$is_alive())
})
