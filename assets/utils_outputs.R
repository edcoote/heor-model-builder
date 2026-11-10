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
  utils::write.csv(df, file.path(dir, paste0(name, ".csv")), row.names = FALSE,
                   fileEncoding = "UTF-8")
  # Title and footnote alongside the CSV, so build_report() can show the table
  # without rerunning the model
  jsonlite::write_json(list(title = title, footnote = footnote %||% ""),
                       file.path(dir, paste0(name, ".meta.json")),
                       auto_unbox = TRUE, pretty = TRUE)

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

# ---- HTML report -------------------------------------------------------------
# build_report() writes outputs/report.html: one self-contained file (figures
# embedded) that opens in any browser, for sharing results with co-authors or
# clients. It reads only saved outputs (tables/*.csv, figures/*.png, the
# legends, spec and log), so it never reruns the model. No pandoc needed.
#
# sections: named list, section title -> list of items. An item is
#   - "fig_<stem>" or "tab_<stem>": a saved figure or table,
#   - a data frame: shown as a table (e.g. test results),
#   - report_text("markdown"): a short paragraph.
# headline: named character vector of key results shown as cards at the top,
#   e.g. c("ICER" = "£2,992 per QALY", "P(cost-effective) at £25,000" = "99.8%").
# Figure legends come from manuscript/figure_legends.md: put a line
#   <!-- fig_<stem> --> directly above each legend.

report_text <- function(md) structure(md, class = "report_text")

`%||%` <- function(a, b) if (is.null(a)) b else a

.md_inline <- function(x) {
  x <- htmltools::htmlEscape(x)
  x <- gsub("\\[x\\]", "\u2611", x, ignore.case = TRUE)
  x <- gsub("\\[ \\]", "\u2610", x)
  x <- gsub("`([^`]+)`", "<code>\\1</code>", x)
  x <- gsub("\\*\\*([^*]+)\\*\\*", "<strong>\\1</strong>", x)
  x <- gsub("(^|[^*])\\*([^* ][^*]*)\\*", "\\1<em>\\2</em>", x)
  gsub("\\[([^]]+)\\]\\((https?://[^)]+)\\)", "<a href=\"\\2\">\\1</a>", x)
}

# Minimal markdown to HTML for the spec, log and legends: headings, lists
# (nested by indent), tables, block quotes, code fences and inline styles.
md_to_html <- function(lines) {
  lines <- gsub("\r", "", lines)
  lines <- lines[!grepl("^\\s*<!--.*-->\\s*$", lines)]
  out <- character(); i <- 1; n <- length(lines)
  list_stack <- character(); para <- character()
  flush_para <- function() {
    if (length(para)) out <<- c(out, paste0("<p>", .md_inline(paste(para, collapse = " ")), "</p>"))
    para <<- character()
  }
  close_lists <- function(to = 0) {
    while (length(list_stack) > to) {
      out <<- c(out, paste0("</li></", list_stack[length(list_stack)], ">"))
      list_stack <<- list_stack[-length(list_stack)]
    }
  }
  while (i <= n) {
    l <- lines[i]
    if (grepl("^```", l)) {
      flush_para(); close_lists()
      j <- i + 1
      while (j <= n && !grepl("^```", lines[j])) j <- j + 1
      code <- if (j > i + 1) lines[(i + 1):(j - 1)] else character()
      out <- c(out, paste0("<pre><code>", htmltools::htmlEscape(paste(code, collapse = "\n")), "</code></pre>"))
      i <- j + 1; next
    }
    if (grepl("^\\s*$", l)) { flush_para(); close_lists(); i <- i + 1; next }
    if (grepl("^#{1,6} ", l)) {
      flush_para(); close_lists()
      lev <- min(nchar(sub(" .*", "", l)) + 2, 6)  # the page has its own h1/h2
      out <- c(out, sprintf("<h%d>%s</h%d>", lev, .md_inline(sub("^#+ ", "", l)), lev))
      i <- i + 1; next
    }
    if (grepl("^\\s*\\|", l)) {
      flush_para(); close_lists()
      j <- i
      while (j <= n && grepl("^\\s*\\|", lines[j])) j <- j + 1
      rows <- lines[i:(j - 1)]
      rows <- rows[!grepl("^\\s*\\|[\\s:|-]+\\|\\s*$", rows, perl = TRUE)]
      cells <- lapply(rows, function(r) trimws(strsplit(sub("^\\s*\\|", "", sub("\\|\\s*$", "", r)), "|", fixed = TRUE)[[1]]))
      head <- paste0("<th>", .md_inline(cells[[1]]), "</th>", collapse = "")
      body <- vapply(cells[-1], function(cl) paste0("<tr>", paste0("<td>", .md_inline(cl), "</td>", collapse = ""), "</tr>"), "")
      out <- c(out, paste0("<div class=\"tw\"><table class=\"md\"><thead><tr>", head,
                           "</tr></thead><tbody>", paste(body, collapse = ""), "</tbody></table></div>"))
      i <- j; next
    }
    if (grepl("^>", l)) {
      flush_para(); close_lists()
      out <- c(out, paste0("<blockquote>", .md_inline(sub("^>\\s?", "", l)), "</blockquote>"))
      i <- i + 1; next
    }
    m <- regmatches(l, regexec("^(\\s*)([-*]|[0-9]+\\.)\\s+(.*)$", l))[[1]]
    if (length(m)) {
      flush_para()
      depth <- nchar(m[2]) %/% 2 + 1
      tag <- if (grepl("^[0-9]", m[3])) "ol" else "ul"
      if (depth > length(list_stack)) {
        out <- c(out, paste0("<", tag, "><li>"))
        list_stack <- c(list_stack, tag)
      } else {
        close_lists(depth)
        out <- c(out, "</li><li>")
      }
      out <- c(out, .md_inline(m[4]))
      i <- i + 1; next
    }
    if (length(list_stack) && grepl("^\\s+", l)) {
      out <- c(out, .md_inline(trimws(l))); i <- i + 1; next
    }
    close_lists()
    para <- c(para, trimws(l)); i <- i + 1
  }
  flush_para(); close_lists()
  paste(out, collapse = "\n")
}

.report_legends <- function() {
  path <- here::here("manuscript", "figure_legends.md")
  if (!file.exists(path)) return(list())
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  out <- list()
  for (k in grep("^\\s*<!--\\s*(fig_[A-Za-z0-9_]+)\\s*-->", lines)) {
    stem <- sub("^\\s*<!--\\s*(fig_[A-Za-z0-9_]+)\\s*-->.*", "\\1", lines[k])
    j <- k + 1
    while (j <= length(lines) && grepl("^\\s*$", lines[j])) j <- j + 1
    if (j <= length(lines)) out[[stem]] <- lines[j]
  }
  out
}

.report_table_html <- function(df, title = NULL, footnote = NULL, id = NULL) {
  df <- as.data.frame(df, check.names = FALSE)
  df[] <- lapply(df, function(x) ifelse(is.na(x), "", as.character(x)))
  head <- paste0("<th>", htmltools::htmlEscape(names(df)), "</th>", collapse = "")
  body <- apply(df, 1, function(r) paste0("<tr>", paste0("<td>", htmltools::htmlEscape(r), "</td>", collapse = ""), "</tr>"))
  filter <- if (nrow(df) > 8) "<input class=\"filter\" type=\"search\" placeholder=\"Filter rows\u2026\">" else ""
  paste0(
    "<div class=\"block table-block\"", if (!is.null(id)) paste0(" id=\"", id, "\""), ">",
    if (!is.null(title) && nzchar(title)) paste0("<p class=\"cap\">", htmltools::htmlEscape(title), "</p>") else "",
    filter,
    "<div class=\"tw\"><table class=\"data\"><thead><tr>", head, "</tr></thead><tbody>",
    paste(body, collapse = ""), "</tbody></table></div>",
    if (!is.null(footnote) && nzchar(footnote)) paste0("<p class=\"foot\">", htmltools::htmlEscape(footnote), "</p>") else "",
    "</div>")
}

.report_item <- function(item, legends) {
  if (inherits(item, "report_text")) {
    return(paste0("<div class=\"block text\">", md_to_html(strsplit(item, "\n")[[1]]), "</div>"))
  }
  if (is.data.frame(item)) return(.report_table_html(item))
  stopifnot(is.character(item), length(item) == 1)
  if (startsWith(item, "fig_")) {
    png <- here::here("outputs", "figures", paste0(item, ".png"))
    if (!file.exists(png)) stop("Figure not found: ", png)
    leg <- legends[[item]]
    paste0("<figure class=\"block\" id=\"", item, "\"><img alt=\"", item, "\" src=\"",
           base64enc::dataURI(file = png, mime = "image/png"), "\">",
           if (!is.null(leg)) paste0("<figcaption>", .md_inline(leg), "</figcaption>") else "",
           "</figure>")
  } else if (startsWith(item, "tab_")) {
    csv <- here::here("outputs", "tables", paste0(item, ".csv"))
    if (!file.exists(csv)) stop("Table not found: ", csv)
    df <- utils::read.csv(csv, check.names = FALSE, colClasses = "character",
                          fileEncoding = "UTF-8")
    meta_path <- here::here("outputs", "tables", paste0(item, ".meta.json"))
    meta <- if (file.exists(meta_path)) jsonlite::read_json(meta_path) else list()
    .report_table_html(df, meta$title, meta$footnote, id = item)
  } else stop("Unknown report item: ", item)
}

build_report <- function(sections, headline = NULL, title = NULL, subtitle = NULL,
                         include_spec = TRUE, include_log = TRUE,
                         file = here::here("outputs", "report.html")) {
  spec_path <- here::here("model_spec.md")
  log_path <- here::here("log", "run_log.md")
  if (is.null(title)) title <- basename(here::here())
  legends <- .report_legends()
  slug <- function(x) gsub("[^a-z0-9]+", "-", tolower(x))

  extra <- list()
  if (include_spec && file.exists(spec_path)) extra[["Model specification"]] <-
    paste0("<details class=\"block\"><summary>Show the full model_spec.md</summary><div class=\"text\">",
           md_to_html(readLines(spec_path, encoding = "UTF-8", warn = FALSE)), "</div></details>")
  if (include_log && file.exists(log_path)) extra[["Decision log"]] <-
    paste0("<details class=\"block\" open><summary>Assumptions, deviations and sign-offs (log/run_log.md)</summary><div class=\"text\">",
           md_to_html(readLines(log_path, encoding = "UTF-8", warn = FALSE)), "</div></details>")

  body <- vapply(names(sections), function(s) {
    paste0("<section id=\"", slug(s), "\"><h2>", htmltools::htmlEscape(s), "</h2>",
           paste(vapply(sections[[s]], .report_item, "", legends = legends), collapse = "\n"),
           "</section>")
  }, "")
  body <- c(body, vapply(names(extra), function(s)
    paste0("<section id=\"", slug(s), "\"><h2>", s, "</h2>", extra[[s]], "</section>"), ""))
  all_titles <- c(if (length(headline)) "Summary", names(sections), names(extra))
  nav <- paste0("<a href=\"#", slug(all_titles), "\">", htmltools::htmlEscape(all_titles), "</a>", collapse = "")
  cards <- if (length(headline)) paste0(
    "<section id=\"summary\"><h2>Summary</h2><div class=\"cards\">",
    paste0("<div class=\"card\"><div class=\"v\">", htmltools::htmlEscape(headline),
           "</div><div class=\"k\">", htmltools::htmlEscape(names(headline)), "</div></div>", collapse = ""),
    "</div></section>") else ""

  html <- paste0(
    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<title>", htmltools::htmlEscape(title), "</title><style>", .report_css, "</style></head><body>",
    "<nav><div class=\"brand\">", htmltools::htmlEscape(title), "</div>", nav, "</nav>",
    "<main><header><h1>", htmltools::htmlEscape(title), "</h1>",
    if (!is.null(subtitle)) paste0("<p class=\"sub\">", htmltools::htmlEscape(subtitle), "</p>") else "",
    "<p class=\"meta\">Generated ", format(Sys.time(), "%d %B %Y, %H:%M"),
    " from saved results. Figures and tables are the same files used for the manuscript.</p></header>",
    cards, paste(body, collapse = "\n"),
    "</main><script>", .report_js, "</script></body></html>")
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  con <- file(file, open = "w", encoding = "UTF-8")
  writeLines(html, con)
  close(con)
  invisible(file)
}

.report_css <- "
:root{--ink:#1d2433;--muted:#5b6475;--line:#e3e6ec;--bg:#ffffff;--soft:#f5f7fa;--accent:#0072B2}
*{box-sizing:border-box}
body{margin:0;font-family:Arial,Helvetica,sans-serif;color:var(--ink);background:var(--bg);font-size:15px;line-height:1.5}
nav{position:fixed;top:0;left:0;bottom:0;width:230px;padding:20px 14px;border-right:1px solid var(--line);background:var(--soft);overflow-y:auto}
nav .brand{font-weight:bold;margin:0 6px 14px;font-size:14px;word-break:break-word}
nav a{display:block;padding:6px 8px;border-radius:6px;color:var(--ink);text-decoration:none;font-size:14px}
nav a:hover,nav a.on{background:#e6eef6;color:var(--accent)}
main{margin-left:230px;padding:28px 40px 60px;max-width:1100px}
h1{font-size:26px;margin:0 0 4px}
h2{font-size:20px;margin:36px 0 14px;padding-top:6px;border-top:2px solid var(--line)}
h3,h4,h5,h6{font-size:16px;margin:18px 0 6px}
.sub{font-size:16px;color:var(--muted);margin:0 0 6px}
.meta{font-size:13px;color:var(--muted);margin:0}
section{scroll-margin-top:12px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px}
.card{border:1px solid var(--line);border-radius:10px;padding:14px 16px;background:var(--soft)}
.card .v{font-size:22px;font-weight:bold;color:var(--accent)}
.card .k{font-size:13px;color:var(--muted);margin-top:2px}
.block{margin:0 0 26px}
figure{margin:0 0 26px}
figure img{max-width:100%;height:auto;border:1px solid var(--line);border-radius:6px;background:#fff}
figcaption{font-size:14px;color:var(--muted);margin-top:6px;max-width:850px}
.cap{font-weight:bold;margin:0 0 6px}
.foot{font-size:13px;color:var(--muted);margin:6px 0 0;max-width:900px}
.tw{overflow-x:auto}
table{border-collapse:collapse;font-size:14px;min-width:50%}
th,td{padding:6px 10px;text-align:left;vertical-align:top;border-bottom:1px solid var(--line)}
thead th{border-bottom:2px solid var(--ink);background:#fff;white-space:nowrap}
table.data thead th{cursor:pointer;user-select:none}
table.data thead th:after{content:' \\2195';color:#b0b6c2;font-size:11px}
table.data thead th.asc:after{content:' \\2191';color:var(--accent)}
table.data thead th.desc:after{content:' \\2193';color:var(--accent)}
tbody tr:hover{background:var(--soft)}
.filter{margin:0 0 8px;padding:6px 10px;border:1px solid var(--line);border-radius:6px;font-size:14px;width:260px;max-width:100%}
details summary{cursor:pointer;font-weight:bold;margin-bottom:8px}
.text{max-width:900px}
code{background:var(--soft);padding:1px 4px;border-radius:4px;font-size:13px}
pre{background:var(--soft);padding:10px;border-radius:6px;overflow-x:auto}
blockquote{margin:8px 0;padding:6px 12px;border-left:3px solid var(--accent);background:var(--soft)}
@media (max-width:800px){nav{position:static;width:auto;border-right:0;border-bottom:1px solid var(--line)}main{margin-left:0;padding:16px}}
@media print{nav,.filter{display:none}main{margin:0;padding:0;max-width:none}section{break-inside:avoid-page}}
"

.report_js <- "
function num(s){var t=s.replace(/[\\u00a3,%\\s]/g,'').replace(/\\u2212/g,'-');var v=parseFloat(t);return isNaN(v)||!/^-?[0-9.]/.test(t)?null:v}
document.querySelectorAll('table.data').forEach(function(tb){
  tb.querySelectorAll('thead th').forEach(function(th,ci){
    th.addEventListener('click',function(){
      var asc=!th.classList.contains('asc');
      tb.querySelectorAll('thead th').forEach(function(h){h.classList.remove('asc','desc')});
      th.classList.add(asc?'asc':'desc');
      var body=tb.tBodies[0],rows=Array.prototype.slice.call(body.rows);
      rows.sort(function(a,b){var x=a.cells[ci].textContent,y=b.cells[ci].textContent,nx=num(x),ny=num(y);
        var r=(nx!==null&&ny!==null)?nx-ny:x.localeCompare(y);return asc?r:-r});
      rows.forEach(function(r){body.appendChild(r)});
    });
  });
});
document.querySelectorAll('.table-block').forEach(function(bl){
  var f=bl.querySelector('.filter');if(!f)return;
  f.addEventListener('input',function(){var q=f.value.toLowerCase();
    bl.querySelectorAll('tbody tr').forEach(function(r){r.style.display=r.textContent.toLowerCase().indexOf(q)>-1?'':'none'})});
});
var links=document.querySelectorAll('nav a');
if('IntersectionObserver' in window){
  var obs=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){links.forEach(function(a){a.classList.toggle('on',a.getAttribute('href')==='#'+e.target.id)})}})},{rootMargin:'0px 0px -70% 0px'});
  document.querySelectorAll('main section').forEach(function(s){obs.observe(s)});
}
"
