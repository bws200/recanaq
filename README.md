# recanaq

`recanaq` provides R functions for retrieving Environment Canterbury
(ECan) air-quality data and working with New Zealand holiday calendars.

## Installation

Install the development version from GitHub:

```r
remotes::install_github("bws200/recanaq")
```

For development in a checkout, restore the project environment with `renv`:

```r
renv::restore()
```

## Air-quality data

List monitored stations and their latest observation dates:

```r
library(recanaq)

stations <- get_stations()
```

Retrieve daily measurements for one station:

```r
daily_station <- get_daily_one_station(
  site_id = stations$SiteNo[[1]],
  from_date = "01/01/2025",
  to_date = "31/01/2025"
)
```

Retrieve and combine daily measurements for all stations:

```r
daily_all <- get_daily_all_stations(
  from_date = "01/01/2025",
  to_date = "31/01/2025"
)
```

Dates supplied to the air-quality functions must use `dd/mm/yyyy`. Returned
measurements are tidy, long-format data with `DateTime`, `StationName`, `name`,
and `value` columns.

## New Zealand holidays

Fetch and parse the Ministry of Education school-holiday calendars:

```r
school_holidays <- get_school_holidays()
```

Fetch public holidays for a year:

```r
holidays <- get_nz_holidays(2026)
calendar <- get_nz_holidays(2026, holidays_only = FALSE)
```

`get_nz_holidays()` returns `Date` and `Category` columns. The full calendar
labels weekends, regular weekdays, standard holidays, observed holidays, and
the Canterbury Anniversary.

To append a year's public holidays to the persistent history, use:

```r
update_holiday_history(2026)
```

Use `dev_mode = TRUE` only when deliberately updating the source checkout's
`inst/extdata/nz_holiday_history.csv`; installed packages write to the
user-level package data directory.

## Trend analysis example

The package includes the vignette
[`theil-sen-trend-analysis`](vignettes/theil-sen-trend-analysis.Rmd), which
describes an end-to-end PM10 and PM2.5 trend workflow using
`openair::TheilSen()`. It is not evaluated during package checks because it
retrieves live ECan data. Build it locally with:

```r
vignette("theil-sen-trend-analysis", package = "recanaq")
```

The repository also includes the parameterized Quarto report
[`examples/theil_sen_trend_analysis.qmd`](examples/theil_sen_trend_analysis.qmd),
which is better suited to scheduled or fully rendered analyses. It retrieves
ECan data, applies explicit site decisions, reports coverage, calculates
trends, and exports the exact inputs used for analysis.

The report requires Quarto and the optional analysis packages:

```r
install.packages(c("dplyr", "knitr", "lubridate", "openair", "readr", "tidyr"))
```

Render the Quarto report from the repository root:

```text
quarto render examples/theil_sen_trend_analysis.qmd
```

## Development

Regenerate package documentation and the namespace:

```r
roxygen2::roxygenise()
```

Run the test suite:

```r
testthat::test_local()
```

The data-retrieval examples require network access and depend on the current
contents and availability of the ECan, Ministry of Education, and public
holiday data services.

## License

MIT; see [LICENSE](LICENSE).
