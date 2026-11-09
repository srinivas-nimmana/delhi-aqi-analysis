# Is Delhi's Air Quality Deteriorating Faster Than Other Indian Cities?

An end-to-end analysis of daily AQI data for 26 Indian cities (2015 to mid-2020) using **SQL (MySQL)**, **Python (pandas, statsmodels)** and a 4-page interactive **Power BI** dashboard.

![Dashboard overview](Dashboard%20images/Overview.png)

## The question

Delhi is widely assumed to be getting worse relative to the rest of India. This project tests that directly: is Delhi's AQI deteriorating faster than the other cities, and what drives its pollution?

## Key findings

- **Delhi is improving, not deteriorating.** The seasonally adjusted trend is about **-21 AQI points per year** (-17 excluding the partial, lockdown-affected 2020). That is the 4th steepest decline among the 8 cities with reliable long records.
- **Its lead over the typical city is narrowing in points** (about -16 points per year), but Delhi is still roughly **2.3x** the typical city in relative terms.
- **Fewer bad days.** Very Poor + Severe days fell from **50% of days (2015) to 26% (2019)**. Most of the drop came outside winter: Feb-Oct bad days fell from 99 to 29 a year, while Nov-Jan bad days only slipped from 84 to 66. Winter now holds **69%** of Delhi's bad days.
- **Particulate matter leads the gap.** In 2019, Delhi's PM10 and PM2.5 averages were about **2.0x and 1.9x** those of other cities.
- **The lockdown is a natural experiment.** Between 25 Mar and 30 Jun 2020, Delhi's AQI fell **42%** against a median of **29%** across 19 cities.

## Data

- Source: [Air Quality Data in India (Kaggle, rohanrao)](https://www.kaggle.com/datasets/rohanrao/air-quality-data-in-india), file `city_day.csv`: one row per city per day, 29,531 rows, 26 cities, Jan 2015 to Jul 2020.
- The raw data is **not included** in this repository. Download it from Kaggle and check the dataset's license before reuse.

## Approach

1. **SQL (MySQL 8).** Loaded the CSV into a text staging table, then into a typed table, converting blanks to `NULL` so missing readings are not treated as zero. Ten questions, each building on the last: data coverage, city ranking, year-over-year change, seasonality, severe days, Delhi vs other cities, pollutants, and the lockdown.
2. **Python (pandas, statsmodels).** Monthly aggregation, rolling means, STL decomposition, Theil-Sen trend slopes with Kendall tau, and a with/without-2020 check on every result.
3. **Power BI.** A 4-page interactive report: Overview, Trend & seasonality, City comparison, Drivers & events. It uses a Date table, DAX measures, slicers, cross-filtering and page navigation.

## Data-quality decisions

- **Ahmedabad is excluded everywhere.** Its AQI readings are unreliable (average above the official 500 maximum).
- **2020 is partial (Jan-Jun) and lockdown-affected.** Results are reported with and without it.
- **Two comparison sets.** A continuous benchmark of cities with complete records, and a wider trend set of 10 cities (8 ranked). Patna and Visakhapatnam are excluded from the trend ranking because of gaps longer than 3 months.
- **Missing values stay missing.** Gaps are interpolated only when they are short and inside a series.

## Limitations

- Trend intervals fitted to a smoothed series are optimistic.
- STL end effects partly absorb the lockdown drop.
- Jaipur, Amritsar and Gurugram have short records, so their trend estimates are less reliable.
- CO and O3 readings show measurement-like jumps in some cities. Gas-to-gas ratios (NO2, SO2, CO) depend on how cities are averaged, so only the PM10 and PM2.5 ratios are treated as headline results.
- Some Delhi AQI values exceed the official 500 maximum.
- Correlation only: the lockdown result is consistent with local emissions being a major driver, but this analysis does not prove causation.

## Challenges and how I solved them

| Challenge | Solution |
|---|---|
| MySQL Import Wizard failed with `Error 1366` on blank cells in decimal columns | Loaded into an all-text staging table first, then converted blanks to `NULL` with `NULLIF(TRIM(...), '')` |
| The Import Wizard managed about 444 rows in 11 minutes | Switched to `LOAD DATA LOCAL INFILE`, which loaded the file in about a second |
| `Error 2068` on `LOAD DATA LOCAL INFILE` | Enabled `OPT_LOCAL_INFILE=1` in the connection's advanced settings and fixed the file path format |
| About 260,000 "Data truncated" warnings | `NUMERIC` in MySQL means `DECIMAL(10,0)` and silently rounded values. Redefined columns as `DECIMAL(10,2)` and reloaded |
| Only 5 cities had continuous records, which gave too small a comparison set | Built a separate trend set using a coverage diagnostic (at least 36 valid months and 75% of the city's own span) and interpolation limited to short interior gaps |
| Ahmedabad's AQI averaged above the 500 scale maximum | Excluded it in SQL, pandas and Power BI, and documented why |
| The lockdown and partial 2020 distorted trends | Reported every result with and without 2020 |
| The underlying trend comes from Python, so DAX cannot calculate it | Exported the Python results to CSV (`city_trends.csv`, `lockdown_change.csv`) and loaded them into Power BI as separate tables linked on City |
| The City slicer shrank ranking charts to one bar | Used Power BI's Edit interactions to stop it filtering the city-comparison visuals |
| Pollutant ratios differed between Python and Power BI for NO2, SO2 and CO | Traced it to pooled vs per-city averaging, and kept only the PM10 and PM2.5 ratios as headline claims |

## Repository structure

```
.
├── README.md
├── Indian_air_quality_Project.sql      # load CSV, then 10 analysis questions
├── 02_delhi_aqi_analysis.ipynb         # pandas / statsmodels analysis
├── Indian_air_quality_analysis.pbix    # Power BI dashboard (4 pages)
├── outputs/
│   ├── monthly_aqi_by_city.csv
│   ├── city_trends.csv
│   ├── lockdown_change.csv
│   └── delhi_bad_days.csv
└── Dashboard images/                   # dashboard screenshots
```

## How to reproduce

1. Download `city_day.csv` from Kaggle.
2. Run `Indian_air_quality_Project.sql` in MySQL (update the file path in the `LOAD DATA` line).
3. Run the notebook top to bottom (Restart and Run All). It writes the four CSVs in `outputs/`.
4. Open `Indian_air_quality_analysis.pbix` in Power BI Desktop. If the data sources moved, update them under Transform data.

## Dashboard pages

| Overview | Trend & seasonality |
|---|---|
| ![Overview](Dashboard%20images/Overview.png) | ![Trend](Dashboard%20images/Trend%20%26%20Seasonality.png) |
| **City comparison** | **Drivers & events** |
| ![City](Dashboard%20images/City%20Comparision.png) | ![Drivers](Dashboard%20images/Drivers%20%26%20Events.png) |

## Tools

MySQL 8, Python (pandas, NumPy, statsmodels, SciPy, matplotlib), Jupyter, Power BI Desktop (DAX), Git.
