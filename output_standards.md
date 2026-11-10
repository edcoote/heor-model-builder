# Output standards

Every figure and table goes through `R/utils_outputs.R`. These rules explain what the helpers do, so you can follow them for anything the helpers don't cover.

## Figures

| Item | Standard |
|---|---|
| Size | Single column 85 mm wide, double column 170 mm. Height to suit, max 225 mm. Use the target journal's widths if the spec names them. |
| Formats | TIFF (LZW, 300 dpi; 600 dpi for pure line art), PDF (vector), PNG (300 dpi, for preview and slides). `save_fig()` writes all three. |
| Font | Arial / Helvetica, 8–9 pt for axis text, 9–10 pt for axis titles. Never below 7 pt at final size. |
| Colour | Okabe–Ito palette (`heor_cols`), which is colour-blind safe. If the journal prints in greyscale, use linetype and shape as well as colour. |
| Titles | None on the figure. The title and full explanation go in `manuscript/figure_legends.md`. |
| Axes | Units in brackets: "Incremental cost (£)", "Incremental QALYs", "Willingness to pay (£ per QALY)". Currency axes use thousands separators. |
| Gridlines | Light major gridlines only; no minor gridlines; no grey panel background. |
| Legends | Below the plot, no legend title unless needed. |
| Labels | Strategy names exactly as in the spec, in the same order on every figure. |

Standard figures and their helpers:

| File stem | Helper | Notes |
|---|---|---|
| `fig_model_structure` | Mermaid or DiagrammeR | States as boxes, absorbing states marked, arrows for allowed transitions only |
| `fig_markov_trace` | `plot_trace()` | One panel per strategy |
| `fig_ce_plane` | `plot_ce_plane()` | PSA cloud, mean point, dashed WTP line(s) through origin |
| `fig_ceac` | `plot_ceac()` | Add CEAF if 3+ strategies |
| `fig_tornado` | `plot_tornado()` | Ordered by range, vertical line at base case, low/high input values distinguished |
| `fig_budget_impact` | ggplot bars | Annual incremental budget, with cumulative in the table |

## Tables

| Item | Standard |
|---|---|
| Formats | `.docx` (flextable, booktabs style, Arial 9 pt) and `.csv`. `save_table()` writes both. `compile_tables()` merges all tables into `manuscript/tables.docx`. |
| Title | "Table N. Description" as the caption; numbering in order of mention. |
| Footnotes | Spell out every abbreviation used in the table, plus price year and discount rate for cost results. |
| Costs | `fmt_gbp()`: £ with thousands separator, whole pounds for totals and ICERs; pence only for unit costs under £10. |
| QALYs, life years | 3 decimal places for incremental values, 2 for totals. |
| Probabilities, utilities | 3 decimal places. |
| Uncertainty | 95% credible intervals from PSA as 2.5th and 97.5th percentiles, in brackets after the mean. |
| ICERs | `icer_label()`: "Dominant", "Dominated", or £ value; flag south-west quadrant ICERs. Never report a negative ICER as a number. |
| Order | Strategies in ascending cost order in incremental results, as is standard for fully incremental analysis. |

Standard tables:

| File stem | Content |
|---|---|
| `tab_inputs` | Every parameter: description, base value, range, distribution, source. Generated from `inputs/parameters.csv`. |
| `tab_base_case` | Total costs, QALYs (and LYs), incremental costs and QALYs, ICER, NMB at each threshold |
| `tab_dsa` | Low/high result per parameter (supports the tornado) |
| `tab_scenarios` | One row per scenario: change made, incremental cost, incremental QALYs, ICER |
| `tab_budget_impact` | By year: population, uptake, cost with and without, incremental, cumulative |
| `tab_dcea` | NHB by equity group and inequality measures |
