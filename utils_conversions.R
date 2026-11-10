# utils_conversions.R — transition conversions, discounting, half-cycle
# correction and PSA distribution fitting. Copied into each project by the
# heor-model-builder skill. See references/methods_checklist.md for when to
# use each function.

# ---- Probabilities, rates and relative effects ------------------------------

# Constant rate over t years -> probability of the event within t years
rate_to_prob <- function(rate, t = 1) {
  stopifnot(all(rate >= 0))
  1 - exp(-rate * t)
}

# Probability within t years -> constant rate per year
prob_to_rate <- function(p, t = 1) {
  stopifnot(all(p >= 0 & p < 1))
  -log(1 - p) / t
}

# Probability over from_t years -> probability over to_t years (e.g. cycle)
# Valid when only one event can happen from the state; see methods_checklist.
convert_prob <- function(p, from_t, to_t) {
  rate_to_prob(prob_to_rate(p, from_t), to_t)
}

# Hazard ratio applied to a per-cycle probability
apply_hr <- function(p, hr) {
  stopifnot(all(p >= 0 & p < 1), all(hr >= 0))
  1 - (1 - p)^hr
}

# Odds ratio applied to a probability (same time period as the OR)
apply_or <- function(p, or) {
  stopifnot(all(p >= 0 & p < 1), all(or >= 0))
  odds <- or * p / (1 - p)
  odds / (1 + odds)
}

# Relative risk applied to a probability; stops if the result exceeds 1
apply_rr <- function(p, rr) {
  out <- rr * p
  if (any(out > 1)) stop("RR gives a probability above 1: convert to rates and apply as a HR")
  out
}

# ---- Discounting and half-cycle correction ----------------------------------

# Discount factor at t_years (vector) for an annual rate
discount_factor <- function(t_years, rate) {
  1 / (1 + rate)^t_years
}

# Life-table half-cycle correction: mean of consecutive trace rows.
# trace has n_cycles + 1 rows (row 1 = start). Returns n_cycles rows.
half_cycle_lifetable <- function(trace) {
  trace <- as.matrix(trace)
  (trace[-nrow(trace), , drop = FALSE] + trace[-1, , drop = FALSE]) / 2
}

# ---- PSA distribution fitting ----------------------------------------------

se_from_ci <- function(low, high, level = 0.95) {
  (high - low) / (2 * qnorm(1 - (1 - level) / 2))
}

beta_params <- function(mean, se) {
  stopifnot(mean > 0, mean < 1, se > 0)
  a <- mean * (mean * (1 - mean) / se^2 - 1)
  b <- a * (1 - mean) / mean
  if (a <= 0 || b <= 0) stop("SE too large for a beta with this mean")
  c(shape1 = a, shape2 = b)
}

gamma_params <- function(mean, se) {
  stopifnot(mean > 0, se > 0)
  c(shape = mean^2 / se^2, scale = se^2 / mean)
}

# Lognormal for ratios (HR, OR, RR) from a point estimate and its CI
lognormal_params <- function(mean, low, high, level = 0.95) {
  stopifnot(mean > 0, low > 0, high > low)
  c(meanlog = log(mean),
    sdlog = (log(high) - log(low)) / (2 * qnorm(1 - (1 - level) / 2)))
}

# ---- Background mortality from life tables -----------------------------------
# For UK models the skill bundles ONS life tables as
# inputs/raw/ons_life_tables_uk.csv (columns age, sex, qx, lx, ex, ...).
# See references/methods_checklist.md §3 for when to use each function.

read_life_table <- function(path) {
  lt <- utils::read.csv(path, stringsAsFactors = FALSE)
  stopifnot(all(c("age", "sex", "qx", "lx", "ex") %in% names(lt)),
            all(c("male", "female") %in% lt$sex))
  lt
}

# Survival from exact age a0 to exact age a (vectors) for one sex. The hazard
# -log(1 - qx) is held constant within each year of age, so any cycle length
# and fractional start ages work. Ages past the end of the table reuse the
# last hazard (ONS tables stop at 100).
lt_survival <- function(lt, sex, a0, a) {
  d <- lt[lt$sex == sex, ]
  d <- d[order(d$age), ]
  mu <- -log(1 - d$qx)
  top <- max(d$age)
  cum_h <- function(x) {
    vapply(x, function(xi) {
      full <- floor(min(xi, top + 1))
      h <- sum(mu[d$age < full])
      if (xi <= top + 1) h + (xi - full) * mu[d$age == min(full, top)]
      else h + (xi - top - 1) * mu[d$age == top]
    }, numeric(1))
  }
  exp(-(cum_h(a) - cum_h(a0)))
}

# Per-cycle probability of background death for a cohort entering at
# age_start with a given female share. The sex mix shifts as the cohort ages
# (men die sooner), so the probability is taken from the mixed survival curve
# rather than a fixed-weight average of male and female qx.
background_mortality <- function(lt, age_start, prop_female, n_cycles,
                                 cycle_years = 1) {
  stopifnot(prop_female >= 0, prop_female <= 1)
  ages <- age_start + (0:n_cycles) * cycle_years
  if (max(ages) > max(lt$age) + 1) {
    warning("Horizon runs past age ", max(lt$age) + 1,
            "; the last life-table hazard is carried forward")
  }
  s <- prop_female * lt_survival(lt, "female", age_start, ages) +
    (1 - prop_female) * lt_survival(lt, "male", age_start, ages)
  p <- 1 - s[-1] / s[-length(s)]
  attr(p, "age") <- ages[-length(ages)]
  p
}

# Combine background and disease-specific death probabilities over the same
# cycle. "independent" sums the two hazards (use for excess or
# disease-specific mortality); "max" takes the larger (use when the disease
# figure is already all-cause, so background deaths are not counted twice).
combine_mortality <- function(p_background, p_disease,
                              method = c("independent", "max")) {
  method <- match.arg(method)
  stopifnot(all(p_background >= 0 & p_background <= 1),
            all(p_disease >= 0 & p_disease <= 1))
  if (method == "max") pmax(p_background, p_disease)
  else 1 - (1 - p_background) * (1 - p_disease)
}

# Expected life years from the life table over a horizon, for checking a
# model with disease switched off. Uses lx and ex directly (not qx), so it is
# independent of background_mortality(). Needs a whole-number start age and
# horizon in years; a horizon past the table end returns ex.
lt_life_years <- function(lt, age_start, prop_female, horizon_years) {
  stopifnot(age_start == round(age_start), horizon_years == round(horizon_years))
  one_sex <- function(sex) {
    d <- lt[lt$sex == sex, ]
    d <- d[order(d$age), ]
    if (age_start + horizon_years > max(d$age)) return(d$ex[d$age == age_start])
    l <- d$lx[d$age >= age_start & d$age <= age_start + horizon_years]
    sum((l[-1] + l[-length(l)]) / 2) / l[1]
  }
  prop_female * one_sex("female") + (1 - prop_female) * one_sex("male")
}
