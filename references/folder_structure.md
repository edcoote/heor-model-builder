# Folder structure

`scripts/scaffold.py <project_dir>` creates this layout. It never overwrites existing files, so it is safe to rerun on an existing project to add anything missing.

```
<project-name>/
├── model_spec.md            # the filled-in spec; source of design decisions
├── README.md                # what the model is and how to run it
├── run_all.R                # runs every script in order from a clean session
├── <project-name>.Rproj     # makes here::here() find the root
├── inputs/
│   ├── parameters.csv       # every model number; single source of truth
│   └── raw/                 # source data as received; never edited
│       ├── ons_life_tables_uk.csv        # ONS life tables (copied from the skill)
│       └── ons_life_tables_uk_source.md  # which ONS release it is
├── R/
│   ├── 00_packages.R
│   ├── 01_load_inputs.R
│   ├── 02_model_structure.R
│   ├── 03_run_deterministic.R
│   ├── 03b_hand_check.R     # cycles 1–2 printed for a hand check
│   ├── 04_dsa.R
│   ├── 05_psa.R
│   ├── 06_outputs.R         # rebuilds every figure and table from saved results
│   ├── 07_budget_impact.R   # only if the module is on
│   ├── 08_dcea.R            # only if the module is on
│   ├── utils_conversions.R  # conversions, discounting, PSA fitting (copied from the skill)
│   ├── utils_outputs.R      # house style helpers (copied from the skill)
│   └── utils_tests.R        # sanity tests (copied from the skill)
├── outputs/
│   ├── figures/             # fig_*.tiff / .pdf / .png
│   ├── tables/              # tab_*.docx / .csv
│   └── results/             # *.rds model results and PSA draws
├── manuscript/
│   ├── tables.docx          # all tables compiled
│   ├── figure_legends.md
│   ├── methods_draft.md
│   └── cheers_2022.md
└── log/
    ├── run_log.md           # dated assumptions, defaults, decisions, checkpoints
    └── review_checklist.md  # human checks, ticked and signed at each checkpoint
```

## What goes where

- A new data file from the user goes in `inputs/raw/` unchanged; any cleaning happens in `01_load_inputs.R`.
- A number used by the model goes in `parameters.csv`, never in a script.
- Anything a script produces goes in `outputs/`; anything meant for the paper ends up in `manuscript/`.
- Names: lowercase, underscores, no spaces or dates in file names (versions live in git and the log).
