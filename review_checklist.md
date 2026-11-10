# Human review checklist

Claude runs the automatic tests in `R/utils_tests.R`. Those tests find code errors. They do not find a wrong model. A person must do the checks below at each checkpoint. The scaffold copies this file to `log/review_checklist.md` in each project. Tick each item, write the result, and add the date and your initials. Claude must not continue to the next stage until the reviewer signs the checkpoint.

The checks follow the TECH-VER checklist (Büyükkaramikli et al., 2019) and AdViSHE (Vemer et al., 2016). Use those papers for a full validation report.

---

## Checkpoint 1: structure and inputs

### Face validity (ask a clinician if you can)
- [ ] The health states agree with the clinical pathway. No important event is missing.
- [ ] Each allowed transition can occur in real life. No transition is possible that cannot occur.
- [ ] Death is absorbing. Each state can go to death.
- [ ] The cycle length is shorter than the time between the most frequent events.
- [ ] The time horizon is long enough to show all differences in costs and outcomes.

### Inputs
- [ ] Each value in `parameters.csv` agrees with its source. Check 5 values against the source paper, chosen at random.
- [ ] Each value has the correct time unit (per year, per month, per cycle).
- [ ] Each value has the correct type (probability, rate, HR, OR, RR).
- [ ] All costs use the same currency and price year.
- [ ] Utilities are in the correct order: a worse state has a lower utility.
- [ ] Each low/high range contains the base value.
- [ ] Each PSA distribution agrees with the type of parameter (beta for probabilities, gamma for costs, lognormal for ratios).

Sign-off: ________ Date: ________

---

## Checkpoint 2: deterministic base case

### Rationality checks (do the results make sense?)
- [ ] Look at the Markov trace plot. The curves have a sensible shape. No state increases when it must decrease.
- [ ] Undiscounted life expectancy agrees with ONS life tables for the start age, after you remove the effect of the disease.
- [ ] Total costs per patient are in a sensible range for this disease and setting.
- [ ] The direction of the result agrees with your expectation. If the result is "dominant" or "dominated", find the cause.
- [ ] Compare the results with a published model of the same disease. Explain large differences.

### Quick tests that the calculations are correct
Do these tests. Each has a known answer. Change one input, run the model, and compare. Then set the input back.

| Test | Change | Correct result |
|---|---|---|
| Hand calculation | Copy cycle 1 and cycle 2 of one arm into Excel. Calculate the trace, costs and QALYs by hand. | Same values as R |
| No treatment effect | Make both arms identical (HR = 1, treatment cost = 0) | Incremental cost and QALYs = 0 |
| Perfect health | All utilities = 1, discount = 0 | QALYs = life years |
| No costs | All costs = 0 | Total cost = 0 |
| No discount | Discount rates = 0 | Totals equal the undiscounted totals |
| Immediate death | Probability of death = 1 from the start state | QALYs = half a cycle of the start state (life-table method) |
| No death | All death probabilities = 0 | Cohort stays alive for the full horizon |
| Double a cost | Multiply one cost by 2 | Total cost increases by the discounted total of that cost item, no more and no less |
| Better treatment | Make the treatment effect stronger | QALYs increase in the treatment arm |
| Longer horizon | Increase the horizon | Life years do not decrease |
| Conversion | Take one converted probability | `1 - exp(-rate × cycle)` gives the value in the model |

Sign-off: ________ Date: ________

---

## Checkpoint 3: uncertainty and scenarios

- [ ] PSA mean costs and QALYs are near the deterministic results (within about 5%). If not, find the non-linear parameter.
- [ ] Run the PSA two times with the same seed. The results are identical.
- [ ] Plot the running mean of incremental NMB against iteration number. The line is flat before the last iteration. If not, increase the number of iterations.
- [ ] Look at histograms of 3 sampled parameters. The draws stay inside their possible range (0–1 for probabilities, ≥ 0 for costs).
- [ ] The CEAC values are between 0 and 1. At each WTP, the values for all strategies add up to 1.
- [ ] The CE plane cloud is around the deterministic point.
- [ ] The parameters at the top of the tornado diagram are the parameters you expect to be important.
- [ ] Each scenario result moves in the expected direction (e.g. a higher discount rate gives a smaller QALY gain).

Sign-off: ________ Date: ________

---

## Stage 4: manuscript pack

- [ ] Each number in the tables agrees with the saved results in `outputs/results/`. Check 5 numbers, chosen at random.
- [ ] Each figure has a legend in `manuscript/figure_legends.md`.
- [ ] Each abbreviation is spelt out in a table footnote or legend.
- [ ] The methods text agrees with `model_spec.md` and `log/run_log.md`.
- [ ] Each CHEERS 2022 item has a section or "not applicable".
- [ ] `run_all.R` reproduces all results from a clean R session.

Sign-off: ________ Date: ________
