# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A study project that turns the Office for Students (OfS) National Student Survey (NSS) provider-level results into a star schema for a Power BI dashboard.

- **Pipeline:** `scripts/clean.R` turns `data/raw/*.csv` into `data/clean/`: `fact_teach.parquet` (CAH3 × specific level breakdowns), `fact_provider.parquet` (published provider totals: All subjects × All undergraduates) and `dim_*.csv`.
- **`context/data_dictionary.md`:** the authoritative description of the output tables, their relationships and aggregation rules. Keep it in sync whenever `clean.R` changes the output.
- **`context/powerbi-instruction.md`:** the brief for the agent that builds the Power BI report. It has the data rules, measures, analytical questions, design conventions and review checkpoints.

## Running the pipeline

Run from the project root, because all paths in `clean.R` are relative to it:

```
Rscript scripts/clean.R
```

- **Needs:** `tidyverse`, `janitor` and `arrow`.
- **In the Bash tool, R isn't on PATH**, so the script can't be run from there. Ask the user to run it, or use the `r-btw` MCP tools if an R session is attached.
- **To inspect data from the shell,** use Python. `pyarrow` is installed, which reads the parquet file.
- **There are no tests or linting.**

## Data facts that shape every change

These were verified against the raw data. Don't re-derive or contradict them without checking.

- **Two raw files, same columns:**
  - `teach_ft.csv` holds Full-time results.
  - `teach_pt_appr.csv` holds Part-time and Apprenticeship results.
  - They are stacked with `bind_rows()`, and `mode_of_study` tells them apart.
- **Published totals sit alongside their breakdowns** on two axes, so summing across them double-counts respondents:
  - **Subject:** `All subjects` ⊃ CAH1 ⊃ CAH2 ⊃ CAH3. Parent codes are prefixes of the child code: `CAH02` ⊃ `CAH02-04` ⊃ `CAH02-04-01`.
  - **Level of study:** `All undergraduates` ⊃ `First degree`, `Other undergraduate` and `Undergraduate with postgraduate component`.
- **Breakdowns don't sum to their totals,** because small groups are unpublished. The gap is larger for part-time and apprenticeship. `to_grain()` now keeps only CAH3 subjects and the specific levels (and any mode not starting with "All"); the published totals are filtered out.
- **Percentages must never be summed or averaged:** positivity, benchmark, difference, the CIs and `materially_*`. Positivity can be pooled from option counts as `(option1 + option2) / (option1..option4)`. That matches the published figure within 0.1 pp for about 98% of rows on the 4-option questions. `HC1`–`HC6` and `Q28` use a 5-point scale (`option5`).
- **The fact table's grain:** `ukprn` × `mode_of_study` × `level_of_study` × `cah_code` × `question_no`, unique, with `cah_code` always a CAH3 code. `dim_cah` holds CAH3 rows only, with `cah1_*`/`cah2_*` parent columns; `dim_provider` is built from the fact table.
- **`pub_response_headcount` is in whole students; `number_population` is fractional** (multi-subject students are split). So `pub_resprate` ≠ headcount ÷ population. A pooled response rate is `Σ headcount ÷ Σ (headcount ÷ pub_resprate)`.
- **Rows without a benchmark are dropped** in `to_grain()`. That also removes every suppressed row (codes `BK`, `DP`, `DPL`) and the aggregate `Theme N` rows. Themes are mapped onto questions through `dim_theme_question`. In the raw file each Theme row comes after its own questions, so theme values are filled upward.
- **`benchmark_category`** uses the `materially_*` columns with a 90% confidence cut-off (the OfS materiality threshold is ±2.5 pp). It's blank where `materially_*` is blank.
- **`contr_benchmark`** is the provider's own share of its benchmark population. Above 50%, the benchmark comparison is weak.
- **For the Power BI report, `HC*` questions are excluded entirely.** They're still in the data; the exclusion happens in Power Query.

## Conventions

- **R style:** tidyverse with the native pipe `|>`, and `janitor::clean_names()` straight after reading. Transformations shared by both raw files belong in `to_grain()`, so the two files are always cleaned the same way.
- **Output format:** the fact table is written as Parquet so column types survive. Dimensions are CSV, written with `na = ""` so Power BI reads missing values as blank.
- **Naming:** output tables are called `fact_*` and `dim_*`.
