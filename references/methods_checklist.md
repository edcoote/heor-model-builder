# Methods checklist

## Contents
1. Spec validation
2. Reference case defaults
3. Converting transition inputs
4. Half-cycle correction and discounting
5. PSA distributions
6. Sanity tests
7. Budget impact module
8. DCEA module

---

## 1. Spec validation

Check every **[R]** field in `model_spec.md` is filled. Then check for these common inconsistencies and raise them all in one message:

- Horizon vs cycle length: a lifetime horizon needs enough cycles to run the cohort to (near) 100% dead, and age-dependent background mortality.
- Background mortality: age at entry and sex mix are stated, because the life table needs them. For the UK, the bundled ONS table is used unless the spec says otherwise; give its period and publication date, and flag it if ONS published it more than two years ago. Constant background mortality over a long horizon is an inconsistency to raise.
- Transition inputs: the form ticked in section 5 matches the `input_type` column; probabilities quoted over a period other than the cycle are flagged for conversion.
- Absorbing states: at least one (normally death); no transitions out of it.
- Perspective vs costs: societal perspective with only NHS costs, or NHS perspective with out-of-pocket costs.
- Utilities: instrument and value set stated; mapped utilities name the mapping algorithm.
- PSA: every non-fixed parameter has a distribution or enough information (mean + SE, CI, or counts) to fit one.
- Outcome: if ICERs are likely to cross quadrants (e.g. small QALY differences), suggest NMB as primary.
- Budget impact and DCEA modules: their fields are filled if the module is ticked.

## 2. Reference case defaults (NICE, unless the spec says otherwise)

| Item | Default |
|---|---|
| Perspective | NHS and PSS |
| Discount rate | 3.5% costs and outcomes; sensitivity at 1.5% if the spec allows |
| Horizon | Long enough to capture all differences in costs and outcomes (usually lifetime) |
| Outcome | QALYs from EQ-5D, UK value set (check NICE's current position on EQ-5D-5L valuation before using 5L data) |
| Threshold | Take from the spec; if blank, ask, and state the current NICE position as checked at the time |
| Prices | Latest NHS Reference Costs / National Cost Collection, PSSRU Unit Costs, BNF / eMIT |
| Background mortality | ONS life tables, age- and sex-specific: the table bundled as `assets/ons_life_tables_uk.csv` (release in `assets/ons_life_tables_uk_source.md`); refresh with `scripts/prepare_ons.R` |

Every default used goes in `log/run_log.md`.

## 3. Converting transition inputs

Let `c` be the cycle length in years.

| Input | Conversion to per-cycle probability |
|---|---|
| Rate `r` (per year) | `p = 1 - exp(-r * c)` |
| Probability `P` over `T` years | `r = -log(1 - P) / T`, then `p = 1 - exp(-r * c)` |
| Hazard ratio on baseline probability `p0` | `r1 = HR * (-log(1 - p0) / c)`, then `p1 = 1 - exp(-r1 * c)` (equivalently `1 - (1 - p0)^HR`) |
| Odds ratio on `p0` | `odds1 = OR * p0 / (1 - p0)`; `p1 = odds1 / (1 + odds1)`; convert period afterwards if `p0` is not per-cycle |
| Relative risk on `p0` | `p1 = RR * p0`; check `p1 <= 1`; if `p0` is large, convert to rates and apply as an approximate HR, and log it |
| Parametric survival `S(t)` | `p(t) = 1 - S(t) / S(t - c)` (time-dependent; build a transition array) |
| Life table `qx` by age and sex | `background_mortality(lt, age_start, prop_female, n_cycles, c)`: hazard `-log(1 - qx)` held constant within each year of age; cohort survival mixed by sex, so the female share rises as the cohort ages (time-dependent; build a transition array) |

Cautions:
- The rate–probability conversion is exact only when one event competes from a state. With several exits from one state, convert each to a rate, sum, and split the total probability in proportion to the rates; log it.
- Apply ORs and RRs at the period they were estimated over, then convert to the cycle.
- Combine disease-specific and background mortality as rates (sum, then convert), not by adding probabilities, and avoid double counting if the disease mortality source is all-cause. `combine_mortality(p_bg, p_disease, "independent")` sums the hazards, for excess or disease-specific mortality. `combine_mortality(..., "max")` takes the larger of the two, for an all-cause disease figure, so a state never has lower mortality than the general population.
- With a life table, the exits from a state change every cycle. Build the background-death column per cycle, then take the other exits from what remains: for example, Well → Sick = `p_ws * (1 - p_death)` when the source for `p_ws` is conditional on surviving. Log the choice.
- Never apply ORs or RRs to rates.

## 4. Half-cycle correction and discounting

- **Life-table method (default):** state membership per cycle = mean of the trace at the start and end of the cycle. Apply to per-cycle costs and QALYs, not to one-off transition costs.
- **Simpson's 1/3 rule:** weights 1, 4, 2, 4, …, 2, 4, 1 divided by 3; needs an even number of cycles.
- **Discounting:** discount factor `1 / (1 + d)^t`, with `t` in years at the cycle midpoint when using the life-table method. State the convention in the log, because it changes results slightly.
- One-off costs at time 0 are not discounted.

## 5. PSA distributions

| Parameter type | Distribution | Fitting from mean `m` and SE `s` |
|---|---|---|
| Probability, proportion | Beta | `alpha = m * (m * (1 - m) / s^2 - 1)`, `beta = alpha * (1 - m) / m`; or from counts: `alpha = events`, `beta = n - events` |
| Multinomial probabilities from one state | Dirichlet | counts per destination |
| Cost, resource use | Gamma | `shape = m^2 / s^2`, `scale = s^2 / m` |
| Utility (bounded, well above 0) | Beta | as for probabilities |
| Utility near or below 0, or disutility | Gamma or lognormal on `1 - u` (disutility) | as for costs |
| HR, OR, RR | Lognormal | `meanlog = log(m)`, `sdlog = (log(high) - log(low)) / (2 * 1.96)` |
| Correlated survival parameters | Multivariate normal | from the fitted model's variance–covariance matrix, via Cholesky |
| Unknown SE | Assume SE from the low/high range: `s = (high - low) / (2 * 1.96)`; if no range, assume `s = 0.1 * m` and log it |

Rules: use `set.seed()` from the spec; store every PSA draw in `outputs/results/psa_draws.rds`; check that sampled utilities keep the ordering the spec assumes (e.g. a worse state is never above a better state), and log how often it fails.

## 6. Sanity tests

`R/utils_tests.R` implements the tests below. Run them at Checkpoint 2 and after every PSA.

1. Transition matrix rows sum to 1 and all entries lie in [0, 1].
2. Trace rows sum to 1 (cohort is conserved) in every cycle.
3. Absorbing-state membership never decreases.
4. Running both arms with identical inputs gives zero incremental cost and QALYs.
5. Setting discount rates to 0 reproduces the undiscounted totals.
6. Raising a cost parameter never lowers total cost in the arm that uses it.
7. No utility above 1 in base case or PSA draws.
8. Undiscounted life years are plausible against life tables for the starting age. `test_life_expectancy()` checks this: with the disease switched off, model life years match the table (from `lx`, or `ex` when the horizon reaches the end of the table) to within 0.1 years.
9. PSA mean costs and QALYs are within about 5% of the deterministic values; if not, report it and name the likely non-linearity.

## 7. Budget impact module

Follow ISPOR budget impact good practice:
- Payer perspective, undiscounted, annual and cumulative results, horizon from the spec (default 5 years).
- Eligible population × uptake × market share, comparing the "world with" and "world without" the intervention.
- Report total and incremental budget per year, and per-patient cost.
- One-way sensitivity on uptake, population size and unit costs; scenario on price.
- Outputs: `tab_budget_impact`, `fig_budget_impact` (stacked or side-by-side bars by year).

## 8. DCEA module (aggregate DCEA)

1. Baseline distribution of health by equity group (default: QALE by IMD quintile).
2. Distribute health benefits by group using uptake and need inputs from the spec.
3. Distribute health opportunity costs by group (default: published NHS opportunity cost distribution by IMD).
4. Net health benefit by group; post-intervention health distribution.
5. Inequality measures: absolute and relative gap, slope index of inequality, Atkinson index across the ε values in the spec, and equally distributed equivalent (EDE) health.
6. Outputs: equity–efficiency impact plane, table of NHB by group, inequality aversion curve if ε values are given.
7. Run PSA through the DCEA so the impact plane shows uncertainty.
