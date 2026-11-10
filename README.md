# heor-model-builder

A Claude skill that builds health economic models in R from a filled-in model specification. It covers cost-effectiveness and cost-utility models (decision tree, Markov cohort, partitioned survival), budget impact models and distributional cost-effectiveness analysis (DCEA).

The skill has three aims:

1. Fewer questions and answers before the first draft. All design decisions go in one spec file.
2. No lost files. Each project uses the same folders and relative paths.
3. Manuscript-ready outputs. All figures and tables use one house style.

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
  utils_conversions.R        Rate/probability/HR/OR/RR conversions, discounting,
                             half-cycle correction, PSA distribution fitting
  utils_outputs.R            Figure and table house style, standard plots
  utils_tests.R              Automatic sanity tests
references/
  methods_checklist.md       Spec validation, reference case, conversions, PSA, BIA, DCEA
  output_standards.md        Figure and table rules
  folder_structure.md        Project folder layout
  review_checklist.md        Human checks for each checkpoint
scripts/
  scaffold.py                Makes a new project folder
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

## Run the tests

Do these from the repository root. You need R 4.1 or later.

```
Rscript tests/test_toolkit.R
Rscript tests/test_outputs.R
```

`test_toolkit.R` needs base R only. `test_outputs.R` needs ggplot2, dplyr, scales, here, flextable and officer. Run the tests after each change to a file in `assets/`.

## Status

- Version 0.1.
- Tested: the R helpers (32 known-answer checks), the figure and table output, and the scaffold script.
- Not tested yet: a full model built by Claude from a real spec. Do this before you use the skill for a submission.

## References

- Husereau D, et al. CHEERS 2022. Value Health 2022.
- Büyükkaramikli NC, et al. TECH-VER: a verification checklist to reduce errors in models. PharmacoEconomics 2019.
- Vemer P, et al. AdViSHE: a validation-assessment tool of health-economic models. PharmacoEconomics 2016.
- NICE health technology evaluations: the manual (PMG36).
- Sullivan SD, et al. Budget impact analysis: principles of good practice. Value Health 2014.
