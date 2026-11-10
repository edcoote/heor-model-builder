# heor-model-builder

A Claude skill that builds health economic models in R from a filled-in model specification. It covers cost-effectiveness and cost-utility models (decision tree, Markov cohort, partitioned survival), budget impact models and distributional cost-effectiveness analysis (DCEA).

The skill has three aims:

1. Fewer questions and answers before the first draft. All design decisions go in one spec file.
2. No lost files. Each project uses the same folders and relative paths.
3. Manuscript-ready outputs. All figures and tables use one house style.

## Quick start: build a new model

### One-time setup

1. Install the skill in Claude: **Settings → Capabilities → Skills**, then upload `heor-model-builder.skill`. See [Use the skill in Claude](#use-the-skill-in-claude).
2. Install R 4.1 or later. Add its `bin` folder to your PATH (for example `C:\Program Files\R\R-4.6.1\bin`).
3. Optional: install Python 3 and tick "Add to PATH". The skill then makes the project folders with `scripts/scaffold.py`. Without Python, Claude makes the same folders by hand.

### Each new model

1. **Make a folder for the model.** Use lowercase and hyphens, for example `Documents/HEOR/ckd-sglt2-cua`.
2. **Start a new Claude Code session in that folder.** Choose the folder when you open the session. Without a folder, the work goes into a temporary folder that is deleted with the session.
3. **Get the spec template.** Type:

   ```
   /anthropic-skills:heor-model-builder new model
   ```

   Claude puts a blank `model_spec.md` and the spec form `model_spec_form.html` in the folder. If you already have a filled-in spec, save it in the folder and go to step 5.
4. **Fill in the spec.** Double-click `model_spec_form.html` to open it in your browser. Fill in every field marked **Required**, add your parameters (you can paste them from Excel), then click **Export model_spec.md**, and **Export parameters.csv** if you entered parameters. Save both into the model folder. The form works offline, saves a draft as you go, and can open an existing `model_spec.md` to edit it. For UK models, give the age at entry and the % female, because the ONS life tables need them. Leave background mortality blank to use the bundled ONS tables. You can also edit `model_spec.md` directly instead.
5. **Tell Claude the spec is ready.** Type `spec is done`. Put any data files (for example a parameters spreadsheet) in the folder first, and name them in your message.
6. **Answer the Stage 0 message once.** Claude lists all the gaps and proposed defaults in one message. Reply to all of them in one message, for example "accept all defaults, but use a threshold of £30,000".
7. **Review and sign off each checkpoint.** Use the matching section of `log/review_checklist.md`. Then reply `signed off, continue`.

| Checkpoint | Claude shows | You check |
|---|---|---|
| 1. Structure | Model diagram, inputs table | Input values against their sources, units, face validity |
| 2. Base case | Results table, Markov trace, test summary, hand-check table | Rebuild cycles 1–2 in Excel; results make sense |
| 3. Uncertainty | CE plane, CEAC, tornado, scenarios | Distributions, directions, PSA close to deterministic |
| 4. Manuscript | Tables in Word, figure legends, methods draft, CHEERS 2022 map, HTML report | Tables agree with results |

8. **Share the results.** Send `outputs/report.html` to co-authors or clients. It is one file that opens in any browser and contains:
   - summary cards;
   - every figure and table, with the tables sortable;
   - the model spec;
   - the decision log, with the dated assumptions and sign-offs.

### Coming back later

Open a new session in the same folder and type:

```
/anthropic-skills:heor-model-builder resume
```

Claude reads `model_spec.md` and `log/run_log.md` and tells you which stage the model is at.

Tip: keep each model folder in git or OneDrive, so every version is saved.

## How it works

1. You fill in `assets/model_spec_template.md` for a new model.
2. Claude reads the spec. Claude lists all gaps and problems in one message.
3. `scripts/scaffold.py` makes the project folders and copies the helper files.
4. Claude builds the model in 4 stages. Claude stops at 3 checkpoints for your review.
5. You do the human checks in `log/review_checklist.md` and sign each checkpoint.

| Stage | Claude makes | You check (checkpoint) |
|---|---|---|
| 1. Structure | Model diagram, `parameters.csv`, inputs table | Face validity, input values and units |
| 2. Base case | Deterministic results, Markov trace, automatic tests, hand-check table | Rationality checks and known-answer tests |
| 3. Uncertainty | DSA tornado, PSA, CE plane, CEAC, scenarios | PSA convergence, distributions, directions |
| 4. Manuscript | Compiled tables, figure legends, methods draft, CHEERS 2022 map | Tables agree with results; run_all.R reproduces |

All model numbers are in one file, `inputs/parameters.csv`. The R scripts read this file one time and use the values by name. No script contains a hard-coded value.

## Repository layout

```
SKILL.md                     Instructions that Claude follows
assets/
  model_spec_template.md     The spec you fill in for each model
  model_spec_form.html       Browser form for the spec; exports model_spec.md and parameters.csv
  utils_conversions.R        Rate/probability/HR/OR/RR conversions, discounting,
                             half-cycle correction, PSA distribution fitting,
                             background mortality from life tables
  utils_outputs.R            Figure and table house style, standard plots, HTML report
  utils_tests.R              Automatic sanity tests
  ons_life_tables_uk.csv     ONS UK life tables by single year of age and sex
  ons_life_tables_uk_source.md  Which ONS release the CSV comes from
references/
  methods_checklist.md       Spec validation, reference case, conversions, PSA, BIA, DCEA
  output_standards.md        Figure and table rules
  folder_structure.md        Project folder layout
  review_checklist.md        Human checks for each checkpoint
scripts/
  scaffold.py                Makes a new project folder
  prepare_ons.R              Rebuilds the ONS life table CSV from an ONS workbook
  build_spec_form.R          Re-embeds the template in the spec form after a template change
tests/
  toy_markov.R               Small worked 3-state Markov model
  test_toolkit.R             Known-answer tests for the R helpers
  test_outputs.R             Tests that figures and tables are written
```

## Use the skill in Claude

Add the packaged `heor-model-builder.skill` file to Claude as a custom skill. Then ask Claude to build a model, and give it your filled-in spec.

To make a new project without Claude:

```
python scripts/scaffold.py path/to/my-model
python scripts/scaffold.py path/to/my-model --budget-impact --dcea
```

The script does not overwrite files. You can run it again on a project to add missing folders.

## Background mortality (ONS life tables)

The skill ships ONS UK life tables in `assets/ons_life_tables_uk.csv`. The scaffold copies them into each project's `inputs/raw/`. UK models use them for background mortality by default. `assets/ons_life_tables_uk_source.md` records which ONS release they come from.

To update for a new ONS release, download the UK life tables workbook from the ONS website. Then run the following from the repository root, and rerun the tests:

```
Rscript scripts/prepare_ons.R path/to/workbook.xlsx
```

The script reads both ONS formats: national life tables (3-year periods) and single-year life tables. It uses the latest period unless you name a sheet as a second argument. It needs the readxl package.

## Run the tests

Do these from the repository root. You need R 4.1 or later.

```
Rscript tests/test_toolkit.R
Rscript tests/test_outputs.R
```

`test_toolkit.R` needs base R only. `test_outputs.R` needs ggplot2, dplyr, scales, here, flextable and officer. Run the tests after each change to a file in `assets/`.

## Status

- Version 0.3: adds the browser spec form (model_spec_form.html) and the self-contained HTML report (build_report()). Version 0.2 added ONS life tables for background mortality.
- Tested: the R helpers (51 known-answer checks, including background mortality against ONS life expectancy and the form/template match), the figure, table and report output, and the spec form round trip (its self-test, and loading a filled spec written for an older template).
- A demo model (the 3-state toy model) has been built by Claude through Stage 3, with an HTML report.
- Not tested yet: the scaffold script's steps that copy the life table and the spec form (written without Python available), and a full model built from a real spec. Do both before you use the skill for a submission.

## References

- Husereau D, et al. CHEERS 2022. Value Health 2022.
- Büyükkaramikli NC, et al. TECH-VER: a verification checklist to reduce errors in models. PharmacoEconomics 2019.
- Vemer P, et al. AdViSHE: a validation-assessment tool of health-economic models. PharmacoEconomics 2016.
- NICE health technology evaluations: the manual (PMG36).
- Sullivan SD, et al. Budget impact analysis: principles of good practice. Value Health 2014.
