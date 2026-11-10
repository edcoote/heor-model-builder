# utils_outputs.R — house style for manuscript-ready figures and tables
# Copied into each project by the heor-model-builder skill. Edit the
# settings block below if the target journal needs different sizes.

library(ggplot2)
library(dplyr)
library(flextable)
library(officer)
library(here)

# ---- Settings --------------------------------------------------------------

fig_widths_mm <- c(single = 85, double = 170)
fig_max_height_mm <- 225
fig_dpi <- 300
base_font <- "Arial"

# Okabe-Ito palette (colour-blind safe)
heor_cols <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7",
               "#E69F00", "#56B4E9", "#F0E442", "#000000")

# ---- Formatting ------------------------------------------------------------

fmt_gbp <- function(x, digits = 0) {
  out <- paste0("£", formatC(abs(x), format = "f", digits = digits, big.mark = ","))
  ifelse(is.na(x), NA_character_, ifelse(x < 0, paste0("\u2212", out), out))
}

fmt_num <- function(x, digits = 3) {
  out <- formatC(abs(x), format = "f", digits = digits, big.mark = ",")
  ifelse(is.na(x), NA_character_, ifelse(x < 0, paste0("\u2212", out), out))
}

# Mean with 95% interval, e.g. "£12,345 (£10,100 to £14,900)"
fmt_ci <- function(mean, low, high, fmt = fmt_gbp, ...) {
  paste0(fmt(mean, ...), " (", fmt(low, ...), " to ", fmt(high, ...), ")")
}

# ICER label that never reports a negative ICER as a number
icer_label <- function(inc_cost, inc_qaly) {
  dplyr::case_when(
    is.na(inc_cost) | is.na(inc_qaly) ~ NA_character_,
    inc_qaly >= 0 & inc_cost <= 0 ~ "Dominant",
    inc_qaly <= 0 & inc_cost >= 0 ~ "Dominated",
    inc_qaly < 0 & inc_cost < 0 ~ paste0(fmt_gbp(inc_cost / inc_qaly), " (SW quadrant)"),
    TRUE ~ fmt_gbp(inc_cost / inc_qaly)
  )
}

# ---- Theme and saving ------------------------------------------------------

theme_heor <- function(base_size = 9) {
  theme_minimal(base_size = base_size, base_family = base_font) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey90", linewidth = 0.3),
      axis.line = element_line(colour = "grey30", linewidth = 0.3),
      axis.ticks = element_line(colour = "grey30", linewidth = 0.3),
      axis.title = element_text(size = base_size + 1),
      legend.position = "bottom",
      legend.title = element_blank(),
      strip.text = element_text(face = "bold", hjust = 0),
      plot.title = element_blank(),
      plot.margin = margin(4, 6, 4, 4)
    )
}

# Saves TIFF, PDF and PNG to outputs/figures/<name>.*
save_fig <- function(plot, name, width = "single", height_mm = 70) {
  w <- if (is.numeric(width)) width else fig_widths_mm[[width]]
  h <- min(height_mm, fig_max_height_mm)
  dir <- here::here("outputs", "figures")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  ggsave(file.path(dir, paste0(name, ".tiff")), plot, width = w, height = h,
         units = "mm", dpi = fig_dpi, compression = "lzw", bg = "white")
  ggsave(file.path(dir, paste0(name, ".pdf")), plot, width = w, height = h,
         units = "mm", device = grDevices::cairo_pdf)
  ggsave(file.path(dir, paste0(name, ".png")), plot, width = w, height = h,
         units = "mm", dpi = fig_dpi, bg = "white")
  invisible(file.path(dir, name))
}

# ---- Standard plots --------------------------------------------------------

# psa: data frame with inc_cost, inc_qaly (one row per PSA iteration)
plot_ce_plane <- function(psa, wtp = c(20000, 30000)) {
  means <- summarise(psa, inc_cost = mean(inc_cost), inc_qaly = mean(inc_qaly))
  ggplot(psa, aes(inc_qaly, inc_cost)) +
    geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
    geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.3) +
    geom_point(alpha = 0.25, size = 0.6, colour = heor_cols[1]) +
    geom_abline(slope = wtp, intercept = 0, linetype = "dashed",
                colour = "grey30", linewidth = 0.4) +
    geom_point(data = means, shape = 21, size = 2.5,
               fill = heor_cols[2], colour = "black") +
    scale_y_continuous(labels = scales::label_comma(prefix = "£")) +
    labs(x = "Incremental QALYs", y = "Incremental cost (£)") +
    theme_heor()
}

# ceac: data frame with wtp, strategy, prob
plot_ceac <- function(ceac) {
  ggplot(ceac, aes(wtp, prob, colour = strategy, linetype = strategy)) +
    geom_line(linewidth = 0.6) +
    scale_colour_manual(values = heor_cols) +
    scale_x_continuous(labels = scales::label_comma(prefix = "£")) +
    scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
    labs(x = "Willingness to pay (£ per QALY)",
         y = "Probability cost-effective") +
    theme_heor()
}

# dsa: data frame with parameter (label), low, high (outcome at low and high
# input values); base: outcome at base case
plot_tornado <- function(dsa, base, outcome_label = "Net monetary benefit (£)") {
  d <- dsa |>
    mutate(range = abs(high - low)) |>
    arrange(range) |>
    mutate(pos = row_number())
  ggplot(d) +
    geom_rect(aes(xmin = pmin(base, low), xmax = pmax(base, low),
                  ymin = pos - 0.4, ymax = pos + 0.4, fill = "Low input value")) +
    geom_rect(aes(xmin = pmin(base, high), xmax = pmax(base, high),
                  ymin = pos - 0.4, ymax = pos + 0.4, fill = "High input value")) +
    geom_vline(xintercept = base, linewidth = 0.4) +
    scale_fill_manual(values = c("Low input value" = heor_cols[1],
                                 "High input value" = heor_cols[2]),
                      breaks = c("Low input value", "High input value")) +
    scale_y_continuous(breaks = d$pos, labels = d$parameter, expand = c(0.02, 0)) +
    scale_x_continuous(labels = scales::label_comma(prefix = "£")) +
    labs(x = outcome_label, y = NULL) +
    theme_heor() +
    theme(panel.grid.major.y = element_blank())
}

# trace: long data frame with cycle (or year), state, proportion, strategy
plot_trace <- function(trace, x_label = "Year") {
  ggplot(trace, aes(cycle, proportion, colour = state)) +
    geom_line(linewidth = 0.6) +
    facet_wrap(~ strategy) +
    scale_colour_manual(values = heor_cols) +
    scale_y_continuous(limits = c(0, 1)) +
    labs(x = x_label, y = "Proportion of cohort") +
    theme_heor()
}

# ---- Tables ----------------------------------------------------------------

.table_registry <- new.env()

# Saves outputs/tables/<name>.docx and .csv, and registers the table for
# compile_tables(). df should already be formatted (use fmt_* helpers).
save_table <- function(df, name, title, footnote = NULL) {
  dir <- here::here("outputs", "tables")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  utils::write.csv(df, file.path(dir, paste0(name, ".csv")), row.names = FALSE)

  ft <- flextable(df) |>
    theme_booktabs() |>
    font(fontname = base_font, part = "all") |>
    fontsize(size = 9, part = "all") |>
    bold(part = "header") |>
    set_caption(caption = title) |>
    autofit()
  if (!is.null(footnote)) {
    ft <- add_footer_lines(ft, values = footnote) |>
      fontsize(size = 8, part = "footer")
  }
  save_as_docx(ft, path = file.path(dir, paste0(name, ".docx")))
  assign(name, list(ft = ft, title = title), envir = .table_registry)
  invisible(ft)
}

# Compiles every table saved this session into manuscript/tables.docx,
# in the order given (defaults to alphabetical by file stem).
compile_tables <- function(order = NULL) {
  names <- if (is.null(order)) sort(ls(.table_registry)) else order
  doc <- read_docx()
  for (n in names) {
    tab <- get(n, envir = .table_registry)
    doc <- body_add_flextable(doc, tab$ft) |> body_add_par("")
  }
  dir <- here::here("manuscript")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  print(doc, target = file.path(dir, "tables.docx"))
  invisible(file.path(dir, "tables.docx"))
}
