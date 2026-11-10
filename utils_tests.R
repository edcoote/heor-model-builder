# utils_tests.R — sanity tests for HEOR models
# Copied into each project by the heor-model-builder skill. Each test
# returns a one-row data frame; run_tests() binds them and stops on failure.

tol <- 1e-8

test_result <- function(test, pass, detail = "") {
  data.frame(test = test, pass = isTRUE(pass), detail = detail)
}

# P: transition matrix (states x states) or array (states x states x cycles)
test_transition_matrix <- function(P) {
  rows_ok <- if (length(dim(P)) == 3) {
    all(abs(apply(P, c(1, 3), sum) - 1) < tol)
  } else {
    all(abs(rowSums(P) - 1) < tol)
  }
  range_ok <- all(P >= -tol & P <= 1 + tol)
  test_result("Transition rows sum to 1 and entries in [0, 1]",
              rows_ok && range_ok,
              if (!rows_ok) "Row sums differ from 1" else if (!range_ok) "Entry outside [0, 1]" else "")
}

# trace: matrix (cycles x states), rows = cycles
test_trace_conserved <- function(trace) {
  dev <- max(abs(rowSums(trace) - 1))
  test_result("Cohort conserved in every cycle", dev < 1e-6,
              sprintf("Max deviation %.2e", dev))
}

# absorbing: name(s) or index of absorbing state columns in trace
test_absorbing_monotone <- function(trace, absorbing) {
  ok <- all(apply(as.matrix(trace[, absorbing]), 2, function(x) all(diff(x) >= -tol)))
  test_result("Absorbing state membership never decreases", ok)
}

# run_model: function(params) returning list(cost = c(...), qaly = c(...))
# with one element per strategy; params: named list of parameter values.
# make_identical: function(params) returning params with arms made identical.
test_identical_arms <- function(run_model, params, make_identical) {
  res <- run_model(make_identical(params))
  ok <- abs(diff(range(res$cost))) < 1e-6 && abs(diff(range(res$qaly))) < 1e-9
  test_result("Identical arms give zero increments", ok)
}

# Compare discounted run with d = 0 against the undiscounted totals
test_zero_discount <- function(run_model, params, undiscounted) {
  p0 <- params
  p0$disc_cost <- 0
  p0$disc_qaly <- 0
  res <- run_model(p0)
  ok <- all(abs(res$cost - undiscounted$cost) < 1e-6) &&
        all(abs(res$qaly - undiscounted$qaly) < 1e-9)
  test_result("Zero discount reproduces undiscounted totals", ok)
}

# Raise one cost parameter by 10% and check total cost does not fall
test_cost_monotone <- function(run_model, params, cost_param) {
  base <- run_model(params)$cost
  p_up <- params
  p_up[[cost_param]] <- p_up[[cost_param]] * 1.1
  up <- run_model(p_up)$cost
  test_result(paste0("Total cost non-decreasing in ", cost_param),
              all(up >= base - 1e-6))
}

test_utilities_bounded <- function(utilities) {
  test_result("No utility above 1", all(utilities <= 1 + tol, na.rm = TRUE),
              sprintf("Max %.3f", max(utilities, na.rm = TRUE)))
}

# det: list(cost, qaly) deterministic; psa: data frame with cost_<k>, qaly_<k>
# columns or a list of matrices — pass PSA means directly to keep it simple.
test_psa_vs_deterministic <- function(det, psa_mean, threshold = 0.05) {
  rel <- c(abs(psa_mean$cost - det$cost) / abs(det$cost),
           abs(psa_mean$qaly - det$qaly) / abs(det$qaly))
  test_result("PSA means within 5% of deterministic", all(rel < threshold),
              sprintf("Max relative difference %.1f%%", 100 * max(rel)))
}

# Bind results, print a summary and stop if any test failed
run_tests <- function(...) {
  results <- do.call(rbind, list(...))
  print(results, row.names = FALSE)
  if (!all(results$pass)) {
    stop("Sanity tests failed: ", paste(results$test[!results$pass], collapse = "; "))
  }
  invisible(results)
}

# Methods checklist test 8: with the disease switched off (no transitions out
# of the starting state other than background death, utility 1, no
# discounting), model life years should match the life table. ly_model is the
# undiscounted life years from that run. Tolerance allows for the half-cycle
# method and ONS's own Lx approximation near age 100.
test_life_expectancy <- function(ly_model, lt, age_start, prop_female,
                                 horizon_years, tol = 0.1) {
  ref <- lt_life_years(lt, age_start, prop_female, horizon_years)
  test_result("Life years with disease off match life tables",
              abs(ly_model - ref) < tol,
              sprintf("Model %.2f vs life table %.2f years", ly_model, ref))
}
