# NSS Student Survey — Star Schema Data Dictionary

Context for the Power BI model built on National Student Survey (NSS) results published by the Office for Students (OfS). All tables are produced by `scripts/clean.R` from `data/raw/teach_ft.csv` (full-time) and `data/raw/teach_pt_appr.csv` (part-time and apprenticeship), and written to `data/clean/`.

## Tables

| Table | File | Type | Rows | Key |
|---|---|---|---|---|
| `fact_teach` | `fact_teach.parquet` | Fact | 789,187 | `ukprn` + `mode_of_study` + `level_of_study` + `cah_code` + `question_no` |
| `dim_provider` | `dim_provider.csv` | Dimension | 434 | `ukprn` |
| `dim_cah` | `dim_cah.csv` | Dimension | 220 | `cah_code` |
| `dim_theme_question` | `dim_theme_question.csv` | Dimension | 34 | `question_no` |
| `dim_mode` | `dim_mode.csv` | Dimension | 3 | `mode_of_study` |
| `dim_level` | `dim_level.csv` | Dimension | 4 | `level_of_study` |

## Relationships

```
dim_provider[ukprn]              1 ──< *  fact_teach[ukprn]
dim_cah[cah_code]                1 ──< *  fact_teach[cah_code]
dim_theme_question[question_no]  1 ──< *  fact_teach[question_no]
dim_mode[mode_of_study]          1 ──< *  fact_teach[mode_of_study]
dim_level[level_of_study]        1 ──< *  fact_teach[level_of_study]
```

All relationships are many-to-one from the fact table, single-direction (dimension filters fact). Build slicers from the dimension columns, not the fact columns.

## Grain and aggregation rules

**One row = one published result** for a provider × mode of study × level of study × subject (CAH code) × question.

The fact table contains **published aggregate rows alongside their breakdowns** on two axes. Summing across levels of either axis double-counts respondents.

| Axis | Total value | Breakdown values |
|---|---|---|
| Subject (`dim_cah[subject_level]`) | `All subjects` | `CAH1` ⊃ `CAH2` ⊃ `CAH3` (nested) |
| Level of study (`dim_level[level_of_study]`) | `All undergraduates` | `First degree`, `Other undergraduate`, `Undergraduate with postgraduate component` |

Rules for the report:

- **Make the `subject_level` and `level_of_study` slicers single-select** (with a default such as `All subjects` / `All undergraduates`). Guard additive measures with `HASONEVALUE()` on both.
- **Breakdown rows do not sum to their totals.** Small groups are not published, so the published children cover only part of the total (e.g. part-time/apprenticeship CAH1 rows cover ~75% of `All subjects` responses; level breakdowns ~83% of `All undergraduates`). Always use the published total row rather than rolling up children.
- **Never sum or average percentages** (`positivity_measure`, `benchmark`, `difference`, CIs, `materially_*`). When one visual cell covers exactly one fact row, show the value directly (e.g. `MAX()`). To combine several rows, weight positivity by `number_responses`; benchmarks and CIs cannot be combined.
- Rows without a published benchmark (small or suppressed groups, and the aggregate Theme rows) were removed during cleaning.

## `fact_teach`

| Column | Type | Description |
|---|---|---|
| `ukprn` | text | UK Provider Reference Number. FK → `dim_provider`. |
| `provider_name` | text | Provider name (denormalised; prefer `dim_provider`). |
| `mode_of_study` | text | FK → `dim_mode`. |
| `level_of_study` | text | FK → `dim_level`. See aggregation rules. |
| `subject_level` | text | `All subjects`, `CAH1`, `CAH2`, `CAH3` (denormalised; prefer `dim_cah`). |
| `cah_code` | text | Subject code. `ALL` for All subjects. FK → `dim_cah`. |
| `cah_name` | text | Subject name; blank for `ALL` rows (denormalised; prefer `dim_cah`). |
| `theme_no` | number | Theme number 1–7 (denormalised from `dim_theme_question`; blank for questions outside a theme). |
| `question_no` | text | Question code (`Q01`–`Q28`, `HC1`–`HC6`). FK → `dim_theme_question`. |
| `number_responses` | number | Respondents who answered the question. Can be fractional: students on multi-subject courses are split across subjects. |
| `number_population` | number | Students surveyed in the group (target population). |
| `option1` … `option5` | number | Respondents per answer option, from most positive (`option1`) downward. `option5` is only used by 5-point agreement questions (`HC1`–`HC6`, `Q28`). |
| `not_applicable` | number | "This does not apply to me" responses; excluded from `number_responses`. |
| `positivity_measure` | % (0–100) | Share of respondents giving a positive answer. For the 4-option questions ≈ `(option1 + option2) / (option1 + … + option4)`. |
| `standard_deviation` | number | Standard deviation of the positivity measure. |
| `benchmark` | % (0–100) | Expected positivity for this group given its student and subject mix, based on sector-wide results. |
| `difference` | pp | `positivity_measure − benchmark`, in percentage points. |
| `contr_benchmark` | % (0–100) | Share of the benchmark population that comes from this provider itself. Above ~50% the provider is largely compared with itself; treat the benchmark comparison with caution. |
| `materially_below_bench` | % (0–100) | Statistical confidence that the true difference is more than 2.5 pp below benchmark. |
| `inline_with_bench` | % (0–100) | Confidence that the true difference is within ±2.5 pp of benchmark. |
| `materially_above_bench` | % (0–100) | Confidence that the true difference is more than 2.5 pp above benchmark. The three `materially_*` columns sum to ~100. Blank on 1,111 rows. |
| `difference_lowerci95`, `difference_upperci95` | pp | 95% confidence interval for `difference`. Blank where `materially_*` is blank. |
| `indicator_lowerci95`, `indicator_upperci95` | % (0–100) | 95% confidence interval for `positivity_measure`. |
| `pub_response_headcount` | number | Published survey response headcount for the group (all questions). |
| `pub_resprate` | % (0–100) | Published survey response rate for the group. |
| `benchmark_category` | text | Derived: `Materially above benchmark` if `materially_above_bench` ≥ 90; `Materially below benchmark` if `materially_below_bench` ≥ 90; otherwise `Broadly in line with benchmark` (includes groups too uncertain to call). Blank where `materially_*` is blank. |

Columns dropped from the source: `num`, `population` (constant), `suppression_reason` (all suppressed rows lack a benchmark and are filtered out), and the non-95% confidence intervals.

## `dim_provider`

| Column | Type | Description |
|---|---|---|
| `ukprn` | text | Primary key. One-to-one with `provider_name`. |
| `provider_name` | text | Provider name. |

Contains only providers present in `fact_teach`. National/area totals (`UK`, `England`, `Scotland`, `Wales`, `Northern Ireland`) are not in the fact table.

## `dim_mode`

| Column | Type | Description |
|---|---|---|
| `mode_of_study` | text | Primary key. `Full-time` (from `teach_ft.csv`), `Part-time`, `Apprenticeship` (both from `teach_pt_appr.csv`). |

The modes are separate populations with no "all modes" total, so summing across modes does not double-count. Benchmarks are calculated within each mode, so compare results within a mode.

## `dim_level`

| Column | Type | Description |
|---|---|---|
| `level_of_study` | text | Primary key. `All undergraduates` (total), `First degree`, `Other undergraduate`, `Undergraduate with postgraduate component`. |

`All undergraduates` is the published total of the other three. Use as a single-select slicer (see aggregation rules).

## `dim_cah`

Common Aggregation Hierarchy (CAH) subject classification. One row per code at every level, built from the raw files so every parent exists.

| Column | Type | Description |
|---|---|---|
| `cah_code` | text | Primary key. `ALL`, `CAH02` (CAH1), `CAH02-04` (CAH2), `CAH02-04-01` (CAH3). |
| `cah_name` | text | Subject name (`All subjects` for `ALL`). |
| `subject_level` | text | `All subjects`, `CAH1` (21 codes), `CAH2` (35), `CAH3` (163). Use as a single-select slicer. |
| `parent_cah_code` | text | Code one level up. CAH1 → `ALL`; blank for `ALL`. For parent-child DAX (`PATH()`). |
| `cah1_code`, `cah1_name` | text | CAH1 ancestor (self for CAH1 rows). |
| `cah2_code`, `cah2_name` | text | CAH2 ancestor (self for CAH2 rows; blank for CAH1). |

Suggested hierarchy: `cah1_name` → `cah2_name` → `cah_name`.

## `dim_theme_question`

| Column | Type | Description |
|---|---|---|
| `theme_no` | number | Theme number 1–7; blank for questions outside the seven themes. |
| `theme` | text | Theme name. |
| `question_no` | text | Primary key. |
| `question` | text | Full question wording. |

| Theme | Questions |
|---|---|
| 1 Teaching on my course | Q01–Q04 |
| 2 Learning opportunities | Q05–Q09 |
| 3 Assessment and feedback | Q10–Q14 |
| 4 Academic support | Q15–Q16 |
| 5 Organisation and management | Q17–Q18 |
| 6 Learning resources | Q19–Q21 |
| 7 Student voice | Q22–Q24 |
| — (no theme) | Q25 students' union, Q26 mental wellbeing information, HC1–HC6 healthcare placements, Q27 freedom of expression, Q28 overall satisfaction |

Not every question is asked of every student: HC1–HC6 apply to healthcare placement courses, Q27 is asked in England, and Q28 outside England. Compare providers on these questions with care.

Theme-level results (the source's `Theme N` rows) are not in the fact table. Averaging question positivity within a theme approximates, but does not reproduce, the published theme score.
