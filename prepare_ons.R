# prepare_ons.R — convert an ONS life tables workbook into the tidy CSV the
# skill ships in assets/. Run once per new ONS release:
#
#   Rscript scripts/prepare_ons.R <path/to/ons_workbook.xlsx> [sheet]
#
# Works with both ONS UK workbooks, which share one layout per sheet (males in
# columns 1-6, a blank column, females in columns 8-13, header row "age"):
#   - National life tables (3-year periods, sheets named e.g. "2021-2023")
#   - Single-year life tables (sheets named e.g. "2024")
# With no sheet given, the most recent period is used (first data sheet).
# Needs the readxl package.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("Usage: Rscript scripts/prepare_ons.R <workbook.xlsx> [sheet]")
src <- args[1]
if (!requireNamespace("readxl", quietly = TRUE)) stop("Install readxl first")

sheets <- readxl::excel_sheets(src)
data_sheets <- grep("^[0-9]{4}(-[0-9]{4})?$", sheets, value = TRUE)
sheet <- if (length(args) >= 2) args[2] else data_sheets[1]
if (!sheet %in% data_sheets) stop("Sheet not found or not a data sheet: ", sheet)

# Title and publication date from the Contents sheet, for provenance
contents <- suppressMessages(
  readxl::read_excel(src, sheet = "Contents", col_names = FALSE))[[1]]
title <- contents[1]
pub_line <- grep("published on", contents, value = TRUE)[1]
published <- if (is.na(pub_line)) NA_character_ else
  sub(".*published on ([0-9]{1,2} [A-Za-z]+ [0-9]{4}).*", "\\1", pub_line)
published_iso <- format(as.Date(published, "%d %B %Y"))

raw <- suppressMessages(readxl::read_excel(src, sheet = sheet, col_names = FALSE))
hdr <- which(raw[[1]] == "age")[1]
if (is.na(hdr)) stop("Could not find the 'age' header row in sheet ", sheet)

block <- function(cols, sex) {
  d <- raw[(hdr + 1):nrow(raw), cols]
  names(d) <- c("age", "mx", "qx", "lx", "dx", "ex")
  d <- d[!is.na(d$age) & grepl("^[0-9]+$", d$age), ]
  d[] <- lapply(d, as.numeric)
  cbind(sex = sex, as.data.frame(d))
}
lt <- rbind(block(1:6, "male"), block(8:13, "female"))
lt$period <- sheet
lt$published <- published_iso
lt$source <- "ONS life tables, United Kingdom"

# Basic checks: complete ages, qx in [0, 1], lx falling, radix 100,000
for (s in c("male", "female")) {
  d <- lt[lt$sex == s, ]
  stopifnot(all(d$age == seq(0, max(d$age))),
            all(d$qx >= 0 & d$qx <= 1),
            all(diff(d$lx) <= 0),
            d$lx[1] == 1e5)
}

out <- file.path("assets", "ons_life_tables_uk.csv")
write.csv(lt[, c("age", "sex", "mx", "qx", "lx", "dx", "ex",
                 "period", "published", "source")], out, row.names = FALSE)

writeLines(c(
  "# Bundled ONS life tables",
  "",
  "`assets/ons_life_tables_uk.csv` is made by `scripts/prepare_ons.R`. Do not edit it by hand.",
  "",
  "| Field | Value |",
  "|---|---|",
  paste0("| Workbook | ", title, " |"),
  paste0("| Sheet (period) | ", sheet, " |"),
  paste0("| Published by ONS | ", published, " |"),
  paste0("| Ages | 0 to ", max(lt$age), " by single year, males and females |"),
  paste0("| Prepared | ", format(Sys.Date()), " |"),
  "",
  "Columns: `mx` central death rate; `qx` probability of death between exact age x and x + 1;",
  "`lx` survivors to exact age x per 100,000 births; `dx` deaths between x and x + 1;",
  "`ex` period life expectancy at exact age x.",
  "",
  "To update for a new release: download the UK workbook from the ONS website, then run",
  "`Rscript scripts/prepare_ons.R <workbook.xlsx>` from the repository root, rerun the tests,",
  "and repackage the skill. Contains public sector information licensed under the Open",
  "Government Licence v3.0."
), file.path("assets", "ons_life_tables_uk_source.md"))

cat("Wrote", out, "from sheet", sheet, "(published", published, ")\n")
