# Bundled ONS life tables

`assets/ons_life_tables_uk.csv` is made by `scripts/prepare_ons.R`. Do not edit it by hand.

| Field | Value |
|---|---|
| Workbook | Single-Year Life Tables, United Kingdom, 1980 to 2024 |
| Sheet (period) | 2024 |
| Published by ONS | 10 December 2025 |
| Ages | 0 to 100 by single year, males and females |
| Prepared | 2026-11-10 |

Columns: `mx` central death rate; `qx` probability of death between exact age x and x + 1;
`lx` survivors to exact age x per 100,000 births; `dx` deaths between x and x + 1;
`ex` period life expectancy at exact age x.

To update for a new release: download the UK workbook from the ONS website, then run
`Rscript scripts/prepare_ons.R <workbook.xlsx>` from the repository root, rerun the tests,
and repackage the skill. Contains public sector information licensed under the Open
Government Licence v3.0.
