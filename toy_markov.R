# toy_markov.R — a small 3-state Markov model (Well, Sick, Dead) used to test
# the toolkit. It also shows the structure the skill expects in a project:
# parameters in a named list, a run_model() function that returns total
# costs and QALYs per strategy, and a trace for the tests.

toy_params <- list(
  n_cycles = 40, cycle_years = 1,
  p_ws = 0.10, p_wd = 0.02, p_sd = 0.15,   # per-cycle probabilities
  hr_treat = 0.7,                          # HR on Well -> Sick with treatment
  c_well = 100, c_sick = 2000, c_treat = 500,
  u_well = 0.85, u_sick = 0.55,
  disc_cost = 0.035, disc_qaly = 0.035
)

toy_matrix <- function(p, treat = FALSE) {
  p_ws <- if (treat) apply_hr(p$p_ws, p$hr_treat) else p$p_ws
  matrix(c(1 - p_ws - p$p_wd, p_ws,         p$p_wd,
           0,                 1 - p$p_sd,   p$p_sd,
           0,                 0,            1),
         nrow = 3, byrow = TRUE,
         dimnames = list(c("Well", "Sick", "Dead"), c("Well", "Sick", "Dead")))
}

toy_trace <- function(P, n_cycles) {
  tr <- matrix(0, n_cycles + 1, ncol(P), dimnames = list(NULL, colnames(P)))
  tr[1, ] <- c(1, 0, 0)
  for (t in seq_len(n_cycles)) tr[t + 1, ] <- tr[t, ] %*% P
  tr
}

# Returns list(cost = c(soc, treat), qaly = c(soc, treat), traces = list(...))
run_toy <- function(p) {
  out <- list(cost = numeric(2), qaly = numeric(2), traces = list())
  for (k in 1:2) {
    treat <- k == 2
    tr <- toy_trace(toy_matrix(p, treat), p$n_cycles)
    hc <- half_cycle_lifetable(tr)                         # n_cycles rows
    t_mid <- (seq_len(p$n_cycles) - 0.5) * p$cycle_years   # cycle midpoints
    c_state <- c(p$c_well + if (treat) p$c_treat else 0, p$c_sick, 0)
    u_state <- c(p$u_well, p$u_sick, 0) * p$cycle_years
    out$cost[k] <- sum(hc %*% c_state * discount_factor(t_mid, p$disc_cost))
    out$qaly[k] <- sum(hc %*% u_state * discount_factor(t_mid, p$disc_qaly))
    out$traces[[k]] <- tr
  }
  out
}
