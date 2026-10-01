test_that("get_daily_one_station rejects invalid dates", {
  expect_error(
    get_daily_one_station(
      site_no =  1,
      from_date = "2025-01-01",
      to_date = "02/01/2025"
    ),
    "dd/mm/yyyy"
  )
})

test_that("get_daily_all_stations rejects a reversed date range", {
  expect_error(
    get_daily_all_stations(
      from_date = "02/01/2025",
      to_date = "01/01/2025"
    ),
    "from_date must be earlier than to_date"
  )
})

test_that("get_daily_one_station rejects a reversed date range", {
  expect_error(
    get_daily_one_station(
      site_no = 1,
      from_date = "02/01/2025",
      to_date = "01/01/2025"
    ),
    "from_date must be earlier than to_date"
  )
})

test_that("get_daily_all_stations can continue after a station failure", {
  station_data <- tibble::tibble(site_no = c(101, 202))
  station_result <- function(site_no, from_date, to_date) {
    if (site_no == 101) {
      stop("station unavailable", call. = FALSE)
    }

    tibble::tibble(site_no = site_no)
  }

  testthat::expect_warning(
    result <- testthat::with_mocked_bindings(
      {
        get_daily_all_stations(
          from_date = "27/08/2026",
          to_date = "27/08/2026",
          on_error = "warn"
        )
      },
      get_stations = function() station_data,
      get_daily_one_station = station_result,
      .package = "recanaq"
    ),
    "station unavailable"
  )

  expect_equal(result$site_no, 202)
})
