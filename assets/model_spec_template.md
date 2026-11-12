# Model specification

Fill in every field marked **[R]** (required). Fields marked [O] are optional; leave blank to accept the default shown, and Claude will list the defaults it used before building. Tick options with `[x]`.

---

## 1. Project

| Field | Entry |
|---|---|
| **[R]** Project name (used as folder name, lowercase-hyphens) | |
| **[R]** One-line decision problem | |
| **[R]** Purpose | [ ] Journal manuscript [ ] HTA / payer submission [ ] Internal decision [ ] Conference |
| [O] Target journal (sets figure widths, word and figure limits) | |
| [O] Figure limit / table limit / word limit | |
| [O] Deadline | |

## 2. Decision problem (PICO)

| Field | Entry |
|---|---|
| **[R]** Population (age at entry, sex mix as % female, key characteristics; age and sex mix drive background mortality) | |
| **[R]** Intervention | |
| **[R]** Comparator(s) | |
| **[R]** Setting / country | |
| [O] Subgroups to report separately | |

## 3. Evaluation type and reference case

| Field | Entry |
|---|---|
| **[R]** Evaluation type | [ ] CUA (QALYs) [ ] CEA (natural units: ______) [ ] CBA [ ] CCA [ ] Cost-minimisation |
| **[R]** Perspective | [ ] NHS & PSS [ ] Healthcare payer (non-UK: ______) [ ] Societal [ ] Patient / out-of-pocket [ ] Provider |
| **[R]** Time horizon | [ ] Lifetime [ ] Fixed: ____ years |
| [O] Discount rate, costs / outcomes (default 3.5% / 3.5%) | / |
| [O] Currency and price year (default GBP, latest year of inputs) | |
| [O] Inflation index (default NHSCII / PSSRU) | |
| [O] Willingness-to-pay threshold(s) (confirm the current NICE position) | |
| [O] Reference case to follow (default NICE) | [ ] NICE [ ] ISPOR-SMDM good practice [ ] Other: ______ |

## 4. Model structure

| Field | Entry |
|---|---|
| **[R]** Model type | [ ] Decision tree [ ] Markov cohort [ ] Decision tree + Markov [ ] Partitioned survival [ ] Microsimulation [ ] Discrete event simulation |
| **[R]** Disease transmission | [ ] Non-communicable (static model) [ ] Communicable (dynamic model needed: ______) |
| **[R]** Health states (list; mark absorbing states) | |
| **[R]** Allowed transitions (list "from → to", or attach a diagram) | |
| **[R]** Cycle length | [ ] 1 month [ ] 3 months [ ] 6 months [ ] 1 year [ ] Other: ______ |
| [O] Half-cycle correction (default: life-table method, applied to costs and QALYs) | [ ] Life-table [ ] Simpson's 1/3 [ ] None (justify): ______ |
| [O] Background mortality (default for UK: ONS life tables bundled with the skill, age- and sex-specific; non-UK: attach a national life table) | |
| [O] Tunnel states / time-dependent transitions | |
| [O] Treatment effect waning | |

## 5. Inputs

Fill one row per parameter, or attach a CSV with these columns. This becomes `inputs/parameters.csv`.

**[R]** Input form for transitions: tick each that appears below so Claude converts correctly.
[ ] Per-cycle probabilities [ ] Probabilities over a different period [ ] Rates [ ] Hazard ratios [ ] Odds ratios [ ] Relative risks [ ] Survival curves (KM / parametric)

| name | description | base | low | high | distribution | param_1 | param_2 | input_type | source | notes |
|---|---|---|---|---|---|---|---|---|---|---|
| p_example | Annual probability of X | 0.05 | 0.03 | 0.08 | beta | 50 | 950 | probability (1 yr) | Author 2024 | |

- `distribution`: beta, gamma, lognormal, normal, dirichlet, fixed. Leave blank and Claude will propose one from the parameter type.
- `low`/`high`: 95% CI where available; otherwise state the range rule in notes (e.g. ±20%).
- `input_type`: probability (period), rate, HR, OR, RR, cost, utility, disutility, count.

## 6. Costs and outcomes

| Field | Entry |
|---|---|
| **[R]** Cost categories included | |
| [O] One-off vs per-cycle costs (list each) | |
| **[R]** Utility source and instrument (e.g. EQ-5D-3L, UK tariff; mapped from OHIP-14) | |
| [O] Disutilities (adverse events, procedures) and their duration | |
| [O] Age-adjustment of utilities (default: yes, Ara & Brazier general population norms) | |

## 7. Analyses and uncertainty

| Field | Entry |
|---|---|
| **[R]** Primary outcome | [ ] ICER [ ] NMB at £____ [ ] Both |
| **[R]** Uncertainty analyses | [ ] One-way DSA [ ] Threshold analysis [ ] PSA [ ] Scenario analyses [ ] EVPI [ ] EVPPI |
| [O] PSA iterations (default 5,000) and seed (default 2026) | |
| [O] Parameters for DSA (default: all with low/high) | |
| [O] Scenario analyses (list each, one line each) | |
| [O] Threshold analysis (parameter to vary; target, e.g. ICER = £25,000) | |
| [O] EVPPI parameter groups (one group per line) | |
| [O] Structural uncertainty to test | |

## 8. Optional modules

**Budget impact** [ ] Include
| Field | Entry |
|---|---|
| Eligible population and source | |
| Uptake by year (Y1–Y5) | |
| Market shares with / without intervention | |
| Time horizon (default 5 years, undiscounted) | |
| Payer | |

**Distributional CEA** [ ] Include
| Field | Entry |
|---|---|
| Equity-relevant grouping (default IMD quintile) | |
| Baseline health distribution source (e.g. QALE by IMD quintile) | |
| Uptake / need by group | |
| Opportunity cost distribution source | |
| Inequality aversion parameters to report (Atkinson ε) | |
| Outputs | [ ] Equity-efficiency impact plane [ ] Health inequality impact [ ] Equity-weighted NHB |

## 9. Outputs wanted

[ ] Model structure diagram
[ ] Inputs table
[ ] Base case results table
[ ] Markov trace
[ ] CE plane
[ ] CEAC (and CEAF if 3+ strategies)
[ ] Tornado diagram
[ ] Scenario results table
[ ] Budget impact table and chart
[ ] DCEA outputs
[ ] Methods text draft
[ ] CHEERS 2022 checklist

[O] Anything special about figures (journal colour policy, greyscale only, font): ______

## 10. Notes for Claude

Anything else: data files to read, existing code to reuse, decisions already made with co-authors, things not to do.
