---
name: heor-model-builder
description: Build health economic (HEOR) models in R from a filled-in model spec — cost-effectiveness and cost-utility models (decision tree, Markov cohort, partitioned survival), budget impact models, and distributional cost-effectiveness analysis (DCEA) — inside a fixed project folder, with staged review checkpoints and manuscript-ready figures and tables. Use this skill whenever the user asks to build, draft, extend, debug or rerun a CEA, CUA, BIA, DCEA, Markov model, decision model, PSA, DSA, CEAC, CE plane, tornado diagram or ICER table, or mentions a model spec, even if they don't name this skill.
---

# HEOR model builder

This skill turns a filled-in model spec into a working R model, with outputs a journal will accept, in as few rounds as possible. Three problems it exists to remove:

1. **Back and forth on design.** Every design decision lives in `model_spec.md`. Read it, list every gap in one message, and only then build.
2. **Lost files and broken paths.** Every project uses the same folder scaffold and `here::here()` relative paths. Nothing is saved anywhere else.
3. **Outputs that aren't manuscript ready.** Every figure and table goes through the helpers in `R/utils_outputs.R`, which apply the house style in `references/output_standards.md`.

## Workflow

Follow these stages in order. Stop at each checkpoint and wait for the user's sign-off, because rework after the PSA is expensive and most errors are cheaper to catch at the structure stage.

Automatic tests find code errors; they cannot tell whether the model is right. So at every checkpoint, point the user to the matching section of `log/review_checklist.md` (copied from `references/review_checklist.md`), and offer to run any of its known-answer tests for them. Record the user's sign-off, with the date, in `log/run_log.md`. Do not start the next stage without it, even if all automatic tests pass.

### Stage 0 — Spec

1. Look for `model_spec.md` in the project folder or among the user's files.
2. If there is none, copy `assets/model_spec_template.md` into the project as `model_spec.md`, and copy `assets/model_spec_form.html` into the project root. Ask the user to fill in the spec. The easiest way is to open `model_spec_form.html` in a browser, fill it in, and export `model_spec.md` (and `parameters.csv` if they used the parameter table) into the project folder. The form works offline and can also open an existing `model_spec.md` to edit it. Editing `model_spec.md` directly also works. If they would rather answer in chat, ask for the **required** fields only, all in one message. If the form exported a `parameters.csv`, move it to `inputs/parameters.csv` and use it as the starting point for Stage 1.
3. Validate the spec against `references/methods_checklist.md` (section "Spec validation"). Then send **one** message that lists:
   - missing required fields,
   - internal inconsistencies (e.g. lifetime horizon with a 1-year cycle and no age-dependent mortality; probabilities given where rates are needed),
   - the defaults you propose for anything optional left blank, labelled as defaults.
   Never fill a required field silently. Never drip-feed questions across several turns.
4. **Background mortality.** For a UK setting with background mortality left blank, the default is the ONS life table bundled with the skill (`assets/ons_life_tables_uk.csv`; its period and publication date are in `assets/ons_life_tables_uk_source.md`). State that period and date in the Stage 0 message, and flag it if ONS published it more than two years before today, so the user can refresh it with `scripts/prepare_ons.R`. Age at entry and sex mix become required. For a non-UK setting, ask for a national life table in the same format. Only use constant background mortality if the user asks for it, and log it as a deviation.

### Stage 1 — Scaffold and structure → CHECKPOINT 1

1. Create the project with `python scripts/scaffold.py <project_dir>` (it is safe to rerun; it never overwrites existing files). Folder layout is in `references/folder_structure.md`. The scaffold copies the ONS life table into `inputs/raw/`. If Python is not available, create the same layout and starter files by hand, following `scripts/scaffold.py` exactly, never overwriting a file, and log that the script was not run.
2. Write `inputs/parameters.csv` from the spec. It is the single source of truth for every number in the model: no hard-coded values in R scripts.
3. Write `R/02_model_structure.R` (states, transitions, conversion of ORs/RRs/hazards/rates to per-cycle probabilities as set out in `references/methods_checklist.md`). Use the functions in `R/utils_conversions.R` for every conversion, discount factor, half-cycle correction and PSA distribution fit, rather than writing the formulas again. For background mortality, read the life table with `read_life_table()`, get per-cycle probabilities with `background_mortality()`, and combine them with disease mortality using `combine_mortality()`. Because these probabilities change with age, the transition matrix becomes an array (states × states × cycles).
4. Produce the model diagram (`outputs/figures/fig_model_structure`) and the inputs table (`outputs/tables/tab_inputs`).
5. **Checkpoint 1:** show the diagram, the inputs table, and a one-paragraph summary of structural assumptions. Wait for approval.

### Stage 2 — Deterministic base case → CHECKPOINT 2

1. Write `R/03_run_deterministic.R`. Save results as `.rds` in `outputs/results/`.
2. Run every applicable test in `R/utils_tests.R`. All must pass before you report results; if one fails, fix the cause, don't loosen the test. When the model uses a life table, include `test_life_expectancy()`: run the model with the disease switched off, utility 1 and no discounting, and compare its life years with the table.
3. Write `R/03b_hand_check.R`, which prints cycles 1 and 2 of the trace, costs and QALYs for one arm in a plain table, so the user can rebuild them by hand in Excel.
4. **Checkpoint 2:** show the base case results table, the Markov trace (if Markov), the test summary and the hand-check table. Wait for approval.

### Stage 3 — Uncertainty and scenarios → CHECKPOINT 3

1. DSA (`R/04_dsa.R`): one-way analysis on the parameters flagged in the spec, using the low/high columns of `parameters.csv`. Tornado diagram on the outcome the spec names (ICER or NMB; prefer NMB when ICERs cross quadrants).
2. PSA (`R/05_psa.R`): distributions from `parameters.csv`, `set.seed()` from the spec, number of iterations from the spec. Check that PSA means are close to the deterministic results and report any gap.
3. Scenario analyses listed in the spec.
4. Budget impact and DCEA modules only if switched on in the spec (see `references/methods_checklist.md`).
5. **Checkpoint 3:** show the CE plane, CEAC, tornado and scenario table.

### Stage 4 — Manuscript pack

1. `R/06_outputs.R` regenerates every figure and table from saved results, so outputs can be rebuilt without rerunning the model.
2. Compile all tables into `manuscript/tables.docx` with `compile_tables()`.
3. Write `manuscript/figure_legends.md` (one legend per figure, abbreviations spelt out). Put `<!-- fig_<stem> -->` on the line above each legend, so the HTML report can match legends to figures. Start the file at Stage 1 and add each legend when its figure is first made.
4. Write `manuscript/methods_draft.md` covering every CHEERS 2022 methods item the model touches, and `manuscript/cheers_2022.md` mapping each item to a section or "not applicable".
5. Build the HTML report at the end of `R/06_outputs.R` with `build_report()` from `R/utils_outputs.R`. It writes `outputs/report.html`, one self-contained file to share with co-authors or clients. Pass:
   - `headline`: the key results as short strings: the ICER (or "Dominant"), incremental QALYs and costs, INMB and the probability of being cost-effective at each threshold;
   - `sections`: the figures and tables in reading order: model, inputs, base case, DSA, scenarios, PSA, then a data frame of the automatic test results;
   - a `subtitle` that names the comparison, perspective and horizon.

   The report adds the spec and the decision log itself. Compute headline numbers from the saved `.rds` files, not by rerunning the model. You can also build an interim report at Checkpoints 2 and 3 if the user wants something to share.
6. Make sure `run_all.R` reproduces everything from a clean session.

## Rules that apply throughout

- **Paths:** use `here::here()` for every read and write. No absolute paths, no `setwd()`, no files saved outside the scaffold. If the user asks where something is, give the path relative to the project root.
- **Logging:** append every assumption, default, deviation from the spec and checkpoint decision to `log/run_log.md` with the date. This is how a later session picks up where the last one stopped, so read it first when resuming.
- **Resuming:** when the user returns to an existing project, read `model_spec.md` and `log/run_log.md` before doing anything else, and say which stage the project is at.
- **Spec changes:** if the user changes a design decision mid-build, update `model_spec.md` first, log it, then change the code.
- **Code style:** one script per stage as numbered in the scaffold; tidyverse style; functions for anything run more than once; comments explain *why*, not *what*. Hand-code Markov models with matrices (transparent, easy to audit) unless the spec names a package.
- **Outputs:** never call `ggsave()` or write a table directly. Use `save_fig()` and `save_table()` from `R/utils_outputs.R`, which apply the house style and save every format needed. Figures carry no titles; the title goes in the legend.
- **Honesty about results:** report surprising results (dominance, negative QALY gains, ICERs far from expectation) plainly at the checkpoint with the likely driver, rather than tuning inputs.

## Reference files

- `references/methods_checklist.md` — spec validation list, NICE reference case defaults, probability conversions, PSA distribution choice, half-cycle correction, BIA and DCEA modules. Read at Stage 0 and whenever building transitions or the PSA.
- `references/output_standards.md` — figure and table house style. Read before producing any output.
- `references/folder_structure.md` — the scaffold and what goes where.
- `assets/model_spec_template.md` — the fill-out spec.
- `assets/model_spec_form.html` — a browser form for the spec, built from an embedded copy of the template. It exports `model_spec.md` and `parameters.csv`. After changing the template, run `Rscript scripts/build_spec_form.R` to re-embed it; `tests/test_toolkit.R` fails if they differ. Open the form with `?selftest` added to its address to run its round-trip self-test.
- `references/review_checklist.md` — the human checks for each checkpoint: face validity, rationality checks and known-answer tests. Copied into each project's `log/` folder.
- `assets/utils_conversions.R`, `assets/utils_outputs.R`, `assets/utils_tests.R` — copied into each project's `R/` folder by the scaffold script.
- `assets/ons_life_tables_uk.csv` and `assets/ons_life_tables_uk_source.md` — ONS UK life tables by single year of age and sex, with their release details. Copied into each project's `inputs/raw/` folder by the scaffold script. `scripts/prepare_ons.R` rebuilds them from a new ONS workbook.
- `tests/toy_markov.R` — a small, worked 3-state Markov model. Use it as the pattern for `run_model()` (named parameter list in, total costs and QALYs per strategy out), because the tests in `utils_tests.R` expect that shape.
