# test_outputs.R — checks the figure and table helpers write every file.
# Run from the repository root:  Rscript tests/test_outputs.R
# Writes into a temporary project folder, then deletes it.

repo <- normalizePath(".")
tmp <- file.path(tempdir(), "heor-output-test")
dir.create(tmp, showWarnings = FALSE)
invisible(file.create(file.path(tmp, ".here")))
setwd(tmp)  # here::here() finds the .here file and uses tmp as the root

suppressPackageStartupMessages(source(file.path(repo, "assets", "utils_outputs.R")))

check <- function(desc, ok) {
  if (!isTRUE(ok)) stop("FAILED: ", desc, call. = FALSE)
  cat("  pass:", desc, "\n")
}

cat("Formatting\n")
check("fmt_gbp thousands and minus", identical(fmt_gbp(c(12345.6, -500)), c("£12,346", "\u2212£500")))
check("icer_label quadrants", identical(
  icer_label(c(-10, 10, -10, 1000), c(0.1, -0.1, -0.1, 0.1)),
  c("Dominant", "Dominated", "£100 (SW quadrant)", "£10,000")))

cat("Figures\n")
set.seed(1)
psa <- data.frame(inc_cost = rnorm(500, 3000, 800), inc_qaly = rnorm(500, 0.2, 0.08))
ceac <- expand.grid(wtp = seq(0, 50000, 1000), strategy = c("SoC", "New"))
ceac$prob <- ifelse(ceac$strategy == "New", pnorm((ceac$wtp - 15000) / 8000), 1 - pnorm((ceac$wtp - 15000) / 8000))
dsa <- data.frame(parameter = c("Cost of sick state", "HR on progression", "Utility well"),
                  low = c(-2000, -500, 1000), high = c(4000, 2500, 1800))
trace <- expand.grid(cycle = 0:20, state = c("Well", "Sick", "Dead"), strategy = c("SoC", "New"))
trace$proportion <- runif(nrow(trace))
save_fig(plot_ce_plane(psa), "fig_ce_plane")
save_fig(plot_ceac(ceac), "fig_ceac")
save_fig(plot_tornado(dsa, base = 1500), "fig_tornado", width = "double")
save_fig(plot_trace(trace), "fig_markov_trace", width = "double")
for (f in c("fig_ce_plane", "fig_ceac", "fig_tornado", "fig_markov_trace"))
  for (ext in c("tiff", "pdf", "png"))
    check(paste0(f, ".", ext, " written"), file.exists(here::here("outputs", "figures", paste0(f, ".", ext))))

cat("Tables\n")
tab <- data.frame(Strategy = c("SoC", "New"), Cost = fmt_gbp(c(10000, 13000)),
                  QALYs = fmt_num(c(5.123, 5.323)), ICER = c("", icer_label(3000, 0.2)))
save_table(tab, "tab_base_case", "Table 2. Base case results",
           footnote = "QALY, quality-adjusted life year; ICER, incremental cost-effectiveness ratio.")
save_table(data.frame(a = 1), "tab_inputs", "Table 1. Inputs")
compile_tables(order = c("tab_inputs", "tab_base_case"))
check("tab_base_case.docx written", file.exists(here::here("outputs", "tables", "tab_base_case.docx")))
check("tab_base_case.csv written", file.exists(here::here("outputs", "tables", "tab_base_case.csv")))
check("manuscript/tables.docx compiled", file.exists(here::here("manuscript", "tables.docx")))
check("table title and footnote saved for the report",
      jsonlite::read_json(here::here("outputs", "tables", "tab_base_case.meta.json"))$title == "Table 2. Base case results")

cat("HTML report\n")
dir.create(here::here("log"), showWarnings = FALSE)
writeLines(c("# Run log", "", "## 2026-01-01 — Stage 1", "", "- Assumption: **constant** mortality.",
             "  - nested point", "", "| A | B |", "|---|---|", "| 1 | 2 |"),
           here::here("log", "run_log.md"))
writeLines(c("# Model specification", "", "| Field | Entry |", "|---|---|",
             "| **[R]** Purpose | [x] Journal manuscript [ ] Conference |"),
           here::here("model_spec.md"))
writeLines(c("# Figure legends", "", "<!-- fig_ce_plane -->",
             "**Figure 1. Cost-effectiveness plane.** Legend text."),
           here::here("manuscript", "figure_legends.md"))
tests_df <- data.frame(test = "Cohort conserved", pass = TRUE)
out <- build_report(
  title = "Test model", subtitle = "Subtitle <with> & characters",
  headline = c("ICER" = "£15,000 per QALY", "P(cost-effective) at £25,000" = "80%"),
  sections = list("Results" = list(report_text("Some **bold** text."), "tab_base_case", "fig_ce_plane"),
                  "Checks" = list(tests_df)))
html <- paste(readLines(out, encoding = "UTF-8", warn = FALSE), collapse = "\n")
check("report.html written", file.exists(here::here("outputs", "report.html")))
check("figure embedded as data URI", grepl("src=\"data:image/png;base64,", html, fixed = TRUE))
check("figure legend matched by marker", grepl("Figure 1. Cost-effectiveness plane.", html, fixed = TRUE))
check("table caption and footnote shown", grepl("Table 2. Base case results", html, fixed = TRUE) &&
        grepl("QALY, quality-adjusted life year", html, fixed = TRUE))
check("pound signs survive", grepl("£15,000 per QALY", html, fixed = TRUE) && grepl("£13,000", html, fixed = TRUE))
check("text is escaped", grepl("Subtitle &lt;with&gt; &amp; characters", html, fixed = TRUE))
check("headline cards shown", grepl("class=\"card\"", html, fixed = TRUE))
check("spec ticks rendered", grepl("☑ Journal manuscript", html, fixed = TRUE))
check("log rendered with nested list and table", grepl("<strong>constant</strong>", html, fixed = TRUE) &&
        grepl("<ul><li>", html, fixed = TRUE) && grepl("<td>2</td>", html, fixed = TRUE))
check("missing figure is an error", inherits(try(build_report(list(X = list("fig_none"))), silent = TRUE), "try-error"))

setwd(repo)
unlink(tmp, recursive = TRUE)
cat("\nAll output checks passed.\n")
