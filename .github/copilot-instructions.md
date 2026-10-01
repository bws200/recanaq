# Copilot instructions for `recanaq`

## Project overview

`recanaq` is an R package that retrieves Environment Canterbury (ECan)
air-quality data and provides New Zealand holiday-calendar helpers. It is a
network-backed package: the main functions call ECan's CSV endpoints, while
the holiday functions scrape the New Zealand Ministry of Education site,
download Outlook `.ics` files, and fetch public-holiday data from GitHub.

## Build, documentation, and validation

The project uses `renv`; `.Rprofile` activates it automatically.

```r
renv::restore()
roxygen2::roxygenise()
```

Build and check the package from the repository root:

```text
R CMD build .
R CMD check recanaq_0.1.1.tar.gz
```

There is currently no `tests/` directory, `testthat` configuration, or lint
configuration. Validate focused changes with direct R calls, for example:

```r
recanaq::check_date_format("01/01/2025")
recanaq::get_stations()
```

Network-backed examples should be run deliberately because they depend on
external services and current remote data.

## Architecture

- `R/recanaq-package.R` contains package-level documentation and the
  roxygen imports used to generate `NAMESPACE`.
- The air-quality pipeline starts with `get_stations()`, which downloads the
  monitored-site table. `get_daily_all_stations()` validates the requested
  range, maps `get_daily_one_station()` over the station IDs, and combines the
  results with `dplyr::bind_rows()`.
- `get_daily_one_station()` calls the ECan daily-data CSV endpoint, reshapes
  pollutant columns into long form with `tidyr::pivot_longer()`, parses dates,
  and rounds values to one decimal place.
- The school-holiday pipeline is
  `get_school_holiday_urls()` -> `download_school_holidays()` ->
  `parse_school_holidays()`. The parser handles folded ICS lines, extracts
  event fields, standardizes common term and holiday names, deduplicates, and
  sorts by start date. `get_school_holidays()` composes those steps.
- `get_nz_holidays()` fetches the public-holiday CSV, labels a complete
  calendar as weekends, regular weekdays, or holiday categories, and can
  return only holiday rows. `update_holiday_history()` appends deduplicated
  holiday rows to `inst/extdata/` in development mode or to the user data
  directory returned by `tools::R_user_dir()` for installed use.
- `man/` and `NAMESPACE` are generated from roxygen comments in `R/`; update
  them with roxygen2 rather than editing generated files by hand.

## Repository-specific conventions

- Public date arguments use `dd/mm/yyyy` strings. Validate them with
  `check_date()` or `lubridate::dmy()` before making requests; returned
  observation dates are `Date`/`POSIXct` values as documented by each
  function.
- Air-quality results are tidy long-format tibbles with `DateTime`,
  `StationName`, `name`, and `value` columns. Preserve this shape when
  extending the data pipeline.
- Prefer the existing explicit `pkg::fun()` style for package calls and keep
  roxygen imports synchronized with implementation changes.
- Remote HTTP responses are checked with `httr` and failures are surfaced with
  contextual errors. Invalid dates, malformed station metadata, and malformed
  daily responses should fail explicitly; preserve empty results only for valid
  requests that genuinely contain no observations.
- Holiday parsing is intentionally tolerant of changing source labels:
  normalize known term/holiday variants in the existing `case_when()` style,
  then use title case and whitespace squishing as the fallback.
- Preserve the persistence split in `update_holiday_history()`: use
  `dev_mode = TRUE` only for source-package development; installed-package
  data belongs under the user data directory, not inside the installed
  package.
- Keep examples that require network access or substantial plotting work
  guarded with `\dontrun{}` where appropriate.
