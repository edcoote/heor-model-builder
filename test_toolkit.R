# test_toolkit.R — checks the skill's R helpers give known answers.
# Run from the repository root:  Rscript tests/test_toolkit.R
# Exits with an error if any check fails.

root <- normalizePath(".")
source(file.path(root, "assets", "utils_conversions.R"))
source(file.path(root, "assets", "utils_tests.R"))
source(file.path(root, "tests", "toy_markov.R"))

n_pass <- 0
check <- function(desc, ok) {
  if (!isTRUE(ok)) stop("FAILED: ", desc, call. = FALSE)
  n_pass <<- n_pass + 1
  cat("  pass:", desc, "\n")
}
near <- function(a, b, tol = 1e-6) isTRUE(all(abs(a - b) < tol))

cat("Conversions (known answers)\n")
check("rate 0.1 over 1 year -> p = 1 - exp(-0.1)", near(rate_to_prob(0.1), 0.0951625820))
check("prob_to_rate inverts rate_to_prob", near(prob_to_rate(rate_to_prob(0.3, 2), 2), 0.3))
check("20% over 5 years -> 1 - 0.8^(1/5) per year", near(convert_prob(0.2, 5, 1), 1 - 0.8^(1/5)))
check("annual 10% -> monthly and back", near(convert_prob(convert_prob(0.1, 1, 1/12), 1/12, 1), 0.1))
check("HR of 1 leaves p unchanged", near(apply_hr(0.25, 1), 0.25))
check("HR of 2 on p = 0.1 gives 1 - 0.9^2", near(apply_hr(0.1, 2), 0.19))
check("OR of 3 on p = 0.5 gives 0.75", near(apply_or(0.5, 3), 0.75))
check("OR of 1 leaves p unchanged", near(apply_or(0.37, 1), 0.37))
check("RR above 1/p stops", inherits(try(apply_rr(0.6, 2), silent = TRUE), "try-error"))
check("discount factor at 1 year, 3.5%", near(discount_factor(1, 0.035), 1 / 1.035))
check("discount factor at 0 rate is 1", near(discount_factor(0:10, 0), rep(1, 11)))
check("half-cycle of a 2-row trace is the row mean",
      near(half_cycle_lifetable(rbind(c(1, 0), c(0.8, 0.2))), matrix(c(0.9, 0.1), 1)))

cat("Distribution fitting (moments recovered)\n")
b <- beta_params(0.3, 0.05)
check("beta mean", near(b[["shape1"]] / sum(b), 0.3))
check("beta SD", near(sqrt(prod(b) / (sum(b)^2 * (sum(b) + 1))), 0.05))
g <- gamma_params(1500, 300)
check("gamma mean", near(g[["shape"]] * g[["scale"]], 1500))
check("gamma SD", near(sqrt(g[["shape"]]) * g[["scale"]], 300))
l <- lognormal_params(0.7, 0.5, 0.98)
check("lognormal median equals point estimate", near(exp(l[["meanlog"]]), 0.7))
check("SE from 95% CI", near(se_from_ci(10, 14), 4 / (2 * qnorm(0.975))))

cat("Survival known answer: constant p = 0.1, 2 states\n")
P2 <- matrix(c(0.9, 0.1, 0, 1), 2, byrow = TRUE)
tr2 <- matrix(0, 401, 2); tr2[1, ] <- c(1, 0)
for (t in 1:400) tr2[t + 1, ] <- tr2[t, ] %*% P2
check("life years counted at cycle start = 1/p = 10", near(sum(tr2[1:400, 1]), 10, 1e-6))
check("life years with life-table correction = 9.5", near(sum(half_cycle_lifetable(tr2)[, 1]), 9.5, 1e-6))

cat("Sanity tests on the toy Markov model\n")
p <- toy_params
res <- run_toy(p)
undisc <- run_toy(modifyList(p, list(disc_cost = 0, disc_qaly = 0)))
run_tests(
  test_transition_matrix(toy_matrix(p)),
  test_transition_matrix(toy_matrix(p, TRUE)),
  test_trace_conserved(res$traces[[1]]),
  test_absorbing_monotone(res$traces[[1]], "Dead"),
  test_identical_arms(function(q) run_toy(q), p,
                      function(q) modifyList(q, list(hr_treat = 1, c_treat = 0))),
  test_zero_discount(function(q) run_toy(q), p, undisc),
  test_cost_monotone(function(q) run_toy(q), p, "c_sick"),
  test_utilities_bounded(c(p$u_well, p$u_sick))
)
n_pass <- n_pass + 8
check("treatment costs more and gains QALYs (expected direction)",
      res$cost[2] > res$cost[1] && res$qaly[2] > res$qaly[1])
check("utility of 1 everywhere: QALYs equal life years (undiscounted)", {
  q <- run_toy(modifyList(p, list(u_well = 1, u_sick = 1, disc_qaly = 0, disc_cost = 0)))
  ly <- sum(half_cycle_lifetable(q$traces[[1]])[, 1:2])
  near(q$qaly[1], ly)
})
check("all costs 0: total cost 0", all(run_toy(modifyList(p, list(c_well = 0, c_sick = 0, c_treat = 0)))$cost == 0))
check("certain death in cycle 1: QALYs = half a cycle of Well",
      near(run_toy(modifyList(p, list(p_wd = 1, p_ws = 0, disc_qaly = 0)))$qaly[1], p$u_well / 2))

cat("\nAll", n_pass, "checks passed.\n")
