# NSS Student Survey — Star Schema Data Dictionary

Context for the Power BI model built on National Student Survey (NSS) results published by the Office for Students (OfS). All tables are produced by `scripts/clean.R` from `data/raw/teach_ft.csv` (full-time) and `data/raw/teach_pt_appr.csv` (part-time and apprenticeship), and written to `data/clean/`.

## Tables

| Table | File | Type | Rows | Key |
|---|---|---|---|---|
| `fact_teach` | `fact_teach.parquet` | Fact | 190,235 (185,105 excluding `HC*`) | `ukprn` + `mode_of_study` + `level_of_study` + `cah_code` + `question_no` |
| `fact_provider` | `fact_provider.parquet` | Fact | 17,941 (16,819 excluding `HC*`) | `ukprn` + `mode_of_study` + `question_no` |
| `dim_provider` | `dim_provider.csv` | Dimension | 433 | `ukprn` |
| `dim_cah` | `dim_cah.csv` | Dimension | 163 | `cah_code` |
| `dim_theme_question` | `dim_theme_question.csv` | Dimension | 34 | `question_no` |
| `dim_mode` | `dim_mode.csv` | Dimension | 3 | `mode_of_study` |
| `dim_level` | `dim_level.csv` | Dimension | 3 | `level_of_study` |

## Relationships

```
dim_provider[ukprn]              1 ──< *  fact_teach[ukprn]
dim_cah[cah_code]                1 ──< *  fact_teach[cah_code]
dim_theme_question[question_no]  1 ──< *  fact_teach[question_no]
dim_mode[mode_of_study]          1 ──< *  fact_teach[mode_of_study]
dim_level[level_of_study]        1 ──< *  fact_teach[level_of_study]

dim_provider[ukprn]              1 ──< *  fact_provider[ukprn]
dim_theme_question[question_no]  1 ──< *  fact_provider[question_no]
dim_mode[mode_of_study]          1 ──< *  fact_provider[mode_of_study]
```

All relationships are many-to-one from the fact table, single-direction (dimension filters fact). Build slicers from the dimension columns, not the fact columns. `fact_provider` has no subject or level, so it is not related to `dim_cah` or `dim_level`; subject and level slicers do not filter it.

## Grain and aggregation rules

**Two fact tables at two grains. Never combine rows from both in one figure.**

- **`fact_teach`** — one row per provider × mode × level of study × CAH3 subject × question. It holds **only the most detailed published breakdowns**: CAH3 subjects and the specific levels of study (`First degree`, `Other undergraduate`, `Undergraduate with postgraduate component`). The published totals (`All subjects`, CAH1, CAH2 and `All undergraduates`) are removed in `to_grain()`, so rows no longer double-count across the subject or level axis.
- **`fact_provider`** — one row per provider × mode × question: the **published provider total** (`All subjects` × `All undergraduates`). Use it for provider-level headlines and provider-to-provider comparison; its benchmark, difference and CIs are the OfS published figures for the provider. There is still no total across modes or across providers.

Rules for the report:

- **Rolled-up counts understate the true totals.** Small groups are not published, so summing CAH3 or level rows covers only part of each provider's students (the gap is larger for part-time and apprenticeship). Label any roll-up accordingly.
- **Roll subjects up with `dim_cah`** (`cah1_name` → `cah2_name` → `cah_name`); each CAH3 row carries its CAH1 and CAH2 parents.
- **Never sum or average percentages** (`positivity_measure`, `benchmark`, `difference`, CIs, `materially_*`). When one visual cell covers exactly one fact row, show the value directly (e.g. `MAX()`). To combine several rows, weight positivity by `number_responses`; benchmarks and CIs cannot be combined.
- Rows without a published benchmark (small or suppressed groups, and the aggregate Theme rows) were removed during cleaning.

## `fact_teach`

| Column | Type | Description |
|---|---|---|
| `ukprn` | text | UK Provider Reference Number. FK → `dim_provider`. |
| `provider_name` | text | Provider name (denormalised; prefer `dim_provider`). |
| `mode_of_study` | text | FK → `dim_mode`. |
| `level_of_study` | text | FK → `dim_level`. See aggregation rules. |
| `subject_level` | text | Always `CAH3` (denormalised; prefer `dim_cah`). |
| `cah1_code`, `cah1_name` | text | CAH1 parent of the subject (denormalised from `dim_cah`). |
| `cah2_code`, `cah2_name` | text | CAH2 parent of the subject (denormalised from `dim_cah`). |
| `cah_code` | text | CAH3 subject code. FK → `dim_cah`. |
| `cah_name` | text | Subject name (denormalised; prefer `dim_cah`). |
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
| `materially_above_bench` | % (0–100) | Confidence that the true difference is more than 2.5 pp above benchmark. The three `materially_*` columns sum to ~100. Blank on 285 rows. |
| `difference_lowerci95`, `difference_upperci95` | pp | 95% confidence interval for `difference`. Blank where `materially_*` is blank. |
| `indicator_lowerci95`, `indicator_upperci95` | % (0–100) | 95% confidence interval for `positivity_measure`. |
| `pub_response_headcount` | number | Published survey response headcount for the group (all questions). |
| `pub_resprate` | % (0–100) | Published survey response rate for the group. |
| `benchmark_category` | text | Derived: `Materially above benchmark` if `materially_above_bench` ≥ 90; `Materially below benchmark` if `materially_below_bench` ≥ 90; otherwise `Broadly in line with benchmark` (includes groups too uncertain to call). Blank where `materially_*` is blank. |

Columns dropped from the source: `num`, `population` (constant), `suppression_reason` (all suppressed rows lack a benchmark and are filtered out), and the non-95% confidence intervals.

## `fact_provider`

Same columns and meanings as `fact_teach`, except that `level_of_study`, `subject_level`, `cah_code`, `cah_name` and the `cah1_*`/`cah2_*` columns are dropped (the level is always `All undergraduates` and the subject always `All subjects`). Built by `to_grain(..., totals = TRUE)`, so it is cleaned exactly like `fact_teach`. Every row has a materiality assessment. 37 providers have a published total but no published CAH3 breakdown, and 1 provider has the reverse.

## `dim_provider`

| Column | Type | Description |
|---|---|---|
| `ukprn` | text | Primary key. One-to-one with `provider_name`. |
| `provider_name` | text | Provider name. |

Built from both fact tables, so it contains exactly the providers with a published result in either. National/area totals (`UK`, `England`, `Scotland`, `Wales`, `Northern Ireland`) are not in the fact table.

## `dim_mode`

| Column | Type | Description |
|---|---|---|
| `mode_of_study` | text | Primary key. `Full-time` (from `teach_ft.csv`), `Part-time`, `Apprenticeship` (both from `teach_pt_appr.csv`). |

The modes are separate populations with no "all modes" total, so summing across modes does not double-count. Benchmarks are calculated within each mode, so compare results within a mode.

## `dim_level`

| Column | Type | Description |
|---|---|---|
| `level_of_study` | text | Primary key. `First degree`, `Other undergraduate`, `Undergraduate with postgraduate component`. |

The published `All undergraduates` total is excluded (see aggregation rules).

## `dim_cah`

Common Aggregation Hierarchy (CAH) subject classification. One row per CAH3 subject (163 codes; 161 have published results in `fact_teach`), with its CAH1 and CAH2 parents flattened onto the row.

| Column | Type | Description |
|---|---|---|
| `cah_code` | text | Primary key. CAH3 code, e.g. `CAH02-04-01`. |
| `cah_name` | text | CAH3 subject name. |
| `cah1_code`, `cah1_name` | text | CAH1 parent, e.g. `CAH02` (21 codes). |
| `cah2_code`, `cah2_name` | text | CAH2 parent, e.g. `CAH02-04` (35 codes). |

Hierarchy: `cah1_name` → `cah2_name` → `cah_name`. CAH codes nest by prefix, so the parent codes are the first 5 and 8 characters of `cah_code`.

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
