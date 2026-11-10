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

cat("Background mortality from the bundled ONS life table\n")
lt <- read_life_table(file.path(root, "assets", "ons_life_tables_uk.csv"))
qx <- function(sex, age) lt$qx[lt$sex == sex & lt$age == age]
ex <- function(sex, age) lt$ex[lt$sex == sex & lt$age == age]
# Life years from per-cycle death probabilities, life-table half-cycle method
ly_from_p <- function(p, c = 1) {
  s <- c(1, cumprod(1 - p))
  sum(half_cycle_lifetable(cbind(s, 1 - s))[, 1]) * c
}
check("table has ages 0 to 100 for both sexes",
      all(table(lt$sex) == 101) && identical(range(lt$age), c(0L, 100L)))
check("annual cycle from age 50 (men) reproduces qx at 50, 51, 52",
      near(as.vector(background_mortality(lt, 50, 0, 3)),
           c(qx("male", 50), qx("male", 51), qx("male", 52)), 1e-12))
check("two 6-month cycles compound to the annual qx",
      near(1 - prod(1 - background_mortality(lt, 50, 0, 2, 0.5)), qx("male", 50), 1e-12))
check("50:50 cohort, first cycle: mean of male and female qx",
      near(background_mortality(lt, 50, 0.5, 1)[1],
           (qx("male", 50) + qx("female", 50)) / 2, 1e-12))
mix <- suppressWarnings(background_mortality(lt, 50, 0.5, 60))
men <- suppressWarnings(background_mortality(lt, 50, 0, 60))
wom <- suppressWarnings(background_mortality(lt, 50, 1, 60))
check("mixed cohort lies between women and men in every cycle",
      all(mix >= wom - 1e-12 & mix <= men + 1e-12))
check("mixed cohort drifts towards women's mortality as men die sooner",
      (mix[40] - wom[40]) / (men[40] - wom[40]) < (mix[1] - wom[1]) / (men[1] - wom[1]))
check("life expectancy at 50 (men) matches ONS ex within 0.05 years",
      near(ly_from_p(men), ex("male", 50), 0.05))
check("life expectancy at 50 (women) matches ONS ex within 0.05 years",
      near(ly_from_p(wom), ex("female", 50), 0.05))
check("monthly cycles give the same life expectancy as annual",
      near(ly_from_p(suppressWarnings(background_mortality(lt, 50, 0.5, 720, 1/12)), 1/12),
           ly_from_p(mix), 0.01))
check("horizon past age 101 warns", inherits(tryCatch(background_mortality(lt, 50, 0.5, 60),
                                                    warning = function(w) w), "warning"))
check("combine_mortality: independent hazards, 0.1 and 0.2 -> 0.28",
      near(combine_mortality(0.1, 0.2), 0.28))
check("combine_mortality: max for an all-cause disease figure",
      near(combine_mortality(c(0.1, 0.3), c(0.2, 0.2), "max"), c(0.2, 0.3)))
check("combine_mortality: no disease deaths leaves background unchanged",
      near(combine_mortality(men, 0), men))
check("lt_life_years past the table end returns ONS ex",
      near(lt_life_years(lt, 50, 0.3, 70),
           0.3 * ex("female", 50) + 0.7 * ex("male", 50)))

cat("Life-table test (methods checklist test 8)\n")
# Toy model with the disease switched off and ONS background mortality in
# place of the constant p_wd: Well -> Dead only, through a transition array.
bg <- background_mortality(lt, 50, 0.5, 40)
P_arr <- array(0, c(2, 2, 40))
P_arr[1, 1, ] <- 1 - bg; P_arr[1, 2, ] <- bg; P_arr[2, 2, ] <- 1
tr_bg <- matrix(0, 41, 2); tr_bg[1, ] <- c(1, 0)
for (t in 1:40) tr_bg[t + 1, ] <- tr_bg[t, ] %*% P_arr[, , t]
ly_bg <- sum(half_cycle_lifetable(tr_bg)[, 1])
run_tests(
  test_transition_matrix(P_arr),
  test_trace_conserved(tr_bg),
  test_life_expectancy(ly_bg, lt, 50, 0.5, 40)
)
n_pass <- n_pass + 3
check("test_life_expectancy fails a model with constant 2% mortality",
      !test_life_expectancy(ly_from_p(rep(0.02, 40)), lt, 50, 0.5, 40)$pass)

cat("\nAll", n_pass, "checks passed.\n")
