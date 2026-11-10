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

setwd(repo)
unlink(tmp, recursive = TRUE)
cat("\nAll output checks passed.\n")
