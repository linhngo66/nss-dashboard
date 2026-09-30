# Prompt: Build the NSS Student Experience dashboard in Power BI

## 1. Role and goal

You are building a Power BI report for a university's Student Planning / Student Experience team. The report analyses National Student Survey (NSS) results for a **selected provider** against its sector benchmarks and against other providers, by subject, theme, question and student segment.

Deliver:
1. A semantic model: tables, relationships and DAX measures.
2. A **page plan and mockup** for my review before any report building (see the review checkpoints in section 2).
3. The report, built from the approved mockup.
4. A short build log listing what you built, the assumptions you made, and the items that need my confirmation.

## 2. Tools and workflow

- Use the **Power BI Authoring MCP server** for the semantic model: tables, columns, relationships, measures, hierarchies and parameters.
- Use the **Power BI Report Authoring skill** (`powerbi-report-authoring`) for the report layer: pages, visuals, filters, formatting, theme and drill-through. The project is saved as **PBIP** with the **PBIR** report format.
- Order of work:
  1. Inspect the data against `context/data_dictionary.md`.
  2. **Checkpoint 1: page plan and wireframe mockup.** Stop and wait for my feedback.
  3. Build the model.
  4. Validate the measures against the published figures (section 9).
  5. **Checkpoint 2: one styled page with real data.** Stop and wait for my feedback.
  6. Build the remaining pages and drill-throughs.
  7. Run `validate-report`.
  8. **Checkpoint 3: screenshots of every page** before final polish (alt text, tab order, tooltips). Stop and wait for my feedback.
  9. Apply my feedback, finish, and write the build log.

**Review checkpoints.** Get my feedback early, while changes are cheap. At each checkpoint, stop, show me the material below, list the open questions and your recommended answers, and do not continue until I reply. Feedback may change earlier steps; revise the plan instead of working around it.

- **Checkpoint 1: page plan and wireframe mockup** (before the model is built).
  - **Page plan:** a table mapping each analytical question in section 6 to a page, with the visuals, their grain and the measures they use.
  - **Wireframes:** a low-fidelity layout of every page at 1280 × 720, including drill-throughs. Each visual is a labelled box with its type and title, and the header, navigation and slicers are shown. Placeholder shapes are fine; no real numbers are needed.
  - **Look and feel:** the colour palette from section 7 as swatches, and a sample of the header and one visual in the proposed style.
  - Save the mockup under `context/mockups/` as a static HTML page or images I can open without Power BI.
- **Checkpoint 2: one styled page with real data** (after the model is validated).
  - Build the Overview page, or whichever page I pick at checkpoint 1, fully in Power BI with the theme applied and real measures.
  - Show me a screenshot and the default provider's key numbers, so I can confirm the style, the measures and the layout before you repeat them across the other pages.
- **Checkpoint 3: all pages** (after `validate-report`).
  - Screenshots of every page and drill-through, with a short note on anything that differs from the approved plan.
- Assume I have committed a baseline to source control before you start. Do not delete or overwrite anything outside this project.
- **Stop and ask me before continuing** if any of the following happens:
  - A table, column or value differs from `context/data_dictionary.md`.
  - The validation in step 4 fails.
  - A design decision in this prompt conflicts with what the data allows.
- Do not guess to get past these points.

## 3. Source data

**`context/data_dictionary.md` is the authoritative description of the data.** Read it in full before starting. This section only summarises it.

The data is a pre-built star schema in `data/clean/`, produced by `scripts/clean.R` from OfS NSS provider-level files. It covers **all UK providers** (434), the **Taught** population only, one survey year, and full-time, part-time and apprenticeship students.

| Table | File | Key |
|---|---|---|
| `fact_teach` | `fact_teach.parquet` | `ukprn` + `mode_of_study` + `level_of_study` + `cah_code` + `question_no` |
| `dim_provider` | `dim_provider.csv` | `ukprn` |
| `dim_cah` | `dim_cah.csv` | `cah_code` |
| `dim_theme_question` | `dim_theme_question.csv` | `question_no` |
| `dim_mode` | `dim_mode.csv` | `mode_of_study` |
| `dim_level` | `dim_level.csv` | `level_of_study` |

What the cleaning has already done, so you do not need to:
- Kept the Taught population only; the Registered/Taught overlap is gone.
- Removed rows without a published benchmark, including all suppressed rows and the published **Theme** rows. There is no suppression column and no theme-level fact.
- Split question numbers into `question_no` and mapped them to themes.
- Keyed "All subjects" as `cah_code = "ALL"` and built the CAH1 → CAH2 → CAH3 hierarchy in `dim_cah`. The prefix nesting of CAH codes has been verified.
- Kept only the 95% confidence intervals and added `benchmark_category` from the OfS `materially_*` columns.

## 4. Data rules (must follow)

1. **One provider at a time.** Every provider view is filtered to a single provider through a single-select slicer on `dim_provider[provider_name]`, with a default provider of [SET BY TEAM]. Sector views (rankings, sector medians) remove that filter explicitly in DAX; they never sum across providers.
2. **One subject level and one study level at a time.** The fact holds published totals alongside their breakdowns (`All subjects` ⊃ CAH1 ⊃ CAH2 ⊃ CAH3; `All undergraduates` ⊃ the three levels). Make the `dim_cah[subject_level]` and `dim_level[level_of_study]` slicers single-select (defaults `All subjects` and `All undergraduates`), and guard additive measures with `HASONEVALUE()` on both.
3. **Always use the published total row.** Breakdown rows do not sum to their totals, because small groups are not published. Never roll children up to recreate a parent.
4. **Compare within a mode.** Benchmarks are calculated within each mode of study. Response counts may be summed across modes; percentages may not be combined across them.
5. **No averaging of percentages.** Never sum or average `positivity_measure`, `benchmark`, `difference`, the CIs or `materially_*`. When one visual cell is exactly one fact row, show the published value. When a visual needs a combined figure:
   - For positivity, pool the option counts (rule 6) and label the result **"derived, not published"**.
   - Benchmarks, differences, CIs and materiality cannot be combined. Show the published rows instead, or count rows by `benchmark_category`, and tell me which visual needed this.
6. **Positivity definition.** Published positivity is approximately `(option1 + option2) ÷ (option1 + option2 + option3 + option4)`. `not_applicable` is excluded from `number_responses`. `option5` is non-zero only on the 5-point agreement question `Q28`. Before relying on the formula:
   - Recompute it for all rows and report the match rate (within 0.1 pp) separately for the 4-option questions and `Q28`.
   - Propose a formula for `Q28` and report its match rate.
7. **Themes are derived, not published.** Theme rows were removed, so:
   - Theme positivity is pooled from the option counts of the theme's questions (rule 6) and labelled derived.
   - Theme-level significance is a count of the theme's questions in each `benchmark_category`, not a theme benchmark.
   - Questions without a theme (`Q25`–`Q28`) are grouped as "Other questions" and shown separately from the seven themes.
8. **Significance uses the OfS materiality columns.** A result is:
   - **Materially above** if `materially_above_bench` ≥ [Confidence threshold].
   - **Materially below** if `materially_below_bench` ≥ [Confidence threshold].
   - **Broadly in line** otherwise.
   - **Not assessed** where `materially_*` is blank (1,111 rows).

   Implement [Confidence threshold] as a what-if parameter with default 90, matching the stored `benchmark_category`. State on the report that "materially" means more than 2.5 pp from benchmark with at least that much statistical confidence.
9. **Reliability flags.** Low-reliability results are shown faded, not hidden.
   - **Low responses:** `number_responses` < [Reliability threshold], a what-if parameter with default [SET BY TEAM, placeholder 30].
   - **Self-benchmarked:** `contr_benchmark` > 50. The provider makes up most of its own benchmark population, so the comparison is weak.
10. **Question applicability.** `Q27` applies only to providers in England, and `Q28` only outside England. Exclude them from provider-to-provider rankings unless the visual is about those questions.
11. **Coverage means what was published.** Unpublished and suppressed combinations are not in the data. Show coverage as what exists (subjects, questions and segments published for the provider), never as a list of suppressed rows.
12. **Excluded questions.** The healthcare placement questions (`question_no` starting with `HC`) are out of scope. Filter them out in Power Query from both `fact_teach` and `dim_theme_question` so they never load into the model. Do not mention or surface them anywhere in the report: no visuals, notes, tooltips, filter panes or page text. Record the exclusion in the build log only.

## 5. Semantic model

Import the tables in section 3 as they are. Do not change the source files. Put additions in Power Query or in model calculated columns, and list them in the build log.

**Model additions**
- `dim_theme_question`: a short question label (≤ 40 characters), a question sort order, and a theme label with blank themes replaced by "Other questions" (sorted last).
- A separate `dim_theme` table (theme number, name, sort order) is optional. If you add it, relate it to `dim_theme_question` and explain why.
- `dim_mode`, `dim_level`: sort-order columns. Suggested orders are Full-time, Part-time, Apprenticeship; and All undergraduates, First degree, Other undergraduate, Undergraduate with postgraduate component.
- `dim_cah`: the hierarchy `cah1_name` → `cah2_name` → `cah_name`.
- Hide the denormalised fact columns (`provider_name`, `subject_level`, `cah_name`, `theme_no`) and all foreign keys.
- The data has no year column. Write measures so that a year dimension can be added later without rewriting them.

**Relationships**: as in the data dictionary. They are one-to-many and single-direction, from each dimension to `fact_teach`.

**Measures** (display folder in brackets)
- **[Core]**
  - Positivity %, Benchmark %, Difference (pts), Standard deviation, and the 95% CI bounds. Each returns the published value when exactly one fact row is in context, and blank otherwise (rule 5).
  - Positivity % (derived): pooled from option counts (rule 6), for themes and other combined views.
  - Responses, Population.
  - Response rate %: the published `pub_resprate` at a single-group grain.
- **[Significance]**
  - Benchmark category (rule 8), plus a numeric sort key and a colour measure for conditional formatting.
  - Count of questions materially above, materially below, broadly in line and not assessed, in the current filter context.
- **[Reliability]**
  - Low responses flag, Self-benchmarked flag.
  - An opacity or colour helper for visuals.
- **[Distribution]**
  - Option 1 share %, Option 2 share %, Negative share % (options 3 + 4), Not applicable %.
- **[Sector]**
  - Provider rank and percentile on positivity and on difference, among providers with a published row for the same mode × level × subject × question.
  - Sector median positivity for the same combination.
  - Number of providers compared.
- **[Priority]**
  - Students below benchmark (est.) = `number_population × −MIN(difference, 0) ÷ 100`, at **question** grain, summed only across rows of one subject level. Its description should say it estimates how many more students would need to respond positively to reach benchmark.
- **[Coverage]**
  - Subjects published at each CAH level for the provider.
  - Questions published.
  - Rows flagged low-reliability.

Add a description to every measure. Format percentages to 1 decimal place and differences as signed points (`+2.3`).

## 6. Analytical questions the report must answer

For each question, the page plan must say which page answers it, at what grain, with which measures and visuals. The notes below are the minimum; propose better visuals where they exist.

### Q1. Overall position: where does the provider stand against its benchmarks?
- **Asks:** At `All subjects` × `All undergraduates` for the selected mode, on which questions is the provider materially above or below benchmark? Are the gaps concentrated in particular themes?
- **Grain:** question, grouped by theme.
- **Measures:** Benchmark category counts, Difference with 95% CI, Positivity % (derived) per theme.
- **Watch for:** Label theme values as derived. Show "Not assessed" separately from "Broadly in line".

### Q2. Subjects: which subjects are furthest below benchmark, and why?
- **Asks:**
  - Which CAH2 subjects (drilling to CAH3) are materially below benchmark, and on which themes?
  - Is a subject's gap **systemic** (materially below on questions across several themes) or **specific** (concentrated in one theme)?
  - Is low positivity a **sector-wide pattern** for that subject (the sector median is also low) or **underperformance** (positivity is below both the benchmark and the sector median)?
- **Grain:** subject × question, one CAH level at a time.
- **Measures:** Difference, Benchmark category counts per subject × theme, Sector median positivity, Provider percentile.
- **Watch for:** Small CAH3 groups. Fade low-reliability and self-benchmarked results.

### Q3. Themes, questions and response strength: what drives a theme's result?
- **Asks:**
  - Within a theme, which questions drive the result?
  - How strong is the positive response, meaning the Option 1 share versus the Option 2 share? A high positivity score made mostly of Option 2 is lukewarm and at risk.
- **Grain:** question.
- **Measures:** Positivity %, Difference, Option 1 share %, Option 2 share %, Negative share %.
- **Watch for:** `Q28` uses a 5-point agreement scale. Keep it out of the 4-option distribution visuals, or handle it separately.

### Q4. Student segments: do results differ by mode and level?
- **Asks:**
  - How do full-time, part-time and apprenticeship students compare against their own benchmarks?
  - How do first degree, other undergraduate and integrated-master's students compare?
  - Does a subject's gap hold across modes and levels, or appear in only one segment?
- **Grain:** mode or level × subject × question.
- **Measures:** Difference, Benchmark category, Responses.
- **Watch for:** Compare each segment with its own benchmark (rule 4), not segment positivity with segment positivity. Many subject × segment combinations are unpublished; show these as "not published", not zero.

### Q5. Sector comparison: how does the provider rank among its peers?
- **Asks:**
  - For a given question and subject, where does the provider rank among all providers with a published result?
  - Which questions put it in the top or bottom quartile of the sector?
  - Does the ranking tell a different story from the benchmark comparison? A provider can be above benchmark but mid-table if its benchmark is low.
- **Grain:** question × subject × mode × level, compared across providers.
- **Measures:** Provider percentile, Sector median positivity, Number of providers compared.
- **Watch for:** Exclude the applicability-limited questions (rule 10). Show the number of providers compared, because small subjects have few peers.

### Q6. Reliability and coverage: how much can the results be trusted?
- **Asks:**
  - What are the response rates by subject and segment?
  - Which results rest on few responses, or on a benchmark the provider dominates?
  - Which subjects and segments have published results at all?
- **Grain:** subject × segment.
- **Measures:** Response rate %, Responses, Low responses flag, Self-benchmarked flag, Coverage measures.
- **Watch for:** Rule 11. Unpublished combinations are absent, not suppressed rows you can list.

### Q7. Priorities and good practice: where should the team act first?
- **Asks:**
  - Which subject × question gaps that are materially below benchmark affect the most students?
  - Where does good practice already exist internally, meaning subjects materially above benchmark on questions where the provider overall is below?
- **Grain:** question × subject, one CAH level at a time.
- **Measures:** Students below benchmark (est.), Difference, Population, Benchmark category.
- **Watch for:**
  - Rank only materially-below results.
  - Mark low-reliability results.
  - Roll up to a theme only by summing Students below benchmark (est.) over questions, and say that one student can count on several questions.

## 7. Design conventions

**Theme: Monash University corporate style.** The report should look like a Monash corporate document: clean, restrained and classic.

- **Brand colours.** Monash Blue `#006DAE` is the single brand accent, used for the header bar, active navigation and selected states. Everything else is black `#000000`, dark grey `#3C3C3C` for body text, mid grey `#8C8C8C` for secondary text, light grey `#F2F2F2` for panels, and white backgrounds. Verify these values against the current Monash brand guidelines and tell me if they differ.
- **Typography.** Segoe UI throughout (Semibold for titles, Regular for body), because Monash's brand typefaces are not available as Power BI fonts. The hierarchy is 20 pt page title, 12 pt visual title, 10 pt body and labels.
- **Layout.** Page size 1280 × 720 with generous white space. Each page has:
  - A flat blue header band with the page title and a filter-context subtitle (provider, mode, level, subject level).
  - Navigation buttons.
  - Synced slicers for Provider, Mode of study, Level of study and Subject level.

  Use thin grey dividers instead of borders or shadows. No gradients, 3D effects or decorative images.
- **Theme file.** Apply the theme through a report theme JSON file, not per visual.

**Colour-blind-safe data colours.** These are muted and corporate, never neon or saturated, and never red/green.

| Use | Colour | Hex |
|---|---|---|
| Materially above benchmark | Deep blue | `#1F4E79` |
| Materially below benchmark | Burnt orange | `#C45A12` |
| Broadly in line | Mid grey | `#A6A6A6` |
| Not assessed | Light grey, hatched or outlined | `#D9D9D9` |
| Low reliability | Same colour at ~35% opacity | — |

- **Why these colours.** Blue and orange stay distinguishable under the common colour-vision deficiencies, and the three colours also differ clearly in lightness, so they survive greyscale printing. The significance blue is deliberately darker than Monash Blue so that brand and meaning are not confused.
- **Don't rely on colour alone.** Always pair colour with a second cue: a ▲ / ▼ / ● marker, a data label, or the category name in the tooltip.
- **Diverging backgrounds** (matrices of Difference): light orange `#F4CBA8` → near-white `#F7F7F7` → light blue `#BDD7EE`. They must stay light enough for dark text to remain readable.
- **Categories** (e.g. modes, levels). Use a single-hue blue ramp of clearly different lightness (`#1F4E79`, `#5B8DB8`, `#A9C6E0`), not a rainbow palette. Do not use orange for categories on pages that show significance.
- **Validation.** Check the final palette with a colour-blindness simulator and record the result in the build log.

**Other conventions**
- **Titles:** each visual title states what the visual shows. Subtitles give the unit, the scale and any truncated axis. Axes on positivity charts may start at 50% only when labelled as such.
- **Legend:** one significance legend per page.
- **Notes:** a short note on relevant pages saying which figures are published and which are derived.
- **Visual types:** use modern visuals (`cardVisual`, not the legacy card). Do not use deprecated visuals (Q&A, Bing maps, filled maps).
- **Accessibility:** set alt text on every visual, and a logical tab order.

## 8. Drill-through

Provide at least two drill-through pages, each with a back button:
- **Subject detail:** all questions for one subject with Difference and benchmark category, split by mode, plus the subject's sector percentile.
- **Question detail:** one question across subjects and across peer providers, with low-reliability results faded.

## 9. Acceptance checks before you finish

1. For 20 random fact rows, the visual values equal the source `positivity_measure`, `benchmark`, `difference` and `benchmark_category`.
2. No visual combines rows from different subject levels, study levels or providers, except sector measures that do so explicitly and are labelled.
3. Every derived figure (theme positivity, pooled positivity) is labelled as derived.
4. The recomputed positivity match rate is reported for the 4-option questions and `Q28`, with examples of mismatches.
5. No `HC` question appears in the model or anywhere in the report.
6. At the default confidence threshold of 90, the Benchmark category measure agrees with the stored `benchmark_category` on every row.
7. `validate-report` passes. Every page renders in Desktop with no broken visuals.
8. The build log lists:
   - Each rule in section 4 and how it was implemented.
   - The model additions (section 5) and measure definitions.
   - The colour-blindness check result.
   - Anything you could not build as specified, and why.
