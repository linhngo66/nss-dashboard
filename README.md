# NSS benchmark dashboard

A Power BI dashboard of the Office for Students (OfS) National Student Survey (NSS) 2025 provider-level results. It shows where students at 433 UK providers are less positive than expected, by subject, theme, study mode and level of study.

![Overview page](portfolio/images/overview.png)

- **Write-up:** [portfolio/nss-dashboard.md](portfolio/nss-dashboard.md), covering the scenario, key findings and every page.
- **Dashboard (PDF):** [nss-dashboard.pdf](nss-dashboard.pdf), also on [Google Drive](https://drive.google.com/file/d/1OMazN9uhBqr9OlCro-XcBRCRmQ0mPWM7/view?usp=sharing).
- **Data source:** [OfS National Student Survey data](https://www.officeforstudents.org.uk/data-and-analysis/national-student-survey-data/), published under the Open Government Licence.

## Folder structure

```
nss-dashboard/
├── data/
│   ├── raw/                      # OfS NSS CSVs (not in the repo; see "Running it")
│   └── clean/                    # Output of clean.R: the star schema
│       ├── fact_teach.parquet    #   results: provider × mode × level × CAH3 subject × question
│       ├── fact_provider.parquet #   published provider-wide totals
│       └── dim_*.csv             #   provider, mode, level, subject (CAH), theme/question
├── scripts/
│   └── clean.R                   # Raw CSVs → data/clean
├── nss-dashboard.pbip            # Power BI project: open this in Power BI Desktop
├── nss-dashboard.SemanticModel/  # Model definition (TMDL): tables, relationships, DAX measures
├── nss-dashboard.Report/         # Report definition (PBIR): pages, visuals, theme
└── portfolio/
    ├── nss-dashboard.md          # Project write-up
    └── images/                   # Page screenshots and the star schema
```

## Running it

1. **Get the raw data.** Download the NSS 2025 provider-level "teaching" CSVs from the OfS link above. Save the full-time file as `data/raw/teach_ft.csv` and the part-time and apprenticeship file as `data/raw/teach_pt_appr.csv`.
2. **Clean it** (optional, because `data/clean/` is already in the repo). This needs R with `tidyverse`, `janitor` and `arrow`. Run it from the project root:
   ```
   Rscript scripts/clean.R
   ```
3. **Open the dashboard.** Open `nss-dashboard.pbip` in Power BI Desktop. In **Transform data → Manage parameters**, set `DataFolder` to your local `data/clean/` path (ending in a backslash), then click **Refresh**.

## Tools

R (tidyverse, janitor, arrow) · Power BI Desktop (Power Query, DAX, PBIP/PBIR/TMDL)
