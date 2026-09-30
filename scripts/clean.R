library(tidyverse)

# Read in data
teach_ft <- read_csv("data/raw/teach_ft.csv") |>
  janitor::clean_names()
teach_pt_appr <- read_csv("data/raw/teach_pt_appr.csv") |>
  janitor::clean_names()

# Lookup of questions and their themes; each "Theme" row follows its questions
dim_theme_question <- teach_pt_appr |>
  distinct(question_number) |>
  separate_wider_regex(question_number, c(code = "[^:]+", ": ", text = ".*")) |>
  mutate(
    is_theme = str_starts(code, "Theme"),
    theme_no = if_else(is_theme, parse_number(code), NA),
    theme = if_else(is_theme, text, NA)
  ) |>
  fill(theme_no, theme, .direction = "up") |>
  filter(!is_theme) |>
  select(theme_no, theme, question_no = code, question = text)


# CAH dimension: one row per subject code at every level, with its parent code.
# CAH codes nest by prefix: CAH02 > CAH02-04 > CAH02-04-01. "All subjects" is keyed "ALL".
dim_cah <- bind_rows(teach_ft, teach_pt_appr) |>
  distinct(cah_code, cah_name, subject_level) |>
  mutate(
    cah_code = replace_na(cah_code, "ALL"),
    cah_name = replace_na(cah_name, "All subjects"),
    parent_cah_code = case_match(
      subject_level,
      "CAH1" ~ "ALL",
      "CAH2" ~ str_sub(cah_code, 1, 5),
      "CAH3" ~ str_sub(cah_code, 1, 8)
    ),
    cah1_code = if_else(subject_level == "All subjects", NA, str_sub(cah_code, 1, 5)),
    cah2_code = if_else(subject_level %in% c("CAH2", "CAH3"), str_sub(cah_code, 1, 8), NA)
  )

# Flattened parent names, for drill-down hierarchies in the report
dim_cah <- dim_cah |>
  left_join(
    dim_cah |> filter(subject_level == "CAH1") |> select(cah1_code = cah_code, cah1_name = cah_name),
    by = join_by(cah1_code)
  ) |>
  left_join(
    dim_cah |> filter(subject_level == "CAH2") |> select(cah2_code = cah_code, cah2_name = cah_name),
    by = join_by(cah2_code)
  ) |>
  filter(subject_level == "CAH3") |>
  select(cah_code, cah_name, cah1_code, cah1_name, cah2_code, cah2_name) |> 
  arrange(cah_code)

# Dim mode
dim_mode <- bind_rows(teach_ft, teach_pt_appr) |>
  distinct(mode_of_study)

dim_level <- bind_rows(teach_ft, teach_pt_appr) |>
  distinct(level_of_study) |> 
  filter(level_of_study != "All undergraduates")

# Remove all aggregated rows where benchmark is NA and question_number does not start with 'Theme'.
# totals = FALSE keeps the most detailed breakdown (CAH3 x specific level);
# totals = TRUE keeps only the published provider totals (All subjects x All undergraduates).
to_grain <- function(df, totals = FALSE) {
  df <- df |>
    filter(!is.na(benchmark) & !str_starts(question_number, "Theme"))

  df <- if (totals) {
    filter(df, level_of_study == "All undergraduates", subject_level == "All subjects")
  } else {
    filter(df, !str_starts(level_of_study, "All"), subject_level == "CAH3")
  }

  df <- df |>
    select(-c(num, population, suppression_reason)) |>
    # Keep only the 95% confidence intervals
    select(-(matches("_(lower|upper)ci\\d+$") & !ends_with("ci95"))) |>
    # 90% confidence that the true difference is beyond the ±2.5pp materiality threshold
    mutate(benchmark_category = case_when(
      is.na(materially_above_bench) ~ NA,
      materially_above_bench >= 90 ~ "Materially above benchmark",
      materially_below_bench >= 90 ~ "Materially below benchmark",
      .default = "Broadly in line with benchmark"
    )) |>
    mutate(question_number = str_extract(question_number, "^[^:]+")) |>
    rename(question_no = question_number) |>
    left_join(select(dim_theme_question, question_no, theme_no), by = join_by(question_no)) |>
    relocate(theme_no, .before = question_no)

  if (totals) {
    # One row per provider x mode x question: the subject and level columns are constant
    select(df, -c(level_of_study, subject_level, cah_code, cah_name))
  } else {
    # CAH1/CAH2 parents of each CAH3 subject
    df |>
      left_join(
        select(dim_cah, cah_code, cah1_code, cah1_name, cah2_code, cah2_name),
        by = join_by(cah_code)
      ) |>
      relocate(cah1_code, cah1_name, cah2_code, cah2_name, .before = cah_code)
  }
}

fact_teach <- bind_rows(to_grain(teach_ft), to_grain(teach_pt_appr))

# Published provider totals, kept in their own table so they never mix with the breakdowns
fact_provider <- bind_rows(to_grain(teach_ft, totals = TRUE), to_grain(teach_pt_appr, totals = TRUE))

# Provider dimension: one row per ukprn in either fact table (some providers
# have a published total but no published CAH3 breakdown, and vice versa)
dim_provider <- bind_rows(fact_teach, fact_provider) |>
  distinct(ukprn, provider_name) |>
  arrange(provider_name)

# # Parquet keeps column types and is much smaller for the large fact table
arrow::write_parquet(fact_teach, "data/clean/fact_teach.parquet")
arrow::write_parquet(fact_provider, "data/clean/fact_provider.parquet")

list(
  dim_theme_question = dim_theme_question,
  dim_provider = dim_provider,
  dim_cah = dim_cah,
  dim_mode = dim_mode,
  dim_level = dim_level
) |>
  iwalk(\(df, name) write_csv(df, file.path("data/clean", paste0(name, ".csv")), na = ""))
