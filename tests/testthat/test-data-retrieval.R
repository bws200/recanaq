test_that("get_stations parses station metadata and timestamps", {
  response <- structure(list(), class = "response")
  station_data <- paste(
    "SiteNo,SiteName,LongName,City,AirShed,LatestDateTime",
    "101,Alpha,Alpha site,Christchurch,Urban,\"27/08/2026 10:30:00\"",
    "202,Beta,Beta site,Timaru,Timaru,\"26/08/2026 09:15:00\"",
    sep = "\n"
  )

  result <- testthat::with_mocked_bindings(
    {
      get_stations()
    },
    GET = function(...) response,
    stop_for_status = function(...) invisible(NULL),
    content = function(...) station_data,
    .package = "httr"
  )

  expect_equal(result$site_no, c(101, 202))
  expect_equal(result$site_name, c("Alpha", "Beta"))
  expect_s3_class(result$latest_date_time, "POSIXct")
  expect_equal(
    result$latest_date_time,
    as.POSIXct(
      c("2026-08-27 10:30:00", "2026-08-26 09:15:00"),
      tz = "Etc/GMT-12"
    )
  )
})

test_that("get_stations cleans the ECan site name column", {
  response <- structure(list(), class = "response")
  station_data <- paste(
    "SiteNo,SiteName,LongName,City,AirShed,LatestDateTime",
    "101,Alpha,Alpha site,Christchurch,Urban,\"27/08/2026 10:30:00\"",
    sep = "\n"
  )

  result <- testthat::with_mocked_bindings(
    {
      get_stations()
    },
    GET = function(...) response,
    stop_for_status = function(...) invisible(NULL),
    content = function(...) station_data,
    .package = "httr"
  )

  expect_equal(result$site_name, "Alpha")
  expect_false("SiteName" %in% names(result))
})

test_that("get_daily_one_station reshapes and rounds CSV data", {
  response <- structure(list(), class = "response")
  csv_data <- paste(
    "DateTime,StationName,PM10,Temperature.2m..DegC.",
    "2026-08-27,Alpha,12.35,8.86",
    "2026-08-28,Alpha,4.44,9.04",
    sep = "\n"
  )

  result <- testthat::with_mocked_bindings(
    {
      get_daily_one_station(
        site_no = 101,
        from_date = "27/08/2026",
        to_date = "28/08/2026"
      )
    },
    GET = function(...) response,
    stop_for_status = function(...) invisible(NULL),
    content = function(...) csv_data,
    .package = "httr"
  )

  expect_equal(nrow(result), 4)
  expect_equal(
    result[, c("date", "station", "parameter", "value")],
    tibble::tibble(
      date = as.Date(c("2026-08-27", "2026-08-27", "2026-08-28", "2026-08-28")),
      station = rep("Alpha", 4),
      parameter = rep(c("PM10", "Temperature.2m..DegC."), 2),
      value = c(12.4, 8.9, 4.4, 9.0)
    )
  )
})

test_that("get_daily_all_stations combines each station result", {
  station_data <- tibble::tibble(site_no = c(101, 202))
  station_result <- function(site_no, from_date, to_date) {
    tibble::tibble(
      site_no = site_no,
      date = as.Date("2026-08-27"),
      value = site_no / 10
    )
  }

  result <- testthat::with_mocked_bindings(
    {
      get_daily_all_stations(
        from_date = "27/08/2026",
        to_date = "27/08/2026"
      )
    },
    get_stations = function() station_data,
    get_daily_one_station = station_result,
    .package = "recanaq"
  )

  expect_equal(result$site_no, c(101, 202))
  expect_equal(result$value, c(10.1, 20.2))
})
