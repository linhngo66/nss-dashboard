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

# Remove all aggregated rows where benchmark is NA and question_number does not start with 'Theme'
to_grain <- function(df) {
  df |>
    filter(!is.na(benchmark) & !str_starts(question_number, "Theme")) |>
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
    mutate(cah_code = replace_na(cah_code, "ALL")) |>
    left_join(select(dim_theme_question, question_no, theme_no), by = join_by(question_no)) |>
    relocate(theme_no, .before = question_no)
}

teach_pt_appr_grain <- to_grain(teach_pt_appr)
teach_ft_grain <- to_grain(teach_ft)

# Combine full-time with part-time/apprenticeship; mode_of_study tells them apart
fact_teach <- bind_rows(teach_ft_grain, teach_pt_appr_grain)

# Provider dimension: one row per ukprn
dim_provider <- fact_teach |>
  distinct(ukprn, provider_name) |>
  arrange(provider_name)

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
  arrange(cah_code)

# Dim mode
dim_mode <- fact_teach |>
  distinct(mode_of_study)

dim_level <- fact_teach |>
  distinct(level_of_study)

# Parquet keeps column types and is much smaller for the large fact table
arrow::write_parquet(fact_teach, "data/clean/fact_teach.parquet")

list(
  dim_theme_question = dim_theme_question,
  dim_provider = dim_provider,
  dim_cah = dim_cah,
  dim_mode = dim_mode,
  dim_level = dim_level
) |>
  iwalk(\(df, name) write_csv(df, file.path("data/clean", paste0(name, ".csv")), na = ""))
