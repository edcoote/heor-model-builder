#!/usr/bin/env python3
"""Create (or complete) a HEOR model project folder.

Usage: python scaffold.py <project_dir> [--budget-impact] [--dcea]

Never overwrites an existing file, so it is safe to rerun on a project.
"""
import argparse
import shutil
from datetime import date
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ASSETS = SKILL_DIR / "assets"

DIRS = [
    "inputs/raw", "R", "outputs/figures", "outputs/tables",
    "outputs/results", "manuscript", "log",
]

SCRIPTS = {
    "00_packages.R": (
        "# Packages used by every script\n"
        "pkgs <- c(\"here\", \"dplyr\", \"tidyr\", \"ggplot2\", \"scales\",\n"
        "          \"flextable\", \"officer\", \"readr\")\n"
        "missing <- pkgs[!pkgs %in% rownames(installed.packages())]\n"
        "if (length(missing)) install.packages(missing)\n"
        "invisible(lapply(pkgs, library, character.only = TRUE))\n"
        "source(here::here(\"R\", \"utils_conversions.R\"))\n"
        "source(here::here(\"R\", \"utils_outputs.R\"))\n"
        "source(here::here(\"R\", \"utils_tests.R\"))\n"
    ),
    "01_load_inputs.R": (
        "# Read parameters.csv into a named list; clean raw data here if needed\n"
        "params_df <- readr::read_csv(here::here(\"inputs\", \"parameters.csv\"),\n"
        "                             show_col_types = FALSE)\n"
        "params <- setNames(as.list(params_df$base), params_df$name)\n"
        "\n"
        "# ONS life table for background mortality (bundled with the skill)\n"
        "lt_path <- here::here(\"inputs\", \"raw\", \"ons_life_tables_uk.csv\")\n"
        "if (file.exists(lt_path)) life_table <- read_life_table(lt_path)\n"
    ),
    "02_model_structure.R": "# States, transitions and conversions (Stage 1)\n",
    "03_run_deterministic.R": "# Base case run and sanity tests (Stage 2)\n",
    "03b_hand_check.R": "# Cycles 1-2 of one arm, printed for a hand check in Excel (Stage 2)\n",
    "04_dsa.R": "# One-way deterministic sensitivity analysis (Stage 3)\n",
    "05_psa.R": "# Probabilistic sensitivity analysis (Stage 3)\n",
    "06_outputs.R": "# Rebuild every figure and table from outputs/results (Stage 4)\n",
}

OPTIONAL_SCRIPTS = {
    "budget_impact": ("07_budget_impact.R", "# Budget impact module\n"),
    "dcea": ("08_dcea.R", "# Distributional CEA module\n"),
}

PARAM_HEADER = ("name,description,base,low,high,distribution,param_1,param_2,"
                "input_type,source,notes\n")


def write_if_missing(path: Path, text: str) -> bool:
    if path.exists():
        return False
    path.write_text(text, encoding="utf-8")
    return True


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("project_dir")
    ap.add_argument("--budget-impact", action="store_true")
    ap.add_argument("--dcea", action="store_true")
    args = ap.parse_args()

    root = Path(args.project_dir).expanduser().resolve()
    name = root.name
    created = []

    for d in DIRS:
        (root / d).mkdir(parents=True, exist_ok=True)

    scripts = dict(SCRIPTS)
    if args.budget_impact:
        scripts[OPTIONAL_SCRIPTS["budget_impact"][0]] = OPTIONAL_SCRIPTS["budget_impact"][1]
    if args.dcea:
        scripts[OPTIONAL_SCRIPTS["dcea"][0]] = OPTIONAL_SCRIPTS["dcea"][1]

    for fname, text in scripts.items():
        if write_if_missing(root / "R" / fname, text):
            created.append(f"R/{fname}")

    for asset in ["utils_conversions.R", "utils_outputs.R", "utils_tests.R"]:
        dest = root / "R" / asset
        if not dest.exists():
            shutil.copy(ASSETS / asset, dest)
            created.append(f"R/{asset}")

    # Life table for background mortality: copied as raw data, never edited
    for asset in ["ons_life_tables_uk.csv", "ons_life_tables_uk_source.md"]:
        dest = root / "inputs" / "raw" / asset
        if not dest.exists():
            shutil.copy(ASSETS / asset, dest)
            created.append(f"inputs/raw/{asset}")

    checklist = root / "log" / "review_checklist.md"
    if not checklist.exists():
        shutil.copy(SKILL_DIR / "references" / "review_checklist.md", checklist)
        created.append("log/review_checklist.md")

    spec = root / "model_spec.md"
    if not spec.exists():
        shutil.copy(ASSETS / "model_spec_template.md", spec)
        created.append("model_spec.md")

    # Outputs script runs last so it can use results from optional modules
    order = sorted(f for f in scripts if f != "06_outputs.R") + ["06_outputs.R"]
    run_all = "".join(f'source(here::here("R", "{f}"))\n' for f in order)
    files = {
        "run_all.R": "# Reproduce everything from a clean session\n" + run_all,
        f"{name}.Rproj": "Version: 1.0\n",
        "README.md": f"# {name}\n\nSee `model_spec.md` for the design and "
                     "`log/run_log.md` for decisions. Run `run_all.R` to "
                     "reproduce all results.\n",
        "inputs/parameters.csv": PARAM_HEADER,
        "log/run_log.md": f"# Run log\n\n## {date.today().isoformat()}\n"
                          "- Project scaffolded.\n",
        "manuscript/figure_legends.md": "# Figure legends\n",
        "manuscript/methods_draft.md": "# Methods (draft)\n",
        "manuscript/cheers_2022.md": "# CHEERS 2022 checklist\n",
    }
    for rel, text in files.items():
        if write_if_missing(root / rel, text):
            created.append(rel)

    print(f"Project: {root}")
    print("Created:" if created else "Nothing new to create.")
    for c in created:
        print(f"  {c}")


if __name__ == "__main__":
    main()
